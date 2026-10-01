"""cnt_robot_arm/* 콜백.

    cnt_keycap_robot_arm  {order_id, keycapN: done}  4건 누적 → keycap_packed
    cnt_board_robot_arm   {order_id, board: done}    dispense 색 일치와 함께 → board_packed
    cnt_tray_robot_arm    {order_id, status: done}   빈 트레이 투입 확인 (stage 전이 없음)
"""
from config import WAREHOUSE_ORDER_KEY
from infra.extensions import r
from infra.logger import logger

from services import collector
from services.process import set_stage, set_fault, is_at_or_past
from callbacks.warehouse import try_board_packed

PACK_SLOTS = ["keycap1", "keycap2", "keycap3", "keycap4"]


def handle_robot_arm(path, con):
    match path:
        case ["cnt_keycap_robot_arm"]:
            on_keycap_robot_arm(con)
        case ["cnt_board_robot_arm"]:
            on_board_robot_arm(con)
        case ["cnt_tray_robot_arm"]:
            on_tray_robot_arm(con)
        case _:
            logger.warning(f"[robot_arm] 미정의 경로: {'/'.join(path)}")


def _order(con, tag):
    order_id = r.get(WAREHOUSE_ORDER_KEY)
    if not order_id:
        logger.warning(f"[{tag}] 진행 중 주문 없음 — 무시")
        return None
    recv = con.get("order_id")
    if recv and recv != order_id:
        logger.warning(f"[{tag}] order_id 불일치 recv={recv} cur={order_id}")
        return None
    stage, fault = r.hmget(f"order:{order_id}", "stage", "fault")
    if fault:
        logger.warning(f"[{tag}] fault={fault} 정지 중 — 무시")
        return None
    return order_id, stage


def on_keycap_robot_arm(con):
    """넣을 때마다 1건. 4건 다 모여야 keycap_packed."""
    got = _order(con, "keycap_robot_arm")
    if got is None:
        return
    order_id, stage = got

    for slot in PACK_SLOTS:
        value = con.get(slot)
        if value is None:
            continue
        if value == "failed":
            logger.error(f"[keycap_robot_arm] {order_id} {slot} 적재 실패")
            # slot 은 keycap1~4 = 선반 번호와 같은 축이다 (services/stock.py 의 SHELVES).
            set_fault(order_id, "keycap_pack_failed",     # W2 — 재시도 여부 창고팀 확인 중
                      section=f"keycap_robot_arm:{slot}")
            return

        # keycap_reached에 처음 들어올 때 목록이 없으면 여기서 깐다
        if not collector.remaining(order_id, "keycap_pack") and not is_at_or_past(stage, "keycap_packed"):
            collector.arm(order_id, "keycap_pack", PACK_SLOTS)

        result, left = collector.consume(order_id, "keycap_pack", slot)
        logger.info(f"[keycap_robot_arm] {order_id} {slot} → {result} 남은={left}")
        if result == "done" and not is_at_or_past(stage, "keycap_packed"):
            set_stage(order_id, "keycap_packed")
        return

    logger.info(f"[keycap_robot_arm] {order_id} 처리할 필드 없음 — {con}")


def on_board_robot_arm(con):
    got = _order(con, "board_robot_arm")
    if got is None:
        return
    order_id, _ = got

    if con.get("board") == "failed":
        logger.error(f"[board_robot_arm] {order_id} 보드 적재 실패")
        set_fault(order_id, "board_pack_failed", section="board_robot_arm")
        return
    if con.get("board") != "done":
        return

    collector.mark(order_id, "board_placed")
    try_board_packed(order_id)      # dispense 색 대조와 둘 다 모여야 board_packed


def on_tray_robot_arm(con):
    got = _order(con, "tray_robot_arm")
    if got is None:
        return
    order_id, _ = got

    if con.get("status") == "failed":
        logger.error(f"[tray_robot_arm] {order_id} 빈 트레이 투입 실패")
        set_fault(order_id, "tray_load_failed", section="tray_robot_arm")
        return
    logger.info(f"[tray_robot_arm] {order_id} 빈 트레이 투입 확인")
