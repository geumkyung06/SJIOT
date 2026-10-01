import json

from infra.extensions import r
from datetime import datetime, timedelta

from config import KST, EXHIBITION_START_DATE, EXHIBITION_DAYS

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
