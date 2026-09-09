import json

from config import WAREHOUSE_ORDER_KEY
from infra.extensions import r
from infra.logger import logger

from services import collector
from services.process import set_stage, set_fault, push_process

# 이 콜백이 정상적으로 올 수 있는 stage. 그 외는 재전송으로 보고 버린다.
KEYCAP_STAGES = {"assigned", "keycap_mismatched"}
BOARD_STAGES = {"tray_reached", "board_mismatched"}

MAX_RETRY = 2

# 주문의 board는 'blue', 카트리지 컨테이너는 cnt_b.
BOARD_CODE = {"red": "r", "yellow": "y", "green": "g", "blue": "b"}


def handle_warehouse(path, con):
    """path 는 라우터가 'cnt_warehouse'를 뗀 나머지.
        ['cnt_keycap_dispense']
        ['cnt_keycap_status', 'cnt_E_r']
    """
    match path:
        case ["cnt_keycap_dispense"]:
            on_keycap_dispense(con)
        case ["cnt_board_dispense"]:
            on_board_dispense(con)
        case ["cnt_keycap_status", cnt_rn]:
            on_cartridge_status("keycap", cnt_rn.removeprefix("cnt_"), con)
        case ["cnt_board_status", cnt_rn]:
            on_cartridge_status("board", cnt_rn.removeprefix("cnt_"), con)
        case _:
            logger.warning(f"[warehouse] 미정의 경로: {'/'.join(path)}")


# 공통 가드
def _current_order(con, allow_stages, tag):
    """(order_id, stage) 또는 None.

    가드 4단 — 진행 중 주문 있음 / order_id 일치 / fault 없음 / stage 맞음.
    stage 가드가 재전송·유령 알림을 거른다. 여기서 걸러야 뒤 로직이 단순해진다.
    """
    order_id = r.get(WAREHOUSE_ORDER_KEY)
    if not order_id:
        logger.warning(f"[{tag}] 진행 중 창고 주문 없음 — 무시")
        return None

    recv = con.get("order_id")
    if recv and recv != order_id:
        logger.warning(f"[{tag}] order_id 불일치 recv={recv} cur={order_id}")
        return None

    stage, fault = r.hmget(f"order:{order_id}", "stage", "fault")
    if fault:
        logger.warning(f"[{tag}] fault={fault} 정지 중 — 무시")
        return None
    if stage not in allow_stages:
        logger.warning(f"[{tag}] stage={stage} (기대 {sorted(allow_stages)}) — 무시")
        return None

    return order_id, stage


def _parts_of(order_id, kind):
    """주문이 쓰는 카트리지 id 목록.
        keycap → ['E_r', 'S_y', 'F_b', 'J_g']
        board  → ['b']
    """
    o = r.hgetall(f"order:{order_id}")
    if kind == "board":
        board = o.get("board")
        return [BOARD_CODE.get(board, board)] if board else []
    letters = o.get("keycap") or ""
    colors = json.loads(o.get("colors") or "[]")
    return [f"{ch}_{c}" for ch, c in zip(letters, colors)]


def _mismatch(order_id, slot):
    """불일치 — 재출고 2회까지, 초과하면 종료."""
    n = r.hincrby(f"order:{order_id}", f"{slot}_retry", 1)
    left = collector.retry(order_id, slot)   # 오배출 기록만 비우고 부족분을 남긴다

    if n > MAX_RETRY:
        logger.error(f"[{slot}] 재출고 {MAX_RETRY}회 초과 — 주문 종료 필요 (부족분 {left})")
        # TODO: finish_order(order_id, "completed", reason=f"{slot}_mismatch") 연결
        set_fault(order_id, f"{slot}_cartridge_failed")
        return

    logger.warning(f"[{slot}] 불일치 {n}회차 — 부족분 {left} 재출고")
    set_stage(order_id, f"{slot}_mismatched")


# 키캡 배출 (4건)
def on_keycap_dispense(con):
    """con = {"order_id": "ord_1234", "keycap": "E_r"} — 주문당 4건.

    배정 시점에 깔아둔 pending 4개를 하나씩 지운다.
    다 지워지기 전에는 Redis만 갱신하고 끝 — cnt_process는 나가지 않는다.
    """
    got = _current_order(con, KEYCAP_STAGES, "keycap_dispense")
    if got is None:
        return
    order_id, _ = got

    keycap = con.get("keycap")
    if not keycap:
        logger.warning("[keycap_dispense] keycap 필드 없음")
        return

    result, left = collector.consume(order_id, "keycap", keycap)
    logger.info(f"[keycap_dispense] {order_id} {keycap} → {result} 남은={left}")

    match result:
        case "waiting":
            return                                    # 아직 안 모임. 여기서 끝.
        case "done":
            set_stage(order_id, "keycap_dispensed")   # hset + _touch + cnt_process push
        case "unexpected":
            _mismatch(order_id, "keycap")


# 보드 배출 (1건)
def on_board_dispense(con):
    """con = {"order_id": "ord_1234", "board": "blue"} — 주문당 1건.

    board_packed는 이 색 대조 + cnt_board_robot_arm 의 done, 둘 다 있어야 한다(명세 6-2).
    그래서 여기서는 플래그만 세우고 완성 판정은 try_board_packed에 맡긴다.
    """
    got = _current_order(con, BOARD_STAGES, "board_dispense")
    if got is None:
        return
    order_id, _ = got

    board = con.get("board")
    if not board:
        logger.warning("[board_dispense] board 필드 없음")
        return

    result, left = collector.consume(order_id, "board", BOARD_CODE.get(board, board))
    logger.info(f"[board_dispense] {order_id} {board} → {result}")

    match result:
        case "waiting":
            return
        case "done":
            collector.mark(order_id, "board_dispensed")
            try_board_packed(order_id)
        case "unexpected":
            _mismatch(order_id, "board")


def try_board_packed(order_id):
    """dispense 색 일치 + robot_arm done. 늦게 온 쪽이 완성을 확인한다.
    callbacks/robot_arm.py 의 on_board_robot_arm 에서도 이 함수를 부른다."""
    if collector.has_all(order_id, "board_dispensed", "board_placed"):
        set_stage(order_id, "board_packed")


# 카트리지 상태
def on_cartridge_status(kind, cartridge_id, con):
    """con = {"order_id": ..., "count": 6, "status": "idle"}

    stage와 무관하다. 배출 시작(busy)·완료(idle)로 주문당 2회씩 올라오고,
    진행 중 주문이 없을 때도 온다. 재고는 무조건 덮어쓴다.
    """
    count = con.get("count")
    status = con.get("status")
    r.hset("warehouse:stock", cartridge_id,
           json.dumps({"count": count, "status": status}))
    logger.info(f"[{kind}_status] {cartridge_id} count={count} status={status}")

    if status in ("idle", "busy"):
        # count가 0이 되면 restock 목록이 바뀐다. 내용이 같으면 push_process가 알아서 안 올린다.
        push_process()
        return

    # disable / empty — 진행 중 주문이 그 칸을 쓸 때만 fault (명세 6-3)
    order_id = r.get(WAREHOUSE_ORDER_KEY)
    if order_id and cartridge_id in _parts_of(order_id, kind):
        fault = f"{kind}_empty" if status == "empty" else f"{kind}_cartridge_failed"
        set_fault(order_id, fault)          # 안에서 push_process를 부른다
    else:
        logger.warning(f"[{kind}_status] {cartridge_id}={status} — 해당 조합 주문 차단")
        push_process()                      # 진행 주문이 없어도 restock 목록은 나가야 한다