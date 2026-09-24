import json
import os

from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from flask import Blueprint, jsonify

from infra.extensions import r


# =========================================================
# 기본 설정
# =========================================================

bp = Blueprint(
    "dashboard",
    __name__,
    url_prefix="/dashboard"
)

KST = ZoneInfo("Asia/Seoul")

EXHIBITION_START_DATE = os.getenv(
    "EXHIBITION_START_DATE",
    "20260918"
)

EXHIBITION_DAYS = int(
    os.getenv("EXHIBITION_DAYS", "3")
)


# =========================================================
# 공통 함수
# =========================================================

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


# =========================================================
# 1. 재고 현황
# GET /dashboard/stocks
# =========================================================

@bp.route("/stocks", methods=["GET"])
def get_dashboard_stocks():
    """
    대시보드 재고 현황 조회
    ---
    tags:
      - Dashboard

    summary: 대시보드 재고 현황 조회

    responses:
      200:
        description: 재고 현황 조회 성공

      400:
        description: 재고 현황 조회 실패
    """

    try:

        raw_stock = r.hgetall(
            "warehouse:stock"
        )

        stocks = {}

        for cartridge_id, value in raw_stock.items():

            stock_data = json.loads(
                value
            )

            stocks[cartridge_id] = {
                "count": stock_data["count"],
                "status": stock_data["status"]
            }

        return jsonify({
            "success": True,
            "stocks": stocks
        }), 200


    except Exception as e:

        print(
            "[dashboard/stocks ERROR]",
            e
        )

        return jsonify({
            "success": False,
            "error": "재고 정보를 조회하지 못했습니다."
        }), 400


# =========================================================
# 2. 주문 건수
# GET /dashboard/orders/stats
# =========================================================

@bp.route("/orders/stats", methods=["GET"])
def get_order_summary():
    """
    대시보드 주문 현황 조회
    ---
    tags:
      - Dashboard

    summary: 대시보드 주문 건수 조회

    description: |
      대시보드 하단의 주문 건수 정보를 반환합니다.

      반환 정보:

      - total_orders
        - 전시 기간 전체 주문 건수

      - today_orders
        - 오늘 생성된 주문 건수

      - waiting_orders
        - 현재 대기열에 있는 주문 건수

      - completed_today
        - 오늘 정상 완료된 주문 건수

    responses:
      200:
        description: 주문 현황 조회 성공
        schema:
          type: object
          properties:

            success:
              type: boolean
              example: true

            total_orders:
              type: integer
              description: 전시 기간 전체 주문 건수
              example: 59

            today_orders:
              type: integer
              description: 오늘 생성된 주문 건수
              example: 10

            waiting_orders:
              type: integer
              description: 현재 대기 주문 건수
              example: 4

            completed_today:
              type: integer
              description: 오늘 정상 완료된 주문 건수
              example: 7

      400:
        description: 주문 현황 조회 실패
    """

    try:

        today = today_key()


        # ==========================================
        # 1. 전시회 전체 주문 건수
        #
        # order:counter:{YYYYMMDD}
        # ==========================================

        total_orders = 0

        for date in get_exhibition_dates():

            count = r.get(
                f"order:counter:{date}"
            )

            total_orders += int(
                count or 0
            )


        # ==========================================
        # 2. 오늘 주문 건수
        # ==========================================

        today_orders = int(
            r.get(
                f"order:counter:{today}"
            ) or 0
        )


        # ==========================================
        # 3. 현재 대기 주문 건수
        # ==========================================

        waiting_orders = r.llen(
            "order:queue"
        )


        # ==========================================
        # 4. 오늘 정상 완료 주문 건수
        #
        # orders:archive:{today}에서
        # reason이 없는 주문만 계산
        # ==========================================

        completed_today = 0

        raw_orders = r.hgetall(
            f"orders:archive:{today}"
        )

        for order_id, raw_order in raw_orders.items():

            try:
                order = json.loads(
                    raw_order
                )

            except (json.JSONDecodeError, TypeError):

                print(
                    f"[dashboard/orders/stats] "
                    f"잘못된 archive 데이터: {order_id}"
                )

                continue

            # reason이 없으면 정상 완료
            if not order.get("reason"):

                completed_today += 1


        # ==========================================
        # 반환
        # ==========================================

        return jsonify({
            "success": True,
            "total_orders": total_orders,
            "today_orders": today_orders,
            "waiting_orders": waiting_orders,
            "completed_today": completed_today
        }), 200


    except Exception as e:

        print(
            "[dashboard/orders/stats ERROR]",
            e
        )

        return jsonify({
            "success": False,
            "error": "주문 현황을 조회하지 못했습니다."
        }), 400


# =========================================================
# 3. 주문 통계
# GET /dashboard/statistics
# =========================================================

@bp.route("/statistics", methods=["GET"])
def get_dashboard_statistics():
    """
    대시보드 주문 통계 조회
    ---
    tags:
      - Dashboard

    summary: 완료 주문 기반 대시보드 통계 조회

    description: |
      전시 기간의 orders:archive:{YYYYMMDD} 데이터를
      직접 조회하여 정상 완료된 주문의 통계를 계산합니다.

      reason이 존재하는 unclaimed / timeout 주문은
      통계에서 제외합니다.

      반환 정보:

      - completed_orders
        - 전시 기간 정상 완료 주문 건수

      - mbti_stats
        - MBTI별 완료 주문 수
        - 비율
        - 순위

      - keycap_color_stats
        - 키캡 색상별 사용 개수
        - 색상별 사용 비율

      - top_keycap_combo
        - 가장 많이 선택된 키캡 색상 조합
        - 해당 조합의 주문 수

    responses:
      200:
        description: 대시보드 통계 조회 성공
        schema:
          type: object
          properties:

            success:
              type: boolean
              example: true

            completed_orders:
              type: integer
              description: 전시 기간 정상 완료 주문 건수
              example: 10

            mbti_stats:
              type: array
              description: MBTI별 완료 주문 통계
              items:
                type: object
                properties:

                  rank:
                    type: integer
                    example: 1

                  mbti:
                    type: string
                    example: ENTP

                  count:
                    type: integer
                    example: 5

                  ratio:
                    type: number
                    format: float
                    example: 50.0

            keycap_color_stats:
              type: object
              description: 키캡 색상별 사용 통계

            top_keycap_combo:
              type: object
              nullable: true
              description: 가장 많이 선택된 키캡 색상 조합

      400:
        description: 대시보드 통계 조회 실패
    """

    try:

        # ==========================================
        # 전시 기간 정상 완료 주문 가져오기
        # ==========================================

        orders = get_completed_archive_orders()

        completed_orders = len(
            orders
        )


        # ==========================================
        # 1. MBTI 통계
        # ==========================================

        mbti_counts = {}

        for order in orders:

            mbti = order.get(
                "keycap"
            )

            if not mbti:
                continue

            mbti_counts[mbti] = (
                mbti_counts.get(
                    mbti,
                    0
                ) + 1
            )


        # 주문 수 기준 내림차순
        sorted_mbti = sorted(
            mbti_counts.items(),
            key=lambda x: x[1],
            reverse=True
        )


        mbti_stats = []

        for rank, (mbti, count) in enumerate(
            sorted_mbti,
            start=1
        ):

            ratio = (
                round(
                    count
                    / completed_orders
                    * 100,
                    2
                )
                if completed_orders > 0
                else 0
            )

            mbti_stats.append({
                "rank": rank,
                "mbti": mbti,
                "count": count,
                "ratio": ratio
            })


        # ==========================================
        # 2. 키캡 색상별 통계
        # ==========================================

        color_counts = {}

        for order in orders:

            colors = order.get(
                "colors",
                []
            )

            if not isinstance(
                colors,
                list
            ):
                continue

            for color in colors:

                color_counts[color] = (
                    color_counts.get(
                        color,
                        0
                    ) + 1
                )


        # 전체 사용 키캡 개수
        total_keycaps = sum(
            color_counts.values()
        )


        keycap_color_stats = {}

        for color, count in color_counts.items():

            ratio = (
                round(
                    count
                    / total_keycaps
                    * 100,
                    2
                )
                if total_keycaps > 0
                else 0
            )

            keycap_color_stats[color] = {
                "count": count,
                "ratio": ratio
            }


        # ==========================================
        # 3. 키캡 색상 조합 통계
        # ==========================================

        combo_counts = {}

        for order in orders:

            colors = order.get(
                "colors",
                []
            )

            if (
                not isinstance(colors, list)
                or not colors
            ):
                continue


            # 예:
            # ["r", "r", "b", "g"]
            # ↓
            # "r-r-b-g"

            combo = "-".join(
                colors
            )


            combo_counts[combo] = (
                combo_counts.get(
                    combo,
                    0
                ) + 1
            )


        # ==========================================
        # 가장 많이 선택된 조합
        # ==========================================

        top_keycap_combo = None

        if combo_counts:

            combo, count = max(
                combo_counts.items(),
                key=lambda x: x[1]
            )

            top_keycap_combo = {
                "colors": combo.split("-"),
                "count": count
            }


        # ==========================================
        # 반환
        # ==========================================

        return jsonify({
            "success": True,
            "completed_orders": completed_orders,
            "mbti_stats": mbti_stats,
            "keycap_color_stats": keycap_color_stats,
            "top_keycap_combo": top_keycap_combo
        }), 200


    except Exception as e:

        print(
            "[dashboard/statistics ERROR]",
            e
        )

        return jsonify({
            "success": False,
            "error": "통계 정보를 조회하지 못했습니다."
        }), 400
        
        
# =========================================================
# 4. 조립대 현황
# GET /dashboard/station
# =========================================================

@bp.route("/station", methods=["GET"])
def get_dashboard_station():
    """
    조립대 현황 조회
    ---
    tags:
      - Dashboard

    summary: 조립대별 현재 주문 및 진행 상태 조회

    description: |
      조립대 1, 2, 3의 현재 주문 정보를 조회합니다.

      각 조립대의 `station:current_order:{station_id}`에서
      현재 배정된 `order_id`를 조회한 뒤,
      `order:{order_id}`에서 `order_seq`와 `stage`를 조회합니다.

      현재 배정된 주문이 없는 조립대는
      `order_seq`와 `stage`가 null로 반환됩니다.

    responses:
      200:
        description: 조립대 현황 조회 성공
        schema:
          type: object
          properties:
            success:
              type: boolean
              example: true

            stations:
              type: object
              properties:
                "1":
                  type: object
                  properties:
                    order_seq:
                      type: integer
                      nullable: true
                      example: 4
                    stage:
                      type: string
                      nullable: true
                      example: queued

                "2":
                  type: object
                  properties:
                    order_seq:
                      type: integer
                      nullable: true
                      example: 5
                    stage:
                      type: string
                      nullable: true
                      example: assembling

                "3":
                  type: object
                  properties:
                    order_seq:
                      type: integer
                      nullable: true
                      example: null
                    stage:
                      type: string
                      nullable: true
                      example: null

        examples:
          application/json:
            success: true
            stations:
              "1":
                order_seq: 4
                stage: queued
              "2":
                order_seq: 5
                stage: assembling
              "3":
                order_seq: null
                stage: null

      400:
        description: 조립대 현황 조회 실패
        schema:
          type: object
          properties:
            success:
              type: boolean
              example: false
            error:
              type: string
              example: 조립대 정보를 조회하지 못했습니다.

    """
    try:
        stations = {}

        for station_id in ["1", "2", "3"]:

            # 1. 해당 조립대의 현재 order_id 조회
            order_id = r.get(
                f"station:current_order:{station_id}"
            )

            # 현재 주문이 없는 경우
            if not order_id:
                stations[station_id] = {
                    "order_seq": None,
                    "stage": None
                }
                continue

            # 2. order:{order_id}에서 order_seq, stage 조회
            order_data = r.hmget(
                f"order:{order_id}",
                "order_seq",
                "stage"
            )

            order_seq, stage = order_data

            stations[station_id] = {
                "order_seq": int(order_seq) if order_seq else None,
                "stage": stage
            }

        return jsonify({
            "success": True,
            "stations": stations
        }), 200

    except Exception as e:
        print("[dashboard/station ERROR]", e)

        return jsonify({
            "success": False,
            "error": "조립대 정보를 조회하지 못했습니다."
        }), 400