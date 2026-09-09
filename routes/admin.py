"""관리자 경로 — fault 해제.

fault 는 stage 를 그대로 둔 채 주문만 멈춰 세운다. 그래서 해제는 "그 자리에서 이어가기"다.
새로 밀어주는 건 `fault` 가 빠진 최신 스냅샷 하나뿐이고, 창고·AGV 는
같은 order_id 에 fault 가 없으면 해결된 것으로 본다 (명세 4-3).
"""
from flask import Blueprint, jsonify, request

from config import (QUEUE_KEY,
                    STATION_ORDER_PREFIX,
                    WAREHOUSE_ORDER_KEY,
                    STATION_RESET_PASSWORD,
                   )
from infra.extensions import r
from infra.logger import logger
from services.process import clear_fault

bp = Blueprint("admin", __name__)


def _live_order_ids():
    """큐 + 조립대 + 창고가 들고 있는 주문. 최대 7건."""
    ids = list(r.lrange(QUEUE_KEY, 0, -1))
    for sid in ("1", "2", "3"):
        oid = r.get(f"{STATION_ORDER_PREFIX}{sid}")
        if oid and oid not in ids:
            ids.append(oid)
    oid = r.get(WAREHOUSE_ORDER_KEY)
    if oid and oid not in ids:
        ids.append(oid)
    return ids


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
              example: [{"order_id": "ord_a1b2c3d4", "stage": "loaded", "fault": "agv_wrong_station", "station_id": "2"}]
    """
    out = []
    for oid in _live_order_ids():
        o = r.hgetall(f"order:{oid}")
        if o.get("fault"):
            out.append({
                "order_id": oid,
                "stage": o.get("stage"),
                "fault": o.get("fault"),
                "station_id": o.get("station_id"),
                "order_seq": o.get("order_seq"),
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
        example: ord_a1b2c3d4
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            password:
              type: string
              description: 관리자 비밀번호 (STATION_RESET_PASSWORD 와 동일)
    responses:
      200:
        description: 해제 완료. fault 가 빠진 스냅샷을 cnt_process 로 다시 push 한다
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

    clear_fault(order_id)      # hdel fault + 워치독 재장전 + cnt_process push
    logger.info(f"[admin] {order_id} fault 해제 ({fault}) stage={order.get('stage')} 유지")

    return jsonify({
        "ok": True,
        "order_id": order_id,
        "cleared": fault,
        "stage": order.get("stage"),
    }), 200
