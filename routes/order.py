import os
import pymysql
import redis
import uuid
from datetime import datetime

from flask import Blueprint, jsonify, request

from services.extensions import r

bp = Blueprint('order', __name__)

QUEUE_KEY = os.getenv("QUEUE_KEY", "order:queue")
WAREHOUSE_KEY = os.getenv("WAREHOUSE_KEY", "warehouse:status")
STATION_KEY = os.getenv("STATION_KEY", "station:status")
# 창고/조립대가 "지금 어떤 주문을 처리 중인지" 역참조하기 위한 키
# (완료 콜백이 station_id/warehouse만 알려줄 때 order_id를 찾기 위해 필요)
WAREHOUSE_ORDER_KEY = os.getenv("WAREHOUSE_ORDER_KEY", "warehouse:current_order")
STATION_ORDER_PREFIX = os.getenv("STATION_ORDER_PREFIX", "station:current_order:")
MAX_QUEUE_LEN = 3  # 조립대 개수와 동일 (그 이상 대기시켜봤자 처리 못 함)

def _ensure_initial_state():
    """warehouse/station 상태키가 없으면 초기값으로 세팅"""
    if not r.exists(WAREHOUSE_KEY):
        r.set(WAREHOUSE_KEY, "idle")
    if not r.exists(STATION_KEY):
        r.hset(STATION_KEY, mapping={"1": "idle", "2": "idle", "3": "idle"})


def _check_inventory(keycap, colors):
    """
    재고 확인 스텁.
    나중에 스마트창고 재고 캐시(Redis) 또는 실시간 조회로 교체.
    지금은 항상 재고 있음으로 처리.
    """
    # TODO: 실제 재고 확인 로직 연결
    return True


def _get_free_station():
    station_status = r.hgetall(STATION_KEY)
    return next((sid for sid, s in station_status.items() if s == "idle"), None)


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

    next_order_id = r.lpop(QUEUE_KEY)
    if not next_order_id:
        return None

    r.set(WAREHOUSE_KEY, "busy")
    r.set(WAREHOUSE_ORDER_KEY, next_order_id)  # 창고가 지금 이 주문의 부품을 꺼내는 중
    r.hset(STATION_KEY, free_station, "busy")
    r.set(f"{STATION_ORDER_PREFIX}{free_station}", next_order_id)  # 이 조립대에 배정된 주문
    r.hset(f"order:{next_order_id}", mapping={
        "status": "assigned",
        "station_id": free_station
    })

    # send_to_mobius(next_order_id, ..., free_station)  # 나중에 연결

    return next_order_id


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
              type: integer
              example: 4
            switch:
              type: string
              example: "black"
            keycap:
              type: string
              example: "L0VE"
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
    data = request.get_json()

    board = data.get("board")
    switch = data.get("switch")
    keycap = data.get("keycap")
    colors = data.get("colors")

    color_list = os.getenv('COLOR_LIST').split(',')  # COLOR_LIST=r,o,y,g,b,p,w
    board_list = [int(b) for b in os.getenv('BOARD_LIST').split(',')]
    switch_list = os.getenv('SWITCH_LIST').split(',') # SWITCH_LIST=blue,brown,red,black

    try:
        if board not in board_list:
            return jsonify({'error': '지원하지 않는 본판'}), 400
        if switch not in switch_list:
            return jsonify({'error': '지원하지 않는 축'}), 400
        if not len(keycap) == board:
            return jsonify({'error': '본판과 키캡 수 불일치'}), 400
        if not len(colors) == board:
            return jsonify({'error': '색상 선택 부족'}), 400
        if not all(c in color_list for c in colors):
            return jsonify({'error': '잘못된 색상 선택'}), 400

        if not _check_inventory(keycap, colors):
            return jsonify({'error': '재고가 부족한 키캡입니다'}), 400

        _ensure_initial_state()

        # 대기열 캡 체크: 이미 3개 대기 중이면 더 받지 않음
        if r.llen(QUEUE_KEY) >= MAX_QUEUE_LEN:
            return jsonify({'error': '대기열이 가득 찼습니다. 잠시 후 다시 시도해주세요'}), 409

        order_id = f"ord_{uuid.uuid4().hex[:8]}"

        # 일단 무조건 큐에 넣고 상태 waiting으로 생성
        r.rpush(QUEUE_KEY, order_id)
        r.hset(f"order:{order_id}", mapping={
            "board": board,
            "switch": switch,
            "keycap": keycap,
            "colors": ",".join(colors),
            "status": "waiting",
            "created_at": datetime.now().isoformat()
        })
        r.expire(f"order:{order_id}", 3600)  # TTL 1시간

        # warehouse/station 여유가 있으면 방금 넣은 주문이 바로 배정될 수 있음
        _try_assign_next()

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
            "station_id": station_id
        }

        return jsonify({'order_status': order_status}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@bp.route('/order/<order_id>/status', methods=['GET'])
def get_order_status(order_id):

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
        "position_in_queue": position_in_queue
    }), 200


@bp.route('/mobius/callback', methods=['POST'])
def mobius_callback():
    """
    창고/조립대 완료 알림 수신.
    Mobius subscription notification이 이 엔드포인트로 들어온다고 가정.
    실제 payload 포맷은 Mobius notification 구조에 맞춰 나중에 조정 필요.
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
            source:
              type: string
              enum: [warehouse, station]
            station_id:
              type: integer
              example: 2
              description: source가 station일 때만 필요
    responses:
      200:
        description: 처리 완료
      400:
        description: 잘못된 payload
    """
    data = request.get_json()
    source = data.get("source")

    try:
        if source == "warehouse":
            # 창고가 부품을 다 꺼냄 -> 조립 단계로 넘어감, 창고는 다음 주문 처리 가능
            current_order_id = r.get(WAREHOUSE_ORDER_KEY)
            r.set(WAREHOUSE_KEY, "idle")
            r.delete(WAREHOUSE_ORDER_KEY)

            if current_order_id:
                r.hset(f"order:{current_order_id}", "status", "in_progress")

            _try_assign_next()  # 창고가 풀렸으니 다음 대기 주문 pick 시도

        elif source == "station":
            station_id = str(data.get("station_id"))
            if station_id not in ("1", "2", "3"):
                return jsonify({'error': '잘못된 station_id'}), 400

            order_key = f"{STATION_ORDER_PREFIX}{station_id}"
            current_order_id = r.get(order_key)

            r.hset(STATION_KEY, station_id, "idle")
            r.delete(order_key)

            if current_order_id:
                r.hset(f"order:{current_order_id}", "status", "done")

            _try_assign_next()  # 조립대가 풀렸으니 다음 대기 주문 배정 시도

        else:
            return jsonify({'error': 'source는 warehouse 또는 station 이어야 합니다'}), 400

        return jsonify({'ok': True}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500