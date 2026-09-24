"""관리자 경로 — fault 해제 · 라인 초기화 · 조립대 호출.

fault 는 stage 를 그대로 둔 채 주문만 멈춰 세운다. 그래서 해제는 "그 자리에서 이어가기"다.
새로 밀어주는 건 `fault` 가 빠진 최신 스냅샷 하나뿐이고, 창고·AGV 는
같은 order_id 에 fault 가 없으면 해결된 것으로 본다 (명세 4-3).
"""
import json
from datetime import datetime

from flask import Blueprint, jsonify, request

from config import (QUEUE_KEY,
                    STATION_KEY,
                    STATION_ORDER_PREFIX,
                    WAREHOUSE_ORDER_KEY,
                    STATION_RESET_PASSWORD,
                    ARCHIVE_PREFIX,
                    KST,
                   )
from infra.extensions import r
from infra.logger import logger
from services import recovery
from services.process import clear_fault
from services.station_service import STATIONS, close_call, open_call, open_calls
from services.watchdog import CALL_EXTEND, MAX_CALL_EXTENDS
from services.stock import get_stocks

bp = Blueprint("admin", __name__)

HARD_RESET_CONFIRM = "HARD-RESET"

STATION_IDS = ("1", "2", "3")

# 창고 재고 최대 수량 (2026-09-09 팀장님 확인값)
WAREHOUSE_MAX = {
    "board": {"g": 325, "b": 325, "r": 325, "y": 325},
    "keycap": {
        "E": {"g": 158, "b": 157, "r": 158, "y": 157},
        "I": {"g": 143, "b": 142, "r": 143, "y": 142},
        "S": {"g": 168, "b": 167, "r": 168, "y": 167},
        "N": {"g": 133, "b": 132, "r": 133, "y": 132},
        "T": {"g": 138, "b": 137, "r": 138, "y": 137},
        "F": {"g": 163, "b": 162, "r": 163, "y": 162},
        "J": {"g": 148, "b": 147, "r": 148, "y": 147},
        "P": {"g": 153, "b": 152, "r": 153, "y": 152},
    },
}

def _to_int(v):
    if v is None or v == "":
        return None
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


def _max_for_part(part):
    """
    STOCK 슬롯 이름(part)에서 최대 수량을 찾는다.
    보드: "r"·"y"·"g"·"b" (밑줄 없음)
    키캡: "E_r" 형식 (글자_색상)
    존재하지 않는 part면 None.
    """
    if "_" in part:
        letter, _, color = part.partition("_")
        return WAREHOUSE_MAX["keycap"].get(letter, {}).get(color)
    return WAREHOUSE_MAX["board"].get(part)


def _live_order_ids():
    """대기열 + 조립대 + 창고가 지금 들고 있는 주문. 최대 7건."""
    ids = list(r.lrange(QUEUE_KEY, 0, -1))
    for sid in STATION_IDS:
        oid = r.get(f"{STATION_ORDER_PREFIX}{sid}")
        if oid and oid not in ids:
            ids.append(oid)
    oid = r.get(WAREHOUSE_ORDER_KEY)
    if oid and oid not in ids:
        ids.append(oid)
    return ids


def _get_order_summary(order_id):
    order_hash = r.hgetall(f"order:{order_id}")
    if not order_hash:
        return None

    colors_raw = order_hash.get("colors", "")
    return {
        "order_id": order_id,
        "board": order_hash.get("board"),
        "keycap": order_hash.get("keycap"),
        "colors": colors_raw.split(",") if colors_raw else [],
        "stage": order_hash.get("stage"),
        "fault": order_hash.get("fault") or None,
        "station_id": order_hash.get("station_id"),
        "order_seq": _to_int(order_hash.get("order_seq")),
        "created_at": order_hash.get("created_at"),
    }


def _today_archive_key():
    return f"{ARCHIVE_PREFIX}{datetime.now(KST).strftime('%Y%m%d')}"


def _get_archived_orders_today():
    archive = r.hgetall(_today_archive_key())
    orders = []
    for order_id, raw in archive.items():
        try:
            record = json.loads(raw)
        except (TypeError, ValueError):
            logger.warning(f"[admin] 아카이브 레코드 파싱 실패: {order_id}")
            continue

        colors_raw = record.get("colors", "")
        colors = colors_raw.split(",") if isinstance(colors_raw, str) and colors_raw else (colors_raw or [])

        orders.append({
            "order_id": record.get("order_id", order_id),
            "board": record.get("board"),
            "keycap": record.get("keycap"),
            "colors": colors,
            "stage": record.get("ended_at_stage") or record.get("final_status"),
            "fault": record.get("fault") or None,
            "station_id": record.get("station_id"),
            "order_seq": _to_int(record.get("order_seq")),
            "created_at": record.get("created_at"),
            "ended_at": record.get("ended_at"),
            "reason": record.get("reason"),
        })
    return orders


@bp.route("/admin/faults", methods=["GET"])
def list_faults():
    """
    fault 로 멈춰 있는 주문 목록
    ---
    tags:
      - Admin
    responses:
      200:
        description: 조회 성공
        schema:
          type: object
          properties:
            faults:
              type: array
              items:
                type: object
              example: [{"order_id": "ord_a1b2c3d4", "stage": "loaded", "fault": "drop_failed",
                         "fault_section": "agv", "station_id": "2"}]
    """
    out = []
    for oid in _live_order_ids():
        o = r.hgetall(f"order:{oid}")
        if o.get("fault"):
            out.append({
                "order_id": oid,
                "stage": o.get("stage"),
                "fault": o.get("fault"),
                "fault_section": o.get("fault_section"),
                "station_id": o.get("station_id"),
                "order_seq": _to_int(o.get("order_seq")),
            })
    return jsonify({"faults": out}), 200


@bp.route("/admin/order/<order_id>/fault/clear", methods=["POST"])
def clear_order_fault(order_id):
    """
    fault 해제 — stage 는 그대로 두고 그 자리에서 이어간다
    ---
    tags:
      - Admin
    parameters:
      - in: path
        name: order_id
        type: string
        required: true
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            password:
              type: string
    responses:
      200:
        description: 해제 완료
      400:
        description: 비밀번호 불일치
      404:
        description: 존재하지 않는 주문
      409:
        description: fault 가 걸려 있지 않은 주문
    """
    data = request.get_json(silent=True) or {}
    if data.get("password") != STATION_RESET_PASSWORD:
        return jsonify({"error": "비밀번호가 틀렸습니다"}), 400

    order = r.hgetall(f"order:{order_id}")
    if not order:
        return jsonify({"error": "존재하지 않거나 만료된 주문입니다"}), 404

    fault = order.get("fault")
    if not fault:
        return jsonify({"error": "fault 가 걸려 있지 않습니다", "stage": order.get("stage")}), 409

    clear_fault(order_id)
    logger.info(f"[admin] {order_id} fault 해제 ({fault}) stage={order.get('stage')} 유지")

    return jsonify({
        "ok": True,
        "order_id": order_id,
        "cleared": fault,
        "stage": order.get("stage"),
    }), 200


@bp.route("/admin/reset", methods=["POST"])
def admin_reset():
    """
    라인 초기화 — 전체 재고 / 상태 / 진행 중 주문 복구
    ---
    tags:
      - Admin
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          example:
            password: "관리자 비밀번호"
            mode: "zero"
            confirm: ""
            keep_queue: false
            reset_seq: false
            flush_unknown: false
          properties:
            password:
              type: string
              description: "관리자 비밀번호 (STATION_RESET_PASSWORD 와 동일)"
            mode:
              type: string
              enum: [zero, mobius, hard]
              default: zero
              description: "zero=전부 초기값(키캡 32칸=40 · 보드 4칸=3, 전 설비 idle, 진행 중 주문 삭제) · mobius=zero 뒤 Mobius 최신값으로 복구 · hard=zero + 아카이브·집계·일련번호까지 삭제(confirm 필요)"
            confirm:
              type: string
              description: "mode=hard 전용·필수. 정확히 HARD-RESET 이어야 한다. 비밀번호만으로는 오타 한 번에 90일치 기록이 날아가서 한 겹 더 둔다"
            keep_queue:
              type: boolean
              default: false
              description: "대기열(order:queue)과 그 주문 해시를 보존할지. 대기열은 Mobius 어디에도 없어서 지우면 복구가 불가능하다"
            reset_seq:
              type: boolean
              default: false
              description: "mode=hard 전용. process:seq 까지 리셋. 머신은 seq 가 안 오르면 무시하므로, 리셋하면 창고·AGV 머신도 같이 재시작해야 한다"
            flush_unknown:
              type: boolean
              default: false
              description: "mode=hard 전용. 이 서비스가 쓰지 않는 키까지 삭제. 실 Redis 는 배포본과 같은 DB 라 기본은 목록만 보고한다"
    responses:
      200:
        description: 초기화 완료
      400:
        description: 비밀번호 불일치쨌지원 안 하는 mode쨌confirm 누락
      500:
        description: 초기화 중 오류
    """
    data = request.get_json(silent=True) or {}
    if data.get("password") != STATION_RESET_PASSWORD:
        return jsonify({"error": "비밀번호가 틀렸습니다"}), 400

    mode = str(data.get("mode") or "zero")
    if mode not in ("zero", "mobius", "hard"):
        return jsonify({"error": "mode 는 zero 쨌 mobius 쨌 hard 중 하나여야 합니다",
                        "got": mode}), 400

    if mode == "hard" and data.get("confirm") != HARD_RESET_CONFIRM:
        return jsonify({
            "error": f'mode=hard 는 confirm="{HARD_RESET_CONFIRM}" 이 필요합니다',
            "will_delete": ["orders:archive:*", "order:counter:*",
                            "상태·진행 중 주문 전부"],
        }), 400

    try:
        report = recovery.reset(
            mode=mode,
            keep_queue=bool(data.get("keep_queue")),
            reset_seq=bool(data.get("reset_seq")) and mode == "hard",
            flush_unknown=bool(data.get("flush_unknown")) and mode == "hard",
        )
    except Exception as e:
        logger.exception("[admin] 초기화 실패")
        return jsonify({"error": str(e)}), 500

    return jsonify({"ok": True, **report}), 200

# 상태는 station:call:{sid}
# 누적 횟수만 order:{id}.call_count

def _bad_station(station_id):
    if str(station_id) not in STATIONS:
        return jsonify({"error": f"없는 조립대입니다: {station_id}"}), 404
    return None

@bp.route('/admin/station/<station_id>/call', methods=['POST'])
def station_admin_call(station_id):
    """
    관리자 호출 — 조립대 사용자가 도움을 요청한다
    ---
    tags:
      - Admin
    parameters:
      - in: path
        name: station_id
        type: string
        required: true
        description: 조립대 번호 (기기 자체 고정값). order_id 는 서버가 station:current_order 에서 꺼낸다
        example: 1
    responses:
      200:
        description: |
          호출 접수. 배정된 주문이 없어도 접수한다 ('부품이 안 온다' 가 호출의 주 용도 중 하나라
          주문 없음을 이유로 거절하면 그 케이스가 막힌다). 이미 호출 중이면 already_open=true 로
          200 을 준다 — called_at 은 최초값을 유지한다.
        schema:
          type: object
          properties:
            ok:
              type: boolean
            station_id:
              type: string
              example: "1"
            order_id:
              type: string
              example: ord_a1b2c3d4
            stage:
              type: string
              example: verified
            called_at:
              type: string
              example: "2026-09-18T14:03:11+09:00"
            waited_sec:
              type: integer
              example: 0
            call_count:
              type: integer
              description: 이 주문의 누적 호출 횟수
              example: 1
            extended_sec:
              type: integer
              description: 이번 호출로 stage 마감을 밀어준 초 (0 이면 연장 대상 stage 가 아니거나 상한 소진)
              example: 180
            already_open:
              type: boolean
      404:
        description: 없는 조립대 번호
    """
    bad = _bad_station(station_id)
    if bad:
        return bad

    state, already, extended = open_call(station_id)

    body = {"ok": True, "already_open": already, "extended_sec": extended, **state}
    oid = state.get("order_id")
    if oid:
        od = r.hgetall(f"order:{oid}")
        body["board"] = od.get("board")
        body["keycap"] = od.get("keycap")
        body["colors"] = [c for c in (od.get("colors") or "").split(",") if c]
        body["call_count"] = int(od.get("call_count") or 0)
    return jsonify(body), 200

@bp.route('/admin/station/<station_id>/call/ok', methods=['POST'])
def station_admin_call_ok(station_id):
    """
    호출 해결 — 관리자가 조치를 마쳤다
    ---
    tags:
      - Admin
    parameters:
      - in: path
        name: station_id
        type: string
        required: true
        example: 1
    responses:
      200:
        description: |
          호출 상태를 지우고, 해결 시점부터 기본 마감을 다시 잰다 (조치가 끝나도 머신이
          다시 움직일 시간은 필요하다). 종료된 주문·노쇼 폐기 대기 중이면 마감은 건드리지 않는다.
        schema:
          type: object
          properties:
            ok:
              type: boolean
            station_id:
              type: string
              example: "1"
            order_id:
              type: string
              example: ord_a1b2c3d4
            waited_sec:
              type: integer
              description: 호출부터 해결까지 걸린 초
              example: 74
            count:
              type: integer
              description: 이번 호출에서 버튼이 눌린 횟수
              example: 2
      404:
        description: 없는 조립대 번호
      409:
        description: 호출 중이 아닌 조립대
    """
    bad = _bad_station(station_id)
    if bad:
        return bad

    state = close_call(station_id)
    if state is None:
        return jsonify({"error": "호출 중이 아닙니다", "station_id": str(station_id)}), 409

    return jsonify({"ok": True, **state}), 200

@bp.route('/admin/calls', methods=['GET'])
def list_calls():
    """
    열려 있는 호출 목록 — 관리자 화면용
    ---
    tags:
      - Admin
    responses:
      200:
        description: 조립대 3칸의 점유 여부 + 배정된 주문 정보
    """
    occupancy = r.hgetall(STATION_KEY)

    stations = []
    for sid in STATION_IDS:
        status = occupancy.get(sid, "idle")
        order_id = r.get(f"{STATION_ORDER_PREFIX}{sid}")

        order_info = _get_order_summary(order_id) if order_id else None

        stations.append({
            "station_id": sid,
            "occupancy": status,
            "order": order_info,
        })

    return jsonify({"stations": stations}), 200


@bp.route('/admin/stock', methods=['GET'])
def admin_stock():
    """
    창고 재고 현황 (관리자 페이지용) — services.stock.get_stocks() 재사용 + max 추가
    ---
    tags:
      - Admin
    responses:
      200:
        description: 재고 수량 + 최대 수량
      503:
        description: 재고 캐시가 아직 없음
    """
    stocks = get_stocks()
    if stocks is None:
        return jsonify({"error": "재고 정보가 아직 없습니다"}), 503

    result = {"board": {}, "keycap": {}}

    for color, qty in stocks.get("board", {}).items():
        result["board"][color] = {
            "qty": qty,
            "max": WAREHOUSE_MAX["board"].get(color, 0),
        }

    for slot, qty in stocks.get("keycap", {}).items():
        letter, _, color = slot.partition("_")
        result["keycap"].setdefault(letter, {})
        result["keycap"][letter][color] = {
            "qty": qty,
            "max": WAREHOUSE_MAX["keycap"].get(letter, {}).get(color, 0),
        }

    return jsonify(result), 200

@bp.route('/admin/stock/refill', methods=['POST'])
def admin_stock_refill():
    """
    재고 채움 업데이트 (관리자 페이지 "채우기" 버튼)
    ---
    tags:
      - Admin
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            part:
              type: string
              description: 재고 칸 이름 — 보드는 "r"쨌"y"쨌"g"쨌"b", 키캡은 "E_r" 형식(글자_색상)
              example: "E_r"
            count:
              type: integer
              description: >
                생략하면 해당 칸의 최대치로 자동 채움("채우기" 버튼 기본 동작).
                값을 보내면 그 수량으로 채우되 최대치를 넘지 못하게 자동으로 잘림.
              example: 30
    responses:
      200:
        description: 업데이트 완료. 최대치로 잘렸으면 clamped=true.
      400:
        description: part 누락쨌존재하지 않는 칸쨌count 형식 오류
    """
    data = request.get_json(silent=True) or {}
    part = data.get("part")
    raw_count = data.get("count")

    if not part or not isinstance(part, str):
        return jsonify({"error": "part가 필요합니다 (예: 'E_r' 또는 'r')"}), 400

    max_qty = _max_for_part(part)
    if max_qty is None:
        return jsonify({"error": f"존재하지 않는 재고 칸입니다: {part}"}), 400

    existing_raw = r.hget("warehouse:stock", part)
    if existing_raw is None:
        return jsonify({"error": f"아직 재고 데이터가 없는 칸입니다: {part}"}), 400
    existing = json.loads(existing_raw)

    clamped = False
    if raw_count is None:
        # count 생략 = "채우기" 버튼 기본 동작 — 자동으로 최대치까지
        count = max_qty
    else:
        if not isinstance(raw_count, int) or raw_count < 0:
            return jsonify({"error": "count는 0 이상의 정수여야 합니다"}), 400
        if raw_count > max_qty:
            count = max_qty
            clamped = True
        else:
            count = raw_count

    # status는 count에 맞춰 자동 조정하되, disable(하드웨어 고장)은 채운다고 해결되는 게
    # 아니므로 절대 건드리지 않는다 (Redis ERD 6-3장 restock_list 원칙과 동일).
    if existing.get("status") != "disable":
        existing["status"] = "idle" if count > 0 else "empty"
    existing["count"] = count
    r.hset("warehouse:stock", part, json.dumps(existing))

    logger.info(f"[admin] 재고 채움: {part} -> {count} (max={max_qty}, clamped={clamped})")
    return jsonify({
        "ok": True,
        "part": part,
        "count": count,
        "max": max_qty,
        "clamped": clamped,
        "status": existing.get("status"),
    }), 200

@bp.route('/admin/stations', methods=['GET'])
def admin_stations():
    """
    조립대 상태 현황 (관리자 페이지용)
    ---
    tags:
      - Admin
    responses:
      200:
        description: 조립대 3칸의 점유 여부 + 배정된 주문 정보
    """
    occupancy = r.hgetall(STATION_KEY)

    stations = []
    for sid in STATION_IDS:
        status = occupancy.get(sid, "idle")
        order_id = r.get(f"{STATION_ORDER_PREFIX}{sid}")

        order_info = _get_order_summary(order_id) if order_id else None

        stations.append({
            "station_id": sid,
            "occupancy": status,
            "order": order_info,
        })

    return jsonify({"stations": stations}), 200


@bp.route('/admin/orders', methods=['GET'])
def admin_orders():
    """
    모든 주문 조회 (관리자 페이지용) — 오늘 접수된 전체
    ---
    tags:
      - Admin
    responses:
      200:
        description: 진행 중 + 오늘 종료된 주문 전체 목록
    """
    orders = []

    for order_id in _live_order_ids():
        summary = _get_order_summary(order_id)
        if summary:
            orders.append(summary)

    orders.extend(_get_archived_orders_today())

    return jsonify({"orders": orders}), 200
