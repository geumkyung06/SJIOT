"""관리자 경로 — fault 해제 · 라인 초기화 (기존)
  + 관리자 페이지 조회/조작용 stock · stations · orders · stock/refill (gsj_backend_dashborad)
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
          example: {"password": "관리자 비밀번호", "mode": "zero", "keep_queue": false}
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


# ── 여기서부터 gsj_backend_dashborad: 관리자 페이지 조회 3종 + 재고 채움 ──────

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