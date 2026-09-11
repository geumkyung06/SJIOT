"""관리자 경로 — fault 해제 · 라인 초기화 (기존)
  + 관리자 페이지 조회용 stock · stations · orders (신규, gsj_backend_dashborad)

fault 는 stage 를 그대로 두고 그 주문만 멈춘다. 그래서 이걸 해제해주면
"그 자리에서 이어간다" — 새로 만들어주는 게 아니라 `fault` 값이 빈 최신 스냅샷을
하나 더 얹고, 창고쨌AGV 는 같은 order_id 에 fault 가 없으면 재결로 판정한다 (명세 4-3).
"""
from flask import Blueprint, jsonify, request

from config import (QUEUE_KEY,
                    STATION_KEY,
                    STATION_ORDER_PREFIX,
                    WAREHOUSE_ORDER_KEY,
                    STATION_RESET_PASSWORD,
                   )
from infra.extensions import r
from infra.logger import logger
from services import recovery
from services.process import clear_fault
from services.stock import get_stocks

bp = Blueprint("admin", __name__)

# mode=hard 는 90일 보관 기록(아카이브쨌집계쨌일련번호)을 지운다.
# 비밀번호와 별도로 실수로 맞을 수 있으니 문자열을 하나 더 요구한다.
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
    """order:{id} 해시를 관리자 페이지용 dict로 변환. 없으면 None."""
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
        "order_seq": order_hash.get("order_seq"),
        "created_at": order_hash.get("created_at"),
    }


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
        description: 해제 완료. fault 가 빈 최신 스냅샷을 cnt_process 로 다시 push 한다
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

    clear_fault(order_id)      # hdel fault + 터치 시각 갱신 + cnt_process push
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
          example: {"password": "관리자 비밀번호", "mode": "zero", "keep_queue": false}
          properties:
            password:
              type: string
              description: "관리자 비밀번호 (STATION_RESET_PASSWORD 와 동일)"
            mode:
              type: string
              enum: [zero, mobius, hard]
              default: zero
              description: "zero=전부 초기값(재고 36칸을 STOCK_MAX_COUNT 로, 조립대쨌창고쨌AGV idle, 진행 중 주문 전부 삭제) 쨌 mobius=zero 후 Mobius 최신값으로 복구 쨌 hard=zero + 아카이브쨌집계쨌일련번호까지 삭제(confirm 필요)"
            confirm:
              type: string
              description: "mode=hard 전용쨌필수. 정확히 HARD-RESET 을 입력해야 한다."
            keep_queue:
              type: boolean
              default: false
              description: "대기열(order:queue)과 그 주문 내역을 보존할지."
            reset_seq:
              type: boolean
              default: false
              description: "mode=hard 전용. process:seq 까지 리셋."
            flush_unknown:
              type: boolean
              default: false
              description: "mode=hard 전용. 알려지지 않은 키까지 삭제."
    responses:
      200:
        description: 초기화 완료. 무엇을 지웠고 무엇을 복구했는지 보고서를 돌려준다.
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
            "will_delete": ["orders:archive:*", "stats:*", "order:counter:*",
                            "상태쨌진행 중 주문 전부"],
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


# ── 여기서부터 gsj_backend_dashborad: 관리자 페이지 조회 3종 ──────────────

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
    stocks = get_stocks()  # 예: {"keycap": {"E_r": 50, ...}, "board": {"r": 30, ...}}
    if stocks is None:
        return jsonify({"error": "재고 정보가 아직 없습니다"}), 503

    result = {"board": {}, "keycap": {}}

    for color, qty in stocks.get("board", {}).items():
        result["board"][color] = {
            "qty": qty,
            "max": WAREHOUSE_MAX["board"].get(color, 0),
        }

    for slot, qty in stocks.get("keycap", {}).items():
        # slot 예: "E_r" -> letter="E", color="r"
        letter, _, color = slot.partition("_")
        result["keycap"].setdefault(letter, {})
        result["keycap"][letter][color] = {
            "qty": qty,
            "max": WAREHOUSE_MAX["keycap"].get(letter, {}).get(color, 0),
        }

    return jsonify(result), 200


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
    occupancy = r.hgetall(STATION_KEY)  # 예: {"1": "busy", "2": "idle"} (없으면 {})

    stations = []
    for sid in STATION_IDS:
        status = occupancy.get(sid, "idle")
        order_id = r.get(f"{STATION_ORDER_PREFIX}{sid}")  # 없으면 None

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
    모든 주문 조회 (관리자 페이지용) — 대기열 + 조립대 + 창고가 들고 있는 주문 전부
    ---
    tags:
      - Admin
    responses:
      200:
        description: 현재 살아있는(TTL 만료 전) 주문 전체 목록
    """
    orders = []
    for order_id in _live_order_ids():
        summary = _get_order_summary(order_id)
        if summary:  # TTL 만료 등으로 이미 사라졌으면 건너뜀
            orders.append(summary)

    return jsonify({"orders": orders}), 200