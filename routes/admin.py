"""관리자 경로 — fault 해제 · 라인 초기화.

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
from services import recovery
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


@bp.route("/admin/reset", methods=["POST"])
def admin_reset():
    """
    라인 초기화 — 처음 켤 때 / 사고 복구
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
            password:
              type: string
              description: 관리자 비밀번호 (STATION_RESET_PASSWORD 와 동일)
            mode:
              type: string
              enum: [zero, mobius]
              default: zero
              description: >
                zero   — 전부 초기값. 재고 36칸을 STOCK_MAX_COUNT 로, 전 설비 idle,
                         진행 중 주문 전부 삭제. 전시회 첫날 시작 전처럼
                         '아무것도 진행 중이 아니어야 할 때'.
                mobius — zero 를 돌린 뒤 Mobius 최신값으로 덮어쓴다. 재고·AGV·
                         진행 중 주문을 되찾는다. 사고 복구, 2일차 시작 전.
            keep_queue:
              type: boolean
              default: false
              description: >
                대기열(order:queue)과 그 주문 해시를 보존할지. 대기열은 Mobius 어디에도
                없어서 지우면 복구가 불가능하다 (cnt_process 는 조립대에 올라간 주문만 싣는다).
    responses:
      200:
        description: 초기화 완료. 무엇을 지우고 무엇을 복구했는지 보고서를 돌려준다
      400:
        description: 비밀번호 불일치 또는 알 수 없는 mode
      500:
        description: 초기화 중 오류
    """
    data = request.get_json(silent=True) or {}
    if data.get("password") != STATION_RESET_PASSWORD:
        return jsonify({"error": "비밀번호가 틀렸습니다"}), 400

    mode = str(data.get("mode") or "zero")
    if mode not in ("zero", "mobius"):
        return jsonify({"error": "mode 는 zero 또는 mobius 여야 합니다", "got": mode}), 400

    try:
        report = recovery.reset(mode=mode, keep_queue=bool(data.get("keep_queue")))
    except Exception as e:
        logger.exception("[admin] 초기화 실패")
        return jsonify({"error": str(e)}), 500

    return jsonify({"ok": True, **report}), 200
