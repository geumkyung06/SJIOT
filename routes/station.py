from datetime import datetime
from flask import Blueprint, jsonify, request

from config import (QUEUE_KEY,
                    WAREHOUSE_KEY,
                    STATION_KEY,
                    AGV_KEY,
                    FAULT_KEY,
                    WAREHOUSE_ORDER_KEY,
                    STATION_ORDER_PREFIX,
                    MAX_QUEUE_LEN,
                    STATION_VERIFIED_PREFIX,
                    ORDER_PAGE_BASE,
                    STATION_RESET_PASSWORD,
                    COLOR_LIST,
                    BOARD_LIST,
                    KST,
                   )

from infra.logger import logger

from infra.extensions import r
from infra.mobius import (handle_stock_notification,
                          send_agv_command_cin,
                          _push_station_snapshot,
                        )
from infra.keys import (_order_counter_key, 
                        _touch,
                        _ensure_initial_state,
                      )

from services.order_service import _is_valid_mbti
from services.station_service import _try_assign_next
from services.process import is_at_or_past, push_process

bp = Blueprint('station', __name__)

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
              type: string
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
    assigned_station_id = str(assigned_station_id)
    if req_station_id != assigned_station_id:
        return jsonify({'error': '이 조립대에 배정된 주문이 아닙니다', 'assigned_station_id': (assigned_station_id)}), 403
    if r.get(f"{STATION_ORDER_PREFIX}{req_station_id}") != order_id:
        return jsonify({'error': '이미 종료되었거나 이 조립대의 현재 주문이 아닙니다'}), 409
    if order_data.get("stage") in ("verified", "completed", "expired", "cancelled"):
        return jsonify({'error': '이미 처리된 주문입니다'}), 409

    send_agv_command_cin(order_id, req_station_id, "verified")

    r.hset(STATION_KEY, assigned_station_id, "busy")
    r.hset(f"order:{order_id}", "stage", "verified")
    r.set(f"{STATION_VERIFIED_PREFIX}{assigned_station_id}", datetime.now(KST).isoformat())
    _touch(STATION_KEY, f"order:{order_id}", f"{STATION_VERIFIED_PREFIX}{assigned_station_id}")

    if _try_assign_next() is None:
        _push_station_snapshot()

    return jsonify({
        'ok': True,
        'order_id': order_id,
        'station_id': assigned_station_id,
        'board': order_data.get("board"),
        'keycap': order_data.get("keycap"),
        'colors': order_data.get("colors", "").split(",")
    }), 200

@bp.route('/station/<station_id>/complete', methods=['POST'])
def station_complete(station_id):
    """
    조립대 완료
    ---
    tags:
      - Station
    parameters:
      - in: path
        name: station_id
        type: string
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

    r.delete(order_key)
    r.delete(f"{STATION_VERIFIED_PREFIX}{station_id}")
    r.hset(STATION_KEY, station_id, "idle")
    r.hset(f"order:{order_id}", "stage", "completed")
    _touch(STATION_KEY, f"order:{order_id}")

    if _try_assign_next() is None:
        _push_station_snapshot()

    return jsonify({'ok': True, 'order_id': order_id}), 200

@bp.route('/station/<station_id>/unclaim', methods=['POST'])
def station_unclaim(station_id):
    """
    조립대 만료됨(노쇼)
    ---
    tags:
      - Station
    parameters:
      - in: path
        name: station_id
        type: string
        required: true
        example: 1
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            order_id:
              type: string
              description: 디스플레이가 들고 있던 주문 ID (서버 기록과 교차검증용)
              example: "ord_a1b2c3d4"           
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
    order_id = data.get("order_id")

    order_data = r.hgetall(f"order:{order_id}")
    if not order_data:
        return jsonify({'error': '존재하지 않거나 만료된 주문입니다'}), 404

    assigned_station_id = order_data.get("station_id")
    if not assigned_station_id:
        return jsonify({'error': '아직 조립대에 배정되지 않은 주문입니다'}), 400
    assigned_station_id = str(assigned_station_id)
    if station_id != assigned_station_id:
        return jsonify({'error': '이 조립대에 배정된 주문이 아닙니다', 'assigned_station_id': (assigned_station_id)}), 403
    if r.get(f"{STATION_ORDER_PREFIX}{station_id}") != order_id:
        return jsonify({'error': '이미 종료되었거나 이 조립대의 현재 주문이 아닙니다'}), 409
    
    prev_stage = order_data.get("stage")

    r.hset(f"order:{order_id}", "stage", "unclaimed")
    _push_station_snapshot()
    push_process(False)

    # 조립대 정리
    r.hset(STATION_KEY, station_id, "idle")
    r.delete(f"{STATION_ORDER_PREFIX}{station_id}")
    r.delete(f"{STATION_VERIFIED_PREFIX}{station_id}")
    _touch(STATION_KEY, AGV_KEY, f"order:{order_id}")

    if _try_assign_next() is None:
        _push_station_snapshot()

    return jsonify({
        'ok': True
    }), 200

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

@bp.route('/station/<station_id>/reset', methods=['POST'])
def station_reset(station_id):
    """
    warehouse/station/대기열 상태를 초기값으로 리셋.
    ---
    tags:
      - Debug
    parameters:
          - in: body
            name: station_id
            type: array
            required: false
            example: [1,2]
            schema:
              type: object
              properties:
                password:
                  type: string
                  description: 초기화 비밀번호
                  example: "reset"
                order_id:
                  type: array
                  description: 조립대 번호
                  example: ["ord_01", "ord_02"]
    responses:
      200:
        description: 초기화 완료
      404:
        description: 디버그 엔드포인트 비활성화 상태
    """
    data = request.get_json()

    station_id.split(",")
    order_id = data.get("order_id").split(",")
    password = data.get("password")

    if password != STATION_RESET_PASSWORD:
        return jsonify({"error":"비밀번호가 틀렸습니다"}), 400
    # 조립대별 order_id 같이 확인 정말 맞는 정보인지 확인 필요 아니면 오류 리턴

    try :
        for sid in station_id :
            r.hset(STATION_KEY, mapping={f"{sid}: idle"})

        r.set(WAREHOUSE_KEY, "idle")
        r.delete(WAREHOUSE_ORDER_KEY)
        r.set(AGV_KEY, "idle")
        for sid in ("1", "2", "3"):
            r.delete(f"{STATION_ORDER_PREFIX}{sid}")
            r.delete(f"{STATION_VERIFIED_PREFIX}{sid}")
        r.delete(QUEUE_KEY)
    
        _push_station_snapshot()
    
        return jsonify({'ok': True}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

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
        example: 1
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
    station_id = str(station_id)
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
        "stage": order_data["stage"]
    }), 200