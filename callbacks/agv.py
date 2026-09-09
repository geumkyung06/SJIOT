"""cnt_agv 콜백. AGV 1대라 order_id 대신 stage로 판정한다."""
from datetime import datetime

from config import AGV_KEY, AGV_STATUS_KEY, STATION_ORDER_PREFIX, KST
from infra.extensions import r
from infra.keys import _touch
from infra.logger import logger

from services import watchdog
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


# AGV가 관여하는 구간. unclaimed·received도 넣는다 — 폐기·복귀 보고가 여기서 온다.
AGV_SCOPE = ("pickup_reached", "loaded", "arrived", "unclaimed", "verified", "received")
# 그중 'AGV가 실제로 트레이를 들고 있는' 구간 (received·unclaimed는 이미 손을 뗀 뒤)
AGV_HOLDING = ("pickup_reached", "loaded", "arrived", "verified")


def _current_order(con, status=None):
    """AGV가 들고 있는 주문. con의 order_id → station_id → 보고 내용 순으로 좁힌다.

    조립대 순번대로 첫 주문을 집으면 안 된다. 앞 조립대에 received로 남아 있는 직전 주문을
    집어서 is_at_or_past에 걸려 '재전송'으로 버려지고, 정작 보고를 올린 뒤 주문은
    그 stage에 그대로 멈춰 워치독 마감까지 방치된다.
    """
    order_id = con.get("order_id")
    if order_id:
        return order_id
    station_id = str(con.get("station_id") or "")
    if station_id:
        return r.get(f"{STATION_ORDER_PREFIX}{station_id}")

    cands = []
    for sid in ("1", "2", "3"):
        oid = r.get(f"{STATION_ORDER_PREFIX}{sid}")
        if not oid:
            continue
        stage = r.hget(f"order:{oid}", "stage")
        if stage in AGV_SCOPE:
            cands.append((oid, stage))
    if not cands:
        return None

    if status in TRANSITIONS:
        need = TRANSITIONS[status][1]
        exact = [oid for oid, stage in cands if stage == need]
        if len(exact) == 1:
            return exact[0]
        if len(exact) > 1:
            logger.error(f"[agv] 대상 주문 모호 status={status} 후보={exact} — 무시")
            return None

    holding = [oid for oid, stage in cands if stage in AGV_HOLDING]
    if len(holding) == 1:
        return holding[0]
    if len(holding) > 1:
        logger.error(f"[agv] 대상 주문 모호 status={status} 후보={holding} — 무시")
        return None
    return cands[0][0]


def on_agv(con):
    status = str(con.get("status") or "")

    # 올라온 status 를 그대로 보관한다. 진단·로그용이다.
    if status:
        r.set(AGV_STATUS_KEY, status)
        _touch(AGV_STATUS_KEY)

    if status == "parked":
        # agv:occupancy 가 idle 이 되는 지점은 여기 하나뿐이다.
        r.set(AGV_KEY, "idle")
        _touch(AGV_KEY)
        logger.info("[agv] 대기장소 복귀 — idle")
        # AGV가 자유로워졌다 → 픽업대에서 기다리던 주문의 시계를 새로 건다.
        watchdog.rearm_pickup_waiters()
        return

    # parked 를 뺀 모든 보고는 'AGV가 살아 움직인다'는 증거다.
    # 픽업대에서 기다리는 주문의 마감을 보고 1건당 한 번만 밀어준다.
    watchdog.extend_pickup_waiters()

    if status == "discarded":
        # 노쇼 폐기 완료. 주문은 이미 unclaimed로 끝났고 조립대도 비었으므로
        # stage를 건드릴 게 없다. 폐기 후 바로 대기장소로 가며 parked를 따로 올린다.
        logger.info("[agv] 폐기 완료 — 대기장소로 복귀 중")
        return

    order_id = _current_order(con, status)
    if not order_id:
        logger.warning(f"[agv] 대상 주문을 못 찾음 status={status} con={con}")
        return

    if status in FAULTS:
        set_fault(order_id, FAULTS[status])
        return

    if status not in TRANSITIONS:
        logger.warning(f"[agv] 미정의 status={status}")
        return

    # fault 는 '그 자리에서 멈춤'이다. 창고·컨베이어·로봇암 콜백은 fault 가 걸린 주문의
    # 보고를 전부 버리는데 AGV만 이 가드가 없어서, 멈춰 세운 주문이 보고 하나에
    # 다음 단계로 넘어가 버렸다 (fault 는 남은 채로 stage 만 진행).
    # fault 보고(위 FAULTS 분기)는 이 가드보다 앞에 둔다 — 새 고장은 계속 받아야 한다.
    fault = r.hget(f"order:{order_id}", "fault")
    if fault:
        logger.warning(f"[agv] {order_id} fault={fault} 정지 중 — {status} 무시")
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
        # 오배송. cnt_agv 는 order_id·station_id 를 싣기로 했으므로, 그 쌍이 배정과
        # 다르면 AGV가 엉뚱한 조립대에 선 것이다. 되돌릴 채널이 아직 없으므로
        # (명세 10-2 A3 미결) stage 는 전이시키지 않고 fault 로 세워 사람이 보게 한다.
        # 관리자가 /admin/order/{id}/fault/clear 로 풀면 stage 가 loaded 그대로라
        # AGV가 제 조립대에서 다시 station_arrived 를 올리는 순간 이어진다.
        con_sid = str(con.get("station_id") or "")
        assigned_sid = str(r.hget(f"order:{order_id}", "station_id") or "")
        if con_sid and assigned_sid and con_sid != assigned_sid:
            logger.error(f"[agv] 오배송 {order_id} 배정={assigned_sid} 도착보고={con_sid}")
            set_fault(order_id, "drop_failed")
            return

        # 노쇼 타이머의 기준 시각. 프론트도 3분을 세지만 그건 클라이언트 값이라
        # /unclaim 가드와 워치독은 이 값으로 다시 잰다. order 해시에 넣어야
        # 주문 TTL을 같이 타고 사라진다 (별도 키를 두면 정리 지점이 하나 늘어난다).
        r.hset(f"order:{order_id}", "arrived_at", datetime.now(KST).isoformat())

    set_stage(order_id, next_stage)
