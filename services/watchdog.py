"""stage 체류 시간 감시.

머신이 죽으면 fault조차 안 올라온다. 이게 유일한 감지 수단이다 (명세 7장).

만료 시각을 ZSET 하나에 모은다.

    order:deadlines   score = 만료 epoch,  member = order_id

전체 주문을 훑지 않고 ZRANGEBYSCORE(0, now)로 지난 것만 뽑는다.

중간 체크포인트는 두지 않는다. 4건이 다 오면 dispense 콜백이 그 자리에서 다음 stage로
넘기므로, 중간에 세어서 얻는 건 '아직 덜 왔다'뿐이고 그 시점에 취할 행동이 없다.
신호가 늦게 오는 경우도 마감 안에만 들어오면 정상 처리된다.
"""
import time

from infra.extensions import r
from infra.logger import logger

from config import DEADLINE_KEY, DISCARD_TIMEOUT_SEC, STATION_ORDER_PREFIX

# 명세 7장. 사람·이동이 끼는 셋은 기계 속도로 재면 안 된다.
STAGE_TIMEOUT = {
    "assigned": 60,
    "keycap_mismatched": 60,
    "keycap_dispensed": 60,
    "keycap_reached": 60,
    "keycap_packed": 60,
    "tray_reached": 120, # AGV 폐기 후 위치 이동 문제. 직접 확인 후 유동적으로 처리하도록 변경 필요
    "board_mismatched": 60,
    "board_packed": 60,
    "pickup_reached": 300,  # AGV 픽업. 앞 주문이 노쇼(3분)면 그만큼 AGV가 묶이므로 그 위로 잡는다
    "loaded": 120,      # AGV 이동 거리에 좌우됨
    "arrived": 300,     # 프론트가 3분에 /unclaim을 친다. 이건 그게 실패했을 때의 백업
    "verified": 60,
    "received": 500,    # 사용자 조립 시간 → 초과 시 completed 일괄
}

# cnt_agv 보고 1건 = 'AGV가 살아 움직인다'는 증거. 픽업대에서 기다리는 주문을 그만큼 밀어준다.
# 연장은 보고가 올 때만 1건당 1회이므로, 보고가 끊기면 더 안 밀린다 — 무한 연장이 구조적으로 불가능하다.
AGV_EXTEND_SEC = 10

# unclaimed 는 STAGE_TIMEOUT 표에 없다. TERMINAL 이라 set_stage 가 disarm 하기 때문이다.
# 대신 archive.finish_order 가 set_stage **뒤에** 폐기 마감(DISCARD_TIMEOUT_SEC)을 직접 건다.
# 노쇼로 끝난 트레이는 AGV 위에 남아 있고, 조립대를 곧바로 풀면 cnt_process 에서
# 폐기 명령이 사라져 버린다 (실측 0.53초). 그래서 조립대를 잡아 둔 채 폐기를 기다린다.


def arm(order_id, stage):
    """set_stage에서 부른다. 이전 예약을 지우고 새로 건다."""
    ttl = STAGE_TIMEOUT.get(stage)
    if not ttl:
        r.zrem(DEADLINE_KEY, order_id)
        return
    r.zadd(DEADLINE_KEY, {order_id: time.time() + ttl})


def disarm(order_id):
    r.zrem(DEADLINE_KEY, order_id)


def sweep():
    """스케줄러가 1초 간격으로 부른다. 만료된 것만 뽑아 처리."""
    for order_id in r.zrangebyscore(DEADLINE_KEY, 0, time.time()):
        if r.zrem(DEADLINE_KEY, order_id) == 0:
            continue                      # 다른 워커가 먼저 가져갔다
        try:
            _expire(order_id)
        except Exception:
            logger.exception(f"[watchdog] {order_id} 처리 실패")


def _expire(order_id):
    # 순환 import 회피 — process가 watchdog.arm을 쓰므로 여기선 함수 안에서 부른다
    from services.archive import finish_order
    from services.process import set_fault
    from services import collector

    stage = r.hget(f"order:{order_id}", "stage")
    if stage is None:
        return                                        # TTL로 이미 사라진 주문

    if stage in ("assigned", "keycap_mismatched"):
        logger.error(f"[watchdog] {order_id} {stage} 마감 — "
                     f"미배출 {collector.remaining(order_id, 'keycap')} "
                     f"오배출 {collector.wrong(order_id, 'keycap')}")
    else:
        logger.error(f"[watchdog] {order_id} {stage} 마감")

    # 마감 초과 처리는 구간에 따라 다르다. 기준은 "트레이가 지금 어디 있나"다.
    #
    #   창고 구간(assigned~board_packed) · AGV 무응답(loaded·verified)
    #       → fault 로 세워 멈춘다. 트레이·부품이 벨트나 AGV 위에 남아 있어서,
    #         그대로 다음 주문을 시작하면 물리적으로 부딪힌다. 사람이 치워야 한다.
    #         기다릴 만큼 기다렸는데 신호가 없으면 그건 머신 문제다 (명세 7장).
    #
    #   pickup_reached(연장 2회 소진) · arrived · received
    #       → 그 자리에서 끝낸다. 벨트는 이미 비어 있어 라인을 계속 돌려도 안전하다.
    #         reason="timeout" 과 끊긴 stage 를 아카이브에 남긴다.
    if stage == "unclaimed":
        # 폐기 마감. AGV 가 DISCARD_TIMEOUT_SEC 안에 discarded 를 안 올렸다.
        # 주문은 이미 종료·아카이브됐으므로 여기서 할 일은 조립대를 되찾는 것뿐이다.
        # 안 풀면 조립대 한 칸이 영구 점유돼 라인이 그만큼 좁아진다.
        from services.archive import release_station_after_discard
        logger.error(f"[watchdog] {order_id} 폐기 미보고 {DISCARD_TIMEOUT_SEC}s — "
                     f"조립대 강제 해제 (AGV 확인 필요)")
        release_station_after_discard(order_id)
    elif stage == "arrived":
        finish_order(order_id, "unclaimed", reason="unclaimed")   # 노쇼 백업 경로
    elif stage == "received":
        finish_order(order_id, "completed", reason="timeout")     # 조립 타임아웃
    elif stage == "pickup_reached":
        # 연장을 다 쓰고 내려온 경우에만 여기 온다. AGV가 돌아올 가망이 없다고 본 것이므로
        # 종료는 하되 'AGV 때문에 끝났다'는 사실은 아카이브에 남긴다.
        r.hset(f"order:{order_id}", "fault", "stage_timeout")
        finish_order(order_id, "completed", reason="timeout")
    else:
        set_fault(order_id, "stage_timeout")


# ───────────────────────────────────────────────── AGV 가 미는 마감

def _pickup_waiters():
    """픽업대에서 AGV를 기다리는 주문. 조립대에 배정된 주문만 대상이다."""
    out = []
    for sid in ("1", "2", "3"):
        oid = r.get(f"{STATION_ORDER_PREFIX}{sid}")
        if oid and r.hget(f"order:{oid}", "stage") == "pickup_reached":
            out.append(oid)
    return out


def extend_pickup_waiters(sec=AGV_EXTEND_SEC):
    """cnt_agv 보고 1건마다 픽업대 대기 주문의 마감을 밀어준다 (callbacks/agv.py 에서 호출).

    마감 시점에 AGV 상태를 보고 판단하지 않는다 — 그러면 AGV가 막 풀린 찰나에 걸린
    주문이 억울하게 종료되고(실측 사례), 반대로 AGV가 그 상태로 죽으면 영원히 밀린다.
    '보고가 왔을 때만 1회' 로 두면 둘 다 생기지 않는다.
    """
    for oid in _pickup_waiters():
        dl = r.zscore(DEADLINE_KEY, oid)
        if dl is None:
            continue
        n = r.hincrby(f"order:{oid}", "pickup_wait_extends", 1)
        r.zadd(DEADLINE_KEY, {oid: dl + sec})
        logger.info(f"[watchdog] {oid} pickup_reached 마감 +{sec}s ({n}회) — AGV 보고 수신")


def rearm_pickup_waiters():
    """AGV가 대기장소로 복귀(parked)했다 → 픽업대 대기 주문의 시계를 새로 건다.

    마감은 트레이가 픽업대에 닿은 시각부터 재는데, 그때 AGV가 앞 주문에 묶여 있었다면
    그건 이 주문 잘못이 아니다. AGV가 자유로워진 시점을 기준선으로 다시 잡는다.
    여기서부터 마감 안에 안 실으면 그건 AGV 문제가 맞다.
    """
    for oid in _pickup_waiters():
        r.hdel(f"order:{oid}", "pickup_wait_extends")
        arm(oid, "pickup_reached")
        logger.info(f"[watchdog] {oid} pickup_reached 마감 재장전 — AGV 대기장소 복귀")


# ───────────────────────────────────────────────── 스케줄러

SWEEP_LOCK = "watchdog:lock"
SWEEP_INTERVAL = 1.0


def start_sweeper(interval=SWEEP_INTERVAL):
    """백그라운드 스레드로 sweep을 돌린다. APScheduler 의존성 없이.

    gunicorn 워커가 여러 개면 프로세스마다 스레드가 뜨므로 Redis 락으로 한 번만 돌게 한다.
    락이 없으면 같은 주문에 fault를 워커 수만큼 건다.
    """
    import threading

    def loop():
        while True:
            try:
                # 락을 잡은 프로세스만 이번 턴을 처리한다. TTL이 지나면 아무나 다시 잡는다.
                if r.set(SWEEP_LOCK, "1", nx=True, ex=max(2, int(interval * 2))):
                    sweep()
            except Exception:
                logger.exception("[watchdog] sweep 루프 오류")
            time.sleep(interval)

    t = threading.Thread(target=loop, name="watchdog-sweeper", daemon=True)
    t.start()
    logger.info(f"[watchdog] sweeper 시작 (interval={interval}s)")
    return t
