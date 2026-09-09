import json

from flask import Blueprint, jsonify, request

from infra.logger import logger

from callbacks.warehouse import handle_warehouse
from callbacks.conveyor import handle_conveyor
from callbacks.robot_arm import handle_robot_arm
from callbacks.agv import handle_agv

from infra.mobius import _extract_notification_con

bp = Blueprint("callback", __name__)

# 컨테이너 그룹별 담당 모듈
HANDLERS = {
    "cnt_warehouse": handle_warehouse,   # 카트리지 36 + dispense 2
    "cnt_conveyor": handle_conveyor,     # keycap · tray 벨트
    "cnt_robot_arm": handle_robot_arm,   # keycap · board · tray 로봇암
    "cnt_agv": handle_agv,               # AGV 보고
}

@bp.route("/mobius/callback/<path:cnt>", methods=["POST"])
def mobius_callback(cnt):
    """
    Mobius 구독 알림 수신 (44개 컨테이너 공용)
    ---
    tags:
      - Callback
    parameters:
      - in: path
        name: cnt
        type: string
        required: true
        description: 컨테이너 경로. 예 cnt_warehouse/cnt_keycap_dispense
        example: cnt_warehouse/cnt_keycap_dispense
      - in: body
        name: body
        required: true
        schema:
          type: object
    responses:
      200:
        description: 수신 완료
      400:
        description: payload 파싱 실패
      404:
        description: 등록되지 않은 컨테이너
    """
    data = request.get_json(force=True, silent=True) or {}

    # 구독 생성 직후 Mobius가 보내는 검증 요청 → 200만 돌려주면 구독 활성화
    if (data.get("m2m:sgn") or {}).get("vrq"):
        logger.info(f"[callback:{cnt}] 구독 검증 요청")
        return jsonify({"ok": True}), 200

    parts = cnt.strip("/").split("/")     # ['cnt_warehouse', 'cnt_keycap_status', 'cnt_E_r']
    group = parts[0]

    handler = HANDLERS.get(group)
    if handler is None:
        logger.warning(f"[callback] 등록되지 않은 컨테이너: {cnt}")
        return jsonify({"error": f"unknown container: {group}"}), 404

    try:
        con = _extract_notification_con(data) # json
    except (KeyError, TypeError, ValueError) as e:
        logger.warning(f"[callback:{cnt}] con 파싱 실패: {e}")
        return jsonify({"error": "bad notification payload"}), 400

    logger.info(f"[callback:{cnt}] con={json.dumps(con, ensure_ascii=False)[:300]}")

    try:
        # 2차 분기는 각 모듈이 한다. 그룹 이름을 뗀 나머지 경로만 넘긴다.
        #   ['cnt_keycap_dispense']  /  ['cnt_keycap_status', 'cnt_E_r']  /  []
        handler(parts[1:], con)
    except Exception:
        logger.exception(f"[callback:{cnt}] 처리 실패")

    return jsonify({"ok": True}), 200