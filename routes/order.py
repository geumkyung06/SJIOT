import os
import uuid
import json
from datetime import datetime
import io
import qrcode
from flask import Blueprint, jsonify, request, send_file
from datetime import datetime
from zoneinfo import ZoneInfo

from services.extensions import r
from services.mobius import (send_order_cin, 
                             send_table_cin,
                             handle_stock_notification
                             #mark_station_in_progress, 
                             # mark_station_empty
                            )

import logging
logger = logging.getLogger(__name__)

bp = Blueprint('order', __name__)

QUEUE_KEY = os.getenv("QUEUE_KEY", "order:queue")
WAREHOUSE_KEY = os.getenv("WAREHOUSE_KEY", "warehouse:status")
STATION_KEY = os.getenv("STATION_KEY", "station:status")
# 창고/조립대가 "지금 어떤 주문을 처리 중인지" 역참조하기 위한 키
# (완료 콜백이 station_id/warehouse만 알려줄 때 order_id를 찾기 위해 필요)
WAREHOUSE_ORDER_KEY = os.getenv("WAREHOUSE_ORDER_KEY", "warehouse:current_order")
STATION_ORDER_PREFIX = os.getenv("STATION_ORDER_PREFIX", "station:current_order:")
MAX_QUEUE_LEN = 3  # 조립대 개수와 동일 (그 이상 대기시켜봤자 처리 못 함)

STATION_STARTED_PREFIX = os.getenv("STATION_STARTED_PREFIX", "station:started_at:")
STATION_TIMEOUT_SEC = int(os.getenv("STATION_TIMEOUT_SEC", "600"))  # 10분

ORDER_COUNTER_KEY = os.getenv("ORDER_COUNTER_KEY", "order:counter")

ORDER_PAGE_BASE = os.getenv("ORDER_PAGE_BASE", "https://sjiot-backend-294910862364.asia-northeast1.run.app")

MBTI_AXES = [("E", "I"), ("S", "N"), ("T", "F"), ("J", "P")]

# 테스트 기간 전용: 설정돼 있으면 건드리는 키마다 이 초만큼 TTL을 계속 갱신함.
# 운영 전환 시 이 env var만 빼면(또는 0으로) 원래대로 영구 보존됨.
TEST_KEY_TTL = int(os.getenv("TEST_KEY_TTL", "0")) or None

# 디버그용 /debug/reset 엔드포인트 활성화 여부. 운영 배포 시 반드시 0/미설정으로 둘 것.
DEBUG_ENDPOINTS_ENABLED = os.getenv("DEBUG_ENDPOINTS_ENABLED", "0") == "1"

COLOR_LIST = [c.strip() for c in os.getenv("COLOR_LIST", "r,y,g,b").split(",")]
BOARD_LIST = [b.strip() for b in os.getenv("BOARD_LIST", "red,yellow,green,blue").split(",")]

DETAIL_TO_STATUS = {
    "assigned":     "occupied",   # 부품 아직 없음 → 오지 마
    "dispensed":    "waiting",    # ← 여기서만 출동
    "agv_arrived":  "occupied",
    "agv_verified": "occupied",
    "in_progress":  "occupied",
    "timeout":      "cancelled",
    "cancelled":    "cancelled",
}

KST = ZoneInfo("Asia/Seoul")

def _order_counter_key():
    today = datetime.now(KST).strftime("%Y%m%d")
    return f"{ORDER_COUNTER_KEY}:{today}"

def _touch(*keys):
    """테스트 모드일 때 해당 키들의 TTL을 TEST_KEY_TTL로 (재)설정"""
    if not TEST_KEY_TTL:
        return
    for key in keys:
        r.expire(key, TEST_KEY_TTL)

def _ensure_initial_state():
    """warehouse/station 상태키가 없으면 초기값으로 세팅"""
    if not r.exists(WAREHOUSE_KEY):
        r.set(WAREHOUSE_KEY, "idle")
    if not r.exists(STATION_KEY):
        r.hset(STATION_KEY, mapping={"1": "idle", "2": "idle", "3": "idle"})
    _touch(WAREHOUSE_KEY, STATION_KEY)

def _get_free_station():
    station_status = r.hgetall(STATION_KEY)
    return next((sid for sid in ("1", "2", "3") if station_status.get(sid, "idle") == "idle"), None)

def _dispatch_order(order_id):
    """배정된 주문을 창고에 불출 지시(cnt_order append). 실패 시 배정 롤백."""
    od = r.hgetall(f"order:{order_id}")
    if not od:
        logger.error(f"[dispatch] order 해시 없음 (order_id={order_id})")
        return False

    ok = send_order_cin(
        order_id,
        od["board"],
        od.get("keycap"),
        od.get("colors", "").split(","),      # ← 리스트로
        int(od["station_id"]),
        int(od["order_seq"]),
    )

    if not ok:
        logger.error(f"[dispatch] cnt_order append 실패 → 배정 롤백 ({order_id})")
        sid = od["station_id"]
        r.set(WAREHOUSE_KEY, "idle")
        r.delete(WAREHOUSE_ORDER_KEY)
        r.hset(STATION_KEY, sid, "idle")
        r.delete(f"{STATION_ORDER_PREFIX}{sid}")
        r.hset(f"order:{order_id}", "status", "waiting")
        r.hdel(f"order:{order_id}", "station_id")
        r.lpush(QUEUE_KEY, order_id)          # 큐 맨 앞으로 복구
    return ok

def _try_assign_next():
    """
    warehouse가 idle이고 빈 조립대가 있으면 큐에서 다음 주문을 꺼내 배정.
    성공하면 배정된 order_id를 반환, 아니면 None.
    """
    if r.get(WAREHOUSE_KEY) != "idle":
        return None

    free_station = _get_free_station()
    if not free_station:
        return None

    # 큐에서 '살아있는' 주문이 나올 때까지 꺼냄
    while True:
        next_order_id = r.lpop(QUEUE_KEY)
        if not next_order_id:
            return None                                  # 큐가 비었음 → 배정할 게 없음
        if r.exists(f"order:{next_order_id}"):
            break                                        # 정상 주문 찾음 → 루프 탈출
        logger.warning(f"[assign] 만료된 주문 건너뜀 ({next_order_id})")
        # exists가 False면 lpop으로 이미 큐에서 빠졌으니 그냥 버리고 다음 반복

    r.set(WAREHOUSE_KEY, "busy")
    r.set(WAREHOUSE_ORDER_KEY, next_order_id)  # 창고가 지금 이 주문의 부품을 꺼내는 중
    r.hset(STATION_KEY, free_station, "busy")
    r.set(f"{STATION_ORDER_PREFIX}{free_station}", next_order_id)  # 이 조립대에 배정된 주문
    r.hset(f"order:{next_order_id}", mapping={
        "status": "assigned",
        "station_id": free_station
    })

    _touch(
        WAREHOUSE_KEY, WAREHOUSE_ORDER_KEY, STATION_KEY,
        f"{STATION_ORDER_PREFIX}{free_station}", f"order:{next_order_id}"
    )
    if not _dispatch_order(next_order_id):
        _push_table_snapshot()      # 롤백된 상태 반영
        return None
    _push_table_snapshot()
    return next_order_id

def check_station_timeouts():
    """in_progress 상태로 STATION_TIMEOUT_SEC 넘은 조립대를 자동 완료 처리."""
    now = datetime.now()
    started_keys = r.keys(f"{STATION_STARTED_PREFIX}*")

    for key in started_keys:
        station_id = key.replace(STATION_STARTED_PREFIX, "")
        started_at = datetime.fromisoformat(r.get(key))

        if (now - started_at).total_seconds() > STATION_TIMEOUT_SEC:
            _complete_station(station_id)

def _complete_station(station_id):
    station_id = str(station_id)
    order_key = f"{STATION_ORDER_PREFIX}{station_id}"
    order_id = r.get(order_key)

    if not order_id:
        return None  # 여기서 조기 반환, 아무 것도 건드리지 않음

    r.hset(STATION_KEY, station_id, "idle")
    r.delete(order_key)
    r.delete(f"{STATION_STARTED_PREFIX}{station_id}")
    _touch(STATION_KEY)

    r.hset(f"order:{order_id}", "status", "done")
    _touch(f"order:{order_id}")

    if _try_assign_next() is None:
        _push_table_snapshot()
    return order_id

def _build_station_snapshot():
    station_status = r.hgetall(STATION_KEY)
    tables = {}

    for sid in ("1", "2", "3"):
        redis_status = station_status.get(sid, "idle")
        order_id = r.get(f"{STATION_ORDER_PREFIX}{sid}")

        if order_id and not r.exists(f"order:{order_id}"):
            order_id = None

        if not order_id or redis_status == "idle":
            tables[sid] = {"status": "empty", "order_id": None}
            continue

        internal = r.hget(f"order:{order_id}", "status")  # assigned / in_progress
        table_status = "in_progress" if internal == "in_progress" else "waiting"
        tables[sid] = {"status": table_status, "order_id": order_id}

    return tables

def _push_table_snapshot():
    """redis 기준 스냅샷을 cnt_table로 전송. 실패해도 로직은 계속."""
    ok = send_table_cin(_build_station_snapshot())
    if not ok:
        logger.warning("[table] cnt_table 스냅샷 전송 실패")
    return ok

def _is_valid_mbti(keycap: str) -> bool:
    """4글자가 각각 해당 자리 축(E/I, S/N, T/F, J/P)에 속하는지 확인."""
    if len(keycap) != 4:
        return False
    return all(
        letter.upper() in axis
        for letter, axis in zip(keycap, MBTI_AXES)
    )

@bp.route('/station/<order_id>/start', methods=['POST'])
def station_start(order_id):
    """
    조립대 시작 (QR 인증)
    ---
    tags:
      - Station
    parameters:
      - in: path
        name: order_id
        type: string
        required: true
        example: "ord_a1b2c3d4"
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            station_id:
              type: integer
              description: QR을 스캔한 현재 조립대 번호 (기기 자체 고정값)
              example: 1
    responses:
      200:
        description: 시작 처리 성공
      400:
        description: 아직 조립대에 배정되지 않은 주문
      403:
        description: station_id 불일치 (다른 조립대에서 스캔함)
      404:
        description: 존재하지 않거나 만료된 주문
      409:
        description: 이미 진행 중
    """
    data = request.get_json(silent=True) or {}
    req_station_id = str(data.get("station_id", ""))

    order_data = r.hgetall(f"order:{order_id}")
    if not order_data:
        return jsonify({'error': '존재하지 않거나 만료된 주문입니다'}), 404

    assigned_station_id = order_data.get("station_id")
    if not assigned_station_id:
        return jsonify({'error': '아직 조립대에 배정되지 않은 주문입니다'}), 400
    if req_station_id != assigned_station_id:
        return jsonify({'error': '이 조립대에 배정된 주문이 아닙니다', 'assigned_station_id': int(assigned_station_id)}), 403
    if order_data.get("status") == "in_progress":
        return jsonify({'error': '이미 조립이 진행 중입니다'}), 409

    r.hset(STATION_KEY, assigned_station_id, "busy")
    r.hset(f"order:{order_id}", "status", "in_progress")
    r.set(f"{STATION_STARTED_PREFIX}{assigned_station_id}", datetime.now().isoformat())
    _touch(STATION_KEY, f"order:{order_id}", f"{STATION_STARTED_PREFIX}{assigned_station_id}")

    _push_table_snapshot()

    return jsonify({
        'ok': True,
        'order_id': order_id,
        'station_id': int(assigned_station_id),
        'board': order_data.get("board"),
        'keycap': order_data.get("keycap"),
        'colors': order_data.get("colors", "").split(",")
    }), 200

@bp.route('/station/<int:station_id>/complete', methods=['POST'])
def station_complete(station_id):
    """
    조립대 완료
    ---
    tags:
      - Station
    parameters:
      - in: path
        name: station_id
        type: integer
        required: true
        example: 1
      - in: body
        name: body
        required: false
        schema:
          type: object
          properties:
            order_id:
              type: string
              description: 디스플레이가 들고 있던 주문 ID (서버 기록과 교차검증용)
              example: "ord_a1b2c3d4"
    responses:
      200:
        description: 완료 처리 성공
        schema:
          type: object
          properties:
            ok:
              type: boolean
              example: true
            order_id:
              type: string
              example: "ord_a1b2c3d4"
      400:
        description: 이 조립대에 진행 중인 주문이 없음
      409:
        description: 화면에 표시된 order_id가 서버 기록과 불일치 (stale 상태)
        schema:
          type: object
          properties:
            error:
              type: string
            current_order_id:
              type: string
              example: "ord_a1b2c3d4"
    """
    station_id = str(station_id)
    data = request.get_json(silent=True) or {}
    req_order_id = data.get("order_id")

    order_key = f"{STATION_ORDER_PREFIX}{station_id}"
    order_id = r.get(order_key)

    if not order_id:
        return jsonify({'error': '이 조립대에 진행 중인 주문이 없습니다'}), 400

    if req_order_id and req_order_id != order_id:
        return jsonify({
            'error': '화면에 표시된 주문 정보가 서버 기록과 다릅니다. 새로고침 후 다시 시도해주세요',
            'current_order_id': order_id
        }), 409

    r.hset(STATION_KEY, station_id, "idle")
    r.delete(order_key)
    r.delete(f"{STATION_STARTED_PREFIX}{station_id}")
    _touch(STATION_KEY)

    r.hset(f"order:{order_id}", "status", "done")
    _touch(f"order:{order_id}")
  
    if _try_assign_next() is None:
        _push_table_snapshot()

    return jsonify({'ok': True, 'order_id': order_id}), 200


@bp.route('/station/free', methods=['GET'])
def free_stations():
    """
    빈 조립대 목록 조회 (AGV용)
    ---
    tags:
      - Station
    responses:
      200:
        description: 빈 조립대 번호 목록
        schema:
          type: object
          properties:
            free_stations:
              type: array
              items:
                type: string
              example: ["2", "3"]
    """
    station_status = r.hgetall(STATION_KEY)
    free = [sid for sid, status in station_status.items() if status == "idle"]
    return jsonify({'free_stations': free}), 200

@bp.route('/queue/status', methods=['GET'])
def queue_status():
    """
    현재 대기열 상태 조회
    ---
    tags:
      - Queue
    responses:
      200:
        description: 대기열 상태
        schema:
          type: object
          properties:
            queue_length:
              type: integer
              example: 2
            max_queue_len:
              type: integer
              example: 3
            full:
              type: boolean
              example: false
    """
    qlen = r.llen(QUEUE_KEY)
    return jsonify({
        'queue_length': qlen,
        'max_queue_len': MAX_QUEUE_LEN,
        'full': qlen >= MAX_QUEUE_LEN,
    })

@bp.route('/debug/reset', methods=['POST'])
def debug_reset():
    """
    [디버그 전용] warehouse/station/대기열 상태를 초기값으로 리셋.
    운영 배포 시에는 DEBUG_ENDPOINTS_ENABLED!=1 
    ---
    tags:
      - Debug
    responses:
      200:
        description: 초기화 완료
      404:
        description: 디버그 엔드포인트 비활성화 상태
    """
    if not DEBUG_ENDPOINTS_ENABLED:
        return jsonify({'error': 'not found'}), 404

    r.set(WAREHOUSE_KEY, "idle")
    r.delete(WAREHOUSE_ORDER_KEY)
    r.hset(STATION_KEY, mapping={"1": "idle", "2": "idle", "3": "idle"})
    for sid in ("1", "2", "3"):
        r.delete(f"{STATION_ORDER_PREFIX}{sid}")
        r.delete(f"{STATION_STARTED_PREFIX}{sid}")
    r.delete(QUEUE_KEY)

    return jsonify({'ok': True}), 200

@bp.route('/order', methods=['POST'])
def post_order_list():
    """
    키캡 주문 생성
    ---
    tags:
      - Order
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            board:
              type: string
              example: "blue"
            keycap:
              type: string
              example: "ESFJ"
            colors:
              type: array
              items:
                type: string
              example: ["r", "y", "b", "g"]
    responses:
      200:
        description: 주문 생성 성공
      400:
        description: 요청 값 오류
      409:
        description: 대기열 초과 (재시도 필요)
    """
    idem_key = request.headers.get("Idempotency-Key")

    if idem_key:
        claimed = r.set(f"idempotency:{idem_key}", "processing", nx=True, ex=300)
        if not claimed:
            # 이미 처리 중이거나 처리 완료 → 잠깐 대기 후 재조회, 또는 409 반환
            cached = r.get(f"idempotency:{idem_key}")
            if cached and cached != "processing":
                cached_response = json.loads(cached)
                return jsonify(cached_response["body"]), cached_response["status"]
            return jsonify({'error': '동일 요청 처리 중입니다. 잠시 후 재시도해주세요'}), 409
            
    data = request.get_json()

    board = data.get("board")
    keycap = data.get("keycap")
    colors = data.get("colors")

    try:
        if board not in BOARD_LIST:
            return jsonify({'error': '지원하지 않는 본판 색상'}), 400
        if not isinstance(keycap, str) or len(keycap) != 4:
            return jsonify({'error': '키캡은 4글자여야 합니다'}), 400
        if not isinstance(colors, list) or len(colors) != 4:
            return jsonify({'error': '색상 4개를 선택해주세요'}), 400
        if not _is_valid_mbti(keycap):
            return jsonify({'error': '잘못된 알파벳 압력(MBTI 아님)'}), 400
        if not all(c in COLOR_LIST for c in colors):
            return jsonify({'error': '잘못된 색상 선택'}), 400

        _ensure_initial_state()

        # 대기열 캡 체크: 이미 3개 대기 중이면 더 받지 않음
        if r.llen(QUEUE_KEY) >= MAX_QUEUE_LEN:
            return jsonify({'error': '대기열이 가득 찼습니다. 잠시 후 다시 시도해주세요'}), 409

        order_id = f"ord_{uuid.uuid4().hex[:8]}"
        order_seq = r.incr(_order_counter_key())

        # 일단 무조건 큐에 넣고 상태 waiting으로 생성
        r.rpush(QUEUE_KEY, order_id)
        r.hset(f"order:{order_id}", mapping={
            "board": board,
            "keycap": keycap,
            "colors": ",".join(colors),
            "status": "waiting",
            "order_seq": order_seq,
            "created_at": datetime.now().isoformat()
        })
        r.expire(f"order:{order_id}", 3600)  # TTL 1시간
        _touch(QUEUE_KEY)

        # warehouse/station 여유가 있으면 방금 넣은 주문이 바로 배정될 수 있음
        assigned_order_id = _try_assign_next()
        logger.debug(f"배정된 order_id: {assigned_order_id}")

        order_data = r.hgetall(f"order:{order_id}")
        status = order_data.get("status")

        if status == "assigned":
            position_in_queue = None
            station_id = int(order_data.get("station_id"))
        else:
            queue = r.lrange(QUEUE_KEY, 0, -1)
            position_in_queue = queue.index(order_id) + 1 if order_id in queue else None
            station_id = None

        order_status = {
            "order_id": order_id,
            "status": status,
            "position_in_queue": position_in_queue,
            "order_seq": order_seq,
            "station_id": station_id
        }

        response_body = {'order_status': order_status}

        if idem_key:
            r.set(f"idempotency:{idem_key}", json.dumps({"status": 200, "body": response_body}), ex=300)

        return jsonify(response_body), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@bp.route('/order/<order_id>/status', methods=['GET'])
def get_order_status(order_id):
    """
    주문 상태 조회
    ---
    tags:
      - Order
    parameters:
      - in: path
        name: order_id
        type: string
        required: true
        example: ord_a1b2c3d4
    responses:
      200:
        description: 조회 성공
        schema:
          type: object
          properties:
            order_id:
              type: string
              example: ord_a1b2c3d4
            status:
              type: string
              enum: [waiting, assigned, in_progress, done]
              example: assigned
            station_id:
              type: integer
              example: 1
            position_in_queue:
              type: integer
              example: 2
      404:
        description: 존재하지 않는 주문
        schema:
          type: object
          properties:
            error:
              type: string
              example: 존재하지 않는 주문입니다
    """
    order_data = r.hgetall(f"order:{order_id}")
    if not order_data:
        return jsonify({'error': '존재하지 않는 주문입니다'}), 404

    status = order_data.get("status")
    station_id = order_data.get("station_id")
    position_in_queue = None

    if status == "waiting":
        queue = r.lrange(QUEUE_KEY, 0, -1)
        if order_id in queue:
            position_in_queue = queue.index(order_id) + 1

    return jsonify({
        "order_id": order_id,
        "status": status,
        "station_id": int(station_id) if station_id else None,
        'board': order_data.get("board"),
        'keycap': order_data.get("keycap"),
        'colors': order_data.get("colors", "").split(","),
        'order_seq' : order_data.get("order_seq"),
        "position_in_queue": position_in_queue
    }), 200

def _extract_notification_con(data):
    """
    Mobius subscription notification 봉투(m2m:sgn)에서 con(dict)을 꺼냄.

    실제 notification 구조:
    {
      "m2m:sgn": {
        "sur": "Mobius/AE명/cnt_stock/sub_xxx",
        "nev": { "net": 3, "rep": { "m2m:cin": { "con": "<JSON 문자열>" } } }
      }
    }
    - con은 create_cin에서 json.dumps로 넣기 때문에 대부분 '문자열'로 옴 → json.loads 필요
    - 봉투가 아닌 flat body(포스트맨으로 콜백을 직접 두드리는 디버깅)면 body 자체를 con으로 취급
    - 꺼낼 수 없으면 None
    """
    if not isinstance(data, dict):
        return None

    sgn = data.get("m2m:sgn")
    if sgn is None:
        return data or None  # 디버깅용 직접 호출: body 자체가 con

    rep = (sgn.get("nev") or {}).get("rep") or {}
    cin = rep.get("m2m:cin") or {}
    con = cin.get("con")
    if isinstance(con, str):
        try:
            con = json.loads(con)
        except json.JSONDecodeError:
            logger.warning(f"[callback] con 파싱 실패: {con[:200]}")
            return None
    return con

@bp.route('/mobius/callback/<source>', methods=['POST'])
def mobius_callback(source):
    """
    창고(cnt_dispense)/AGV(cnt_arrived_table)/재고(cnt_stock) 구독 알림 수신
    ---
    tags:
      - Order
    parameters:
      - in: path
        name: source
        type: string
        required: true
        enum: [warehouse, agv, stock]
        example: warehouse
      - in: body
        name: body
        required: true
        schema:
          type: object
    responses:
      200:
        description: 처리 완료
      400:
        description: 잘못된 payload
    """
    data = request.get_json(silent=True) or {}

    # 구독 생성 직후 Mobius가 보내는 검증 요청 → 200만 돌려주면 구독이 활성화됨
    sgn = data.get("m2m:sgn") or {}
    if sgn.get("vrq"):
        return jsonify({'ok': True}), 200

    con = _extract_notification_con(data)
    logger.info(f"[callback:{source}] con={json.dumps(con, ensure_ascii=False)[:300] if con else con}")

    try:
        if source == "warehouse":
            if con is None:
                return jsonify({'error': 'notification에서 con을 읽지 못했습니다'}), 400
            if con.get("status") != "done":
                return jsonify({'ok': True}), 200

            done_id = con.get("order_id")
            current_order_id = r.get(WAREHOUSE_ORDER_KEY)
            if current_order_id is None:
                logger.warning(f"[callback:warehouse] 중복/유령 알림 무시 ({done_id})")
                return jsonify({'ok': True}), 200
            if done_id and done_id != current_order_id:
                logger.warning(f"[callback:warehouse] order_id 불일치 recv={done_id} cur={current_order_id}")
                return jsonify({'ok': True}), 200

            r.hset(f"order:{current_order_id}", "status", "dispensed")
            r.set(WAREHOUSE_KEY, "idle")
            r.delete(WAREHOUSE_ORDER_KEY)
            _touch(WAREHOUSE_KEY, f"order:{current_order_id}")

            # 출동 신호는 다음 주문 배정(HTTP 왕복)보다 먼저 나가야 해서 여기서 즉시 push
            _push_table_snapshot()
            _try_assign_next()

        elif source == "agv":
            # cnt_arrived_table: {"order_id": "...", "station_id": "2", "status": "ARRIVED"}
            if con is None:
                return jsonify({'error': 'notification에서 con을 읽지 못했습니다'}), 400

            station_id = str(con.get("station_id"))
            if station_id not in ("1", "2", "3"):
                return jsonify({'error': '잘못된 station_id'}), 400

            order_key = f"{STATION_ORDER_PREFIX}{station_id}"
            current_order_id = r.get(order_key)

            r.hset(STATION_KEY, station_id, "idle")
            r.delete(order_key)
            _touch(STATION_KEY)

            if current_order_id:
                r.hset(f"order:{current_order_id}", "status", "done")
                _touch(f"order:{current_order_id}")

            assigned_order_id = _try_assign_next()  # 조립대가 풀렸으니 다음 대기 주문 배정 시도
            logger.debug(f"배정된 order_id: {assigned_order_id}")

        elif source == "stock":
            # cnt_stock: {"board": {...}, "keycap": {...}} | switch 제외
            if con is None:
                return jsonify({'error': 'notification에서 con을 읽지 못했습니다'}), 400
            handle_stock_notification(con)

        else:
            return jsonify({'error': 'source는 warehouse, agv, stock 중 하나여야 합니다'}), 404

        return jsonify({'ok': True}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@bp.route('/order/<order_id>/qr', methods=['GET'])
def get_order_qr(order_id):
    """
    주문 상태 페이지 QR 코드 생성
    ---
    tags:
      - Order
    parameters:
      - in: path
        name: order_id
        type: string
        required: true
    responses:
      200:
        description: QR 코드 PNG 이미지
      404:
        description: 존재하지 않는 주문
    """
    if not r.exists(f"order:{order_id}"):
        return jsonify({'error': '존재하지 않는 주문입니다'}), 404

    url = f"{ORDER_PAGE_BASE}/station/{order_id}/start"

    img = qrcode.make(url)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    return send_file(buf, mimetype="image/png")

@bp.route('/station/<station_id>/status', methods=['GET'])
def get_station_status(station_id):
    """
    조립대 배정 주문 조회 (AGV 도착 알림 후 디스플레이가 주문번호 띄울 때 사용)
    ---
    tags:
      - Station
    parameters:
      - in: path
        name: station_id
        type: string
        required: true
        example: "1"
    responses:
      200:
        description: 조회 성공
        schema:
          type: object
          properties:
            order_id:
              type: string
              example: ord_a1b2c3d4
            order_seq:
              type: integer
              example: 12
      400:
        description: 이 조립대에 배정된 주문이 없음
        schema:
          type: object
          properties:
            error:
              type: string
              example: 이 조립대에 배정된 주문이 없습니다
    """
    order_id = r.get(f"{STATION_ORDER_PREFIX}{station_id}")
    if not order_id:
        return jsonify({'error': '이 조립대에 배정된 주문이 없습니다'}), 400

    order_data = r.hgetall(f"order:{order_id}")
    if not order_data:
        # station_order 키는 남아있는데 order 해시가 TTL로 만료된 엣지 케이스
        return jsonify({'error': '이 조립대에 배정된 주문이 없습니다'}), 400

    return jsonify({
        "order_id": order_id,
        "order_seq": order_data.get("order_seq"),
    }), 200