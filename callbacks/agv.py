"""cnt_agv 콜백. AGV 1대라 order_id 대신 stage로 판정한다."""
from datetime import datetime

from config import AGV_KEY, STATION_ORDER_PREFIX, KST
from infra.extensions import r
from infra.keys import _touch
from infra.logger import logger

from services.process import set_stage, set_fault, is_at_or_past

# status → (전이할 stage, 필요한 직전 stage)
TRANSITIONS = {
    "loaded": ("loaded", "pickup_reached"),
    "station_arrived": ("arrived", "loaded"),
    "unloaded": ("received", "verified"),
}

FAULTS = {
    "load_failed": "pickup_failed",
    "unload_failed": "drop_failed",
    "move_accident": "agv_collided",
    "broken": "agv_broken",
}


def handle_agv(path, con):
    if path:
        logger.warning(f"[agv] 미정의 경로: {'/'.join(path)}")
        return
    on_agv(con)


def _current_order(con):
    """AGV가 들고 있는 주문. con의 order_id를 우선하고, 없으면 조립대에서 찾는다."""
    order_id = con.get("order_id")
    if order_id:
        return order_id
    station_id = str(con.get("station_id") or "")
    if station_id:
        return r.get(f"{STATION_ORDER_PREFIX}{station_id}")
    # AGV는 1대다. pickup_reached~received 구간의 주문이 곧 AGV가 든 주문.
    # unclaimed·received도 넣는다 — 노쇼 폐기(discarded)와 복귀 보고가 이 구간에서 온다.
    for sid in ("1", "2", "3"):
        oid = r.get(f"{STATION_ORDER_PREFIX}{sid}")
        if oid and r.hget(f"order:{oid}", "stage") in (
            "pickup_reached", "loaded", "arrived", "unclaimed", "verified", "received"
        ):
            return oid
    return None


def on_agv(con):
    status = str(con.get("status") or "")

    if status == "parked":
        r.set(AGV_KEY, "idle")
        _touch(AGV_KEY)
        logger.info("[agv] 대기장소 복귀 — idle")
        return

    if status == "discarded":
        # 노쇼 폐기 완료. 주문은 이미 unclaimed로 끝났고 조립대도 비었으므로
        # stage를 건드릴 게 없다. AGV는 대기장소로 복귀하며 parked를 따로 올린다.
        # (AGV팀 회신 전까지 값은 discarded로 고정 — unloaded로 온다면 여기 추가)
        logger.info("[agv] 폐기 완료 — parked 대기")
        return

    order_id = _current_order(con)
    if not order_id:
        logger.warning(f"[agv] 대상 주문을 못 찾음 status={status} con={con}")
        return

    if status in FAULTS:
        set_fault(order_id, FAULTS[status])
        return

    if status not in TRANSITIONS:
        logger.warning(f"[agv] 미정의 status={status}")
        return

    next_stage, need = TRANSITIONS[status]
    stage = r.hget(f"order:{order_id}", "stage")
    if is_at_or_past(stage, next_stage):
        logger.info(f"[agv] {order_id} 이미 {stage} — 재전송으로 보고 무시")
        return
    if not is_at_or_past(stage, need):
        logger.warning(f"[agv] {order_id} stage={stage} (기대 {need} 이후) — 무시")
        return

    if status == "loaded":
        r.set(AGV_KEY, "busy")
        _touch(AGV_KEY)

    if status == "station_arrived":
        # 오배송 감지. AGV가 실어 보낸 조립대와 배정된 조립대가 다르면 경고만 남긴다
        # (AGV에게 되돌릴 채널이 없다 — 명세 10-2 A3 미결).
        con_sid = str(con.get("station_id") or "")
        assigned_sid = str(r.hget(f"order:{order_id}", "station_id") or "")
        if con_sid and assigned_sid and con_sid != assigned_sid:
            logger.error(f"[agv] 오배송 의심 {order_id} "
                         f"배정={assigned_sid} 도착보고={con_sid}")

        # 노쇼 타이머의 기준 시각. 프론트도 3분을 세지만 그건 클라이언트 값이라
        # /unclaim 가드와 워치독은 이 값으로 다시 잰다. order 해시에 넣어야
        # 주문 TTL을 같이 타고 사라진다 (별도 키를 두면 정리 지점이 하나 늘어난다).
        r.hset(f"order:{order_id}", "arrived_at", datetime.now(KST).isoformat())

    set_stage(order_id, next_stage)
