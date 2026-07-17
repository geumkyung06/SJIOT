from datetime import datetime

from flask import Blueprint, jsonify, request

from services.extensions import r 

bp = Blueprint('order', __name__)

@bp.route('/robot/<robot_id>/done', methods=['POST'])
def robot_done(robot_id):
    if robot_id not in ["1", "2", "3"]:
        return jsonify({'error': '존재하지 않는 로봇입니다'}), 400

    # 현재 로봇이 하던 주문 완료 처리 (선택: 어떤 주문이었는지 찾아서 status를 done으로)
    # 로봇→주문 매핑을 찾으려면 order:* 를 스캔해야 하는데, 나중에 robot:current:{robot_id} 같은 키로 관리하면 더 깔끔해요

    r.hset("robot:status", robot_id, "idle")

    next_order = r.lpop("order:queue")
    if next_order:
        order_data = r.hgetall(f"order:{next_order}")
        r.hset("robot:status", robot_id, "busy")
        r.hset(f"order:{next_order}", mapping={
            "status": "assigned",
            "robot_id": robot_id
        })
        # send_to_mobius(next_order, order_data["board"], order_data["keycap"], order_data["colors"].split(","), robot_id)

        return jsonify({
            'message': f'로봇 {robot_id} 완료, 다음 주문 배정됨',
            'next_order_id': next_order
        }), 200

    return jsonify({'message': f'로봇 {robot_id} 완료, 대기열 없음'}), 200