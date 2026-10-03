import json

from infra.extensions import r
from infra.logger import logger
from datetime import datetime, timedelta

from config import (KST,
                    EXHIBITION_START_DATE,
                    EXHIBITION_DAYS,
                    ARCHIVE_PREFIX,
                    QUEUE_KEY,
                    STATION_ORDER_PREFIX,
                    WAREHOUSE_ORDER_KEY,
                   )

STATION_IDS = ("1", "2", "3")

def today_key():
    """
    오늘 날짜를 Redis 날짜 형식으로 반환
    YYYYMMDD
    """
    return datetime.now(KST).strftime("%Y%m%d")


def get_exhibition_dates():
    """
    전시회 전체 날짜 리스트 반환

    예:
    EXHIBITION_START_DATE = 20260920
    EXHIBITION_DAYS = 3

    반환:
    ["20260920", "20260921", "20260922"]
    """

    start_date = datetime.strptime(
        EXHIBITION_START_DATE,
        "%Y%m%d"
    )

    dates = []

    for i in range(EXHIBITION_DAYS):
        date = start_date + timedelta(days=i)

        dates.append(
            date.strftime("%Y%m%d")
        )

    return dates


def get_completed_archive_orders():
    """
    전시 기간의 orders:archive:{YYYYMMDD}를 조회하여
    정상 완료된 주문만 반환

    archive에는 정상 완료뿐 아니라
    unclaimed / timeout 주문도 들어갈 수 있음.

    reason이 존재하는 주문은 정상 완료가 아니므로 제외.
    """

    completed_orders = []

    for date in get_exhibition_dates():

        archive_key = f"orders:archive:{date}"

        raw_orders = r.hgetall(
            archive_key
        )

        for order_id, raw_order in raw_orders.items():

            try:
                order = json.loads(
                    raw_order
                )

            except (json.JSONDecodeError, TypeError):

                print(
                    f"[dashboard] "
                    f"잘못된 archive 데이터: {order_id}"
                )

                continue

            # unclaimed / timeout 제외
            if order.get("reason"):
                continue

            completed_orders.append(
                order
            )

    return completed_orders


def _live_order_ids():
    """
    지금 진행 중인 주문 ID
    대기열 + 조립대 + 창고 (/admin/orders 와 같은 기준, 최대 7건)

    order:* 를 SCAN 하지 않는 이유 —
    종료된 주문 해시도 ORDER_DONE_TTL(10분) 동안 남아 있어서 아카이브와 겹친다.
    """
    ids = list(r.lrange(QUEUE_KEY, 0, -1))

    for station_id in STATION_IDS:
        order_id = r.get(f"{STATION_ORDER_PREFIX}{station_id}")

        if order_id and order_id not in ids:
            ids.append(order_id)

    order_id = r.get(WAREHOUSE_ORDER_KEY)

    if order_id and order_id not in ids:
        ids.append(order_id)

    return ids


def get_order_times(date=None):
    """
    그 날짜(KST)에 접수된 모든 주문의 접수 시각(HH:MM) 리스트

    date   "YYYYMMDD". 생략하면 오늘. 형식이 틀리면 ValueError (라우트가 400 으로 돌려준다)

    order:{order_id}            진행 중 주문 → created_at
    orders:archive:{date}       종료된 주문  → 기록 JSON 의 created_at

    - 같은 분에 들어온 주문이 여러 건이면 그 수만큼 같은 시각이 들어간다
      (시각은 중복 제거하지 않는다)
    - order_id 로만 중복 제거 — 노쇼(unclaimed) 주문은 아카이브된 뒤에도
      AGV 폐기 완료까지 station:current_order 에 남아 양쪽에 다 보인다
    - 정상 완료 / unclaimed / timeout / admin_abort 구분 없이 전부 포함 (접수 시각 기준)
    - created_at 을 KST 로 바꿔 날짜가 date 인 것만 남긴다
    - 진행 중 주문은 날짜와 상관없이 늘 본다 — 자정을 넘겨 도는 주문이 어제 목록에 잡히게.
      날짜 필터가 걸러 주므로 오늘 주문이 어제 목록에 섞이지 않는다

    알려진 한계 — 아카이브는 '끝난 날짜' 키에 쌓인다. 어제 접수해 자정 뒤에 끝난 주문은
    오늘 키에 있어서 어제 목록에서 빠진다 (전시는 밤에 마감하므로 사실상 없다)

    반환: ("YYYYMMDD", ["10:02", "19:55", "19:55", ...])  오름차순
    """
    date_str = date or datetime.now(KST).strftime("%Y%m%d")
    target = datetime.strptime(date_str, "%Y%m%d").date()

    # order_id -> created_at
    created = {}

    # 1. 종료된 주문 — orders:archive:{date}
    raw_orders = r.hgetall(f"{ARCHIVE_PREFIX}{date_str}")

    for order_id, raw_order in raw_orders.items():
        try:
            order = json.loads(raw_order)

        except (json.JSONDecodeError, TypeError):
            logger.error(f"[dashboard/orders/timeline] 잘못된 archive 데이터: {order_id}")

            continue

        created[order_id] = order.get("created_at")

    # 2. 진행 중 주문 — order:{order_id}
    for order_id in _live_order_ids():
        if order_id in created:
            continue        # 노쇼 — 아카이브에서 이미 셌다

        created[order_id] = r.hget(f"order:{order_id}", "created_at")

    times = []

    for order_id, created_at in created.items():
        if not created_at:
            continue

        try:
            dt = datetime.fromisoformat(created_at)

        except (ValueError, TypeError):
            logger.warning(f"[dashboard/orders/timeline] created_at 파싱 실패: {order_id} {created_at}")

            continue

        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=KST)

        dt = dt.astimezone(KST)

        if dt.date() != target:
            continue

        # 2026-10-03T19:55:38.131711+09:00 -> 19:55
        times.append(dt.strftime("%H:%M"))

    times.sort()

    return date_str, times


def get_today_order_times():
    """오늘 목록. get_order_times() 와 같다 — 기존 호출부·테스트 호환용."""
    return get_order_times()
