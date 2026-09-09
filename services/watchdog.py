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

from config import DEADLINE_KEY

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
    "pickup_reached": 120,  # AGV 픽업 + 직전 주문 폐기로 자리 비우는 시간까지
    "loaded": 120,      # AGV 이동 거리에 좌우됨
    "arrived": 300,     # 프론트가 3분에 /unclaim을 친다. 이건 그게 실패했을 때의 백업
    "verified": 60,
    "received": 500,    # 사용자 조립 시간 → 초과 시 completed 일괄
}

# unclaimed는 여기 없다. TERMINAL이라 set_stage가 disarm하므로 등록해도 안 걸린다.
# 노쇼는 그 시점에 이미 정상 종료 경로다 — 조립대는 비었고 다음 주문 배정도 끝났다.
# AGV가 parked를 안 올리면 그건 AGV 고장이고, cnt_agv broken/타 주문의 마감으로 잡힌다.


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
    from services.process import set_stage, set_fault
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

    if stage == "arrived":
        set_stage(order_id, "unclaimed")              # 노쇼는 fault가 아니라 정상 종료 경로
    elif stage == "received":
        set_stage(order_id, "completed")              # 조립 타임아웃 일괄 처리
    else:
        set_fault(order_id, "stage_timeout")


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
