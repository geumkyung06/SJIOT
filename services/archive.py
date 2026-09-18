"""주문 종료 공통 경로 — 아카이브 · 집계 · 자원 해제.

종료 지점이 넷이다. 넷 다 여기로 모은다.
    완료 버튼           routes/station.py  → station_service._complete_station
    노쇼(프론트)        routes/station.py  /unclaim
    노쇼(워치독 백업)    services/watchdog.py  arrived 마감
    타임아웃            services/watchdog.py  그 외 stage 마감

아카이브에는 '아예 끝난 주문'만 들어가므로 기록의 final_status 는 completed 하나다.
정상 완료가 아닌 종료는 reason 으로 구분한다 — 노쇼는 unclaimed, 마감 초과는 timeout.
Redis·cnt_process 의 stage 는 그대로 unclaimed / completed 를 쓴다 (status 16값).

저장 (Redis ERD 5장)
    orders:archive:{YYYYMMDD}   hash   field=order_id  value=기록 JSON   TTL 90일
"""
import json
import time
from datetime import datetime

from config import (ARCHIVE_PREFIX,
                    ARCHIVE_TTL,
                    DEADLINE_KEY,
                    DISCARD_TIMEOUT_SEC,
                    ORDER_DONE_TTL,
                    STATION_ORDER_PREFIX,
                    STATION_VERIFIED_PREFIX,
                    STATION_CALL_PREFIX,
                    WAREHOUSE_ORDER_KEY,
                    KST,
                   )
from infra.extensions import r
from infra.keys import _touch_order
from infra.logger import logger


def finish_order(order_id, final_stage, reason=None):
    """주문을 끝낸다. stage 전이 → 아카이브 → 자원 해제 순서.

    stage 를 먼저 넘기는 이유 — set_stage 가 워치독을 풀고 cnt_process 를 밀어서,
    아카이브를 쓰는 동안 이 주문에 또 마감이 걸리는 일이 없다.
    """
    key = f"order:{order_id}"
    od = r.hgetall(key)
    if not od:
        logger.warning(f"[finish] {order_id} 주문 없음 — 건너뜀")
        return None

    from services.process import set_stage          # 순환 import 회피

    if reason:
        r.hset(key, "reason", reason)
    set_stage(order_id, final_stage)                # cnt_process push + 워치독 해제
    _archive(order_id, od, reason)
    _release_resources(order_id, od, final_stage)

    if final_stage == "unclaimed":
        # 폐기 마감. set_stage 뒤여야 한다 — unclaimed 는 TERMINAL 이라
        # set_stage 안의 watchdog.disarm 이 먼저 돌면서 예약을 지운다.
        r.zadd(DEADLINE_KEY, {order_id: time.time() + DISCARD_TIMEOUT_SEC})
        logger.info(f"[finish] {order_id} 폐기 대기 — 조립대 {od.get('station_id')} 는 "
                    f"AGV discarded 까지 잡아 둔다 (마감 {DISCARD_TIMEOUT_SEC}s)")
    else:
        # 끝난 주문 해시는 오래 둘 이유가 없다. 기록은 아카이브에 있다.
        _touch_order(order_id, ORDER_DONE_TTL)

    logger.info(f"[finish] {order_id} {final_stage}"
                + (f" (reason={reason}, stage={od.get('stage')})" if reason else ""))
    return order_id


def _archive(order_id, od, reason):
    date = datetime.now(KST).strftime("%Y%m%d")
    akey = f"{ARCHIVE_PREFIX}{date}"
    if r.hexists(akey, order_id):
        return                                       # 두 경로가 겹쳐도 한 번만

    colors = [c for c in (od.get("colors") or "").split(",") if c]
    rec = {
        "order_id": order_id,
        "order_seq": int(od.get("order_seq") or 0),
        "station_id": od.get("station_id"),
        "board": od.get("board"),
        "keycap": od.get("keycap"),
        "colors": colors,
        "final_status": "completed",         # 아카이브는 '끝난 주문'만 들어온다
        "created_at": od.get("created_at"),
        "ended_at": datetime.now(KST).isoformat(timespec="seconds"),
    }
    if reason:
        rec["reason"] = reason
        rec["ended_at_stage"] = od.get("stage")      # 어느 단계에서 끊겼는지
    if od.get("fault"):
        rec["fault"] = od["fault"]
    if od.get("pickup_wait_extends"):
        rec["pickup_wait_extends"] = int(od["pickup_wait_extends"])
    if od.get("call_count"):
        rec["call_count"] = int(od["call_count"])       # 관리자를 몇 번 불렀나

    r.hset(akey, order_id, json.dumps(rec, ensure_ascii=False))
    r.expire(akey, ARCHIVE_TTL)

    # stats:* 집계는 폐기했다 (2026-09-18). 쓰는 화면이 없어서 종료 경로마다
    # INCR 4건을 더 치를 이유가 없다. 필요해지면 아카이브 해시를 날짜별로 세면 된다 —
    # 같은 값이 orders:archive:{date} 의 레코드에 전부 들어 있다.


def _release_resources(order_id, od, final_stage=None):
    """창고 먼저, 조립대 나중. 각각 다음 배정을 시도한다.

    타임아웃으로 끝난 주문은 창고 구간 한복판일 수 있다. 창고를 안 풀면
    그 뒤 주문이 통째로 멈춘다 — 완료 버튼 경로에는 없던 상황이다.

    노쇼(unclaimed)만 예외다. 조립대를 여기서 풀면 station:current_order 가 지워지고,
    cnt_process 는 조립대에 올라간 주문만 싣기 때문에(process.active_order_ids)
    **AGV 가 트레이를 아직 들고 있는데 폐기 명령이 스냅샷에서 사라진다.**
    실측 0.53초 만에 사라졌다. 그래서 조립대는 AGV 가 discarded 를 올릴 때까지 잡아 둔다
    (callbacks/agv.py). 안 오면 워치독이 DISCARD_TIMEOUT_SEC 뒤에 강제로 푼다.
    """
    from services.dispatch import release_station, release_warehouse

    if r.get(WAREHOUSE_ORDER_KEY) == order_id:
        release_warehouse()

    if final_stage == "unclaimed":
        return                                   # 조립대는 폐기 완료까지 유지

    sid = od.get("station_id")
    if sid and r.get(f"{STATION_ORDER_PREFIX}{sid}") == order_id:
        r.delete(f"{STATION_VERIFIED_PREFIX}{sid}")
        r.delete(f"{STATION_CALL_PREFIX}{sid}")      # 남기면 다음 사용자가 부른 것처럼 보인다
        release_station(sid)


def release_station_after_discard(order_id):
    """AGV 가 폐기를 마쳤다 → 잡아 두던 조립대를 푼다.

    callbacks/agv.py 의 discarded 분기와 워치독의 폐기 마감, 두 곳에서 부른다.
    어느 쪽이 먼저 와도 되도록 조립대에 그 주문이 남아 있을 때만 움직인다.
    """
    from services.dispatch import release_station
    from services import watchdog

    watchdog.disarm(order_id)
    od = r.hgetall(f"order:{order_id}")
    sid = od.get("station_id")
    if not sid or r.get(f"{STATION_ORDER_PREFIX}{sid}") != order_id:
        return None                              # 이미 풀렸다
    r.delete(f"{STATION_VERIFIED_PREFIX}{sid}")
    r.delete(f"{STATION_CALL_PREFIX}{sid}")
    _touch_order(order_id, ORDER_DONE_TTL)
    logger.info(f"[finish] {order_id} 폐기 완료 — 조립대 {sid} 해제")
    return release_station(sid)                  # try_assign_next 까지 돈다
