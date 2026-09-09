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
    stats:{reason|completed}:{date} string 건수
    stats:mbti:{date}           hash   MBTI 분포
    stats:color:{date}          hash   색상 분포
"""
import json
from datetime import datetime

from config import (ARCHIVE_PREFIX,
                    ARCHIVE_TTL,
                    STATS_PREFIX,
                    STATION_ORDER_PREFIX,
                    STATION_VERIFIED_PREFIX,
                    WAREHOUSE_ORDER_KEY,
                    KST,
                   )
from infra.extensions import r
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
    _release_resources(order_id, od)
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

    r.hset(akey, order_id, json.dumps(rec, ensure_ascii=False))
    r.expire(akey, ARCHIVE_TTL)

    # 집계는 reason 으로 가른다 — 정상 완료 / 노쇼 / 마감 초과
    ckey = f"{STATS_PREFIX}{reason or 'completed'}:{date}"
    r.incr(ckey)
    r.expire(ckey, ARCHIVE_TTL)
    if od.get("keycap"):
        mkey = f"{STATS_PREFIX}mbti:{date}"
        r.hincrby(mkey, od["keycap"], 1)
        r.expire(mkey, ARCHIVE_TTL)
    if colors:
        skey = f"{STATS_PREFIX}color:{date}"
        for c in colors:
            r.hincrby(skey, c, 1)
        r.expire(skey, ARCHIVE_TTL)


def _release_resources(order_id, od):
    """창고 먼저, 조립대 나중. 각각 다음 배정을 시도한다.

    타임아웃으로 끝난 주문은 창고 구간 한복판일 수 있다. 창고를 안 풀면
    그 뒤 주문이 통째로 멈춘다 — 완료 버튼 경로에는 없던 상황이다.
    """
    from services.dispatch import release_station, release_warehouse

    if r.get(WAREHOUSE_ORDER_KEY) == order_id:
        release_warehouse()

    sid = od.get("station_id")
    if sid and r.get(f"{STATION_ORDER_PREFIX}{sid}") == order_id:
        r.delete(f"{STATION_VERIFIED_PREFIX}{sid}")
        release_station(sid)
