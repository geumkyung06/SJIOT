import json
import os
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from flask import Blueprint, jsonify
from services.extensions import r

bp = Blueprint("dashboard", __name__, url_prefix="/dashboard")

KST = ZoneInfo("Asia/Seoul")

EXHIBITION_START_DATE = os.getenv("EXHIBITION_START_DATE", "20260920")
EXHIBITION_DAYS = int(os.getenv("EXHIBITION_DAYS", "3"))

def today_key():
    """Redis archive/stats 날짜 형식: YYYYMMDD"""
    return datetime.now(KST).strftime("%Y%m%d")
  
def get_exhibition_dates():
    """전시회 전체 날짜 리스트 반환"""

    start_date = datetime.strptime(
        EXHIBITION_START_DATE,
        "%Y%m%d"
    )

    dates = []

    for i in range(EXHIBITION_DAYS):
        date = start_date + timedelta(days=i)
        dates.append(date.strftime("%Y%m%d"))

    return dates
  
def update_completed_order_stats(process):

    orders = process.get("orders", {})

    for order_id, order in orders.items():

        # completed가 아닌 주문은 무시
        if order.get("status") != "completed":
            continue

        # 이미 집계한 주문인지 확인
        is_new = r.sadd(
            "dashboard:stats:processed_completed",
            order_id
        )

        # 이미 처리한 주문이면 중복 집계 방지
        if not is_new:
            continue

        # ==========================================
        # 완료 주문 건수
        # ==========================================
        r.incr(
            "dashboard:stats:completed_count"
        )

        # ==========================================
        # MBTI
        # ==========================================
        mbti = order.get("keycap")

        if mbti:
            r.hincrby(
                "dashboard:stats:mbti",
                mbti,
                1
            )

        # ==========================================
        # 키캡 색상
        # ==========================================
        colors = order.get("colors", [])

        for color in colors:
            r.hincrby(
                "dashboard:stats:keycap_color",
                color,
                1
            )

        # ==========================================
        # 키캡 조합
        # ==========================================
        if colors:
            combo = "-".join(colors)

            r.hincrby(
                "dashboard:stats:keycap_combo",
                combo,
                1
            )


# =========================================================
# 1. 재고 현황
# GET /dashboard/stocks
# =========================================================

@bp.route("/stocks", methods=["GET"])
def get_dashboard_stocks():
    try:
        raw_stock = r.hgetall("warehouse:stock")

        stocks = {}

        for cartridge_id, value in raw_stock.items():
            stock_data = json.loads(value)

            stocks[cartridge_id] = {
                "count": stock_data["count"],
                "status": stock_data["status"]
            }

        return jsonify({
            "success": True,
            "stocks": stocks
        }), 200

    except Exception as e:
        print("[dashboard/stocks ERROR]", e)

        return jsonify({
            "success": False,
            "error": "재고 정보를 조회하지 못했습니다."
        }), 400


# # =========================================================
# # 2. 주문 건수 KPI
# # GET /dashboard/orders
# # =========================================================

@bp.route("/orders/stats", methods=["GET"])
def get_order_summary():
    """
    주문 현황 조회
    ---
    tags:
      - Dashboard

    responses:
      200:
        description: 주문 현황 조회 성공
        schema:
          type: object
          properties:
            total_orders:
              type: integer
              example: 30
            today_orders:
              type: integer
              example: 10
            waiting_orders:
              type: integer
              example: 3
            completed_today:
              type: integer
              example: 7

      400:
        description: 주문 현황 조회 실패
    """
    try:
        today = today_key()

        # 1. 전시회 전체 주문 건수
        total_orders = 0

        for date in get_exhibition_dates():
            count = r.get(f"order:counter:{date}")
            total_orders += int(count or 0)

        # 2. 오늘 주문 건수
        today_orders = int(
            r.get(f"order:counter:{today}") or 0
        )

        # 3. 현재 대기 주문 건수
        waiting_orders = r.llen("order:queue")

        # 4. 오늘 완료 주문 건수
        completed_today = int(
            r.get(f"dashboard:stats:completed:{today}") or 0
        )

        return jsonify({
            "success": True,
            "total_orders": total_orders,
            "today_orders": today_orders,
            "waiting_orders": waiting_orders,
            "completed_today": completed_today
        }), 200

    except Exception as e:
        print("[dashboard/orders/stats ERROR]", e)

        return jsonify({
            "success": False,
            "error": str(e)
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

    summary: 대시보드 주문 통계 조회

    description: |
      완료된 주문을 기준으로 집계된 대시보드 통계 정보를 반환합니다.

      Redis에 저장된 아래 통계 데이터를 조회합니다.

      - `dashboard:stats:mbti`
        - MBTI별 완료 주문 수
      - `dashboard:stats:keycap_color`
        - 키캡 색상별 사용 개수
      - `dashboard:stats:keycap_combo`
        - 키캡 색상 조합별 완료 주문 수

      반환되는 통계 정보는 다음과 같습니다.

      - 전체 완료 주문 건수
      - MBTI별 완료 주문 수
      - MBTI별 비율
      - MBTI 순위
      - 키캡 색상별 사용 개수
      - 키캡 색상별 사용 비율
      - 가장 많이 선택된 키캡 색상 조합

    responses:
      200:
        description: 대시보드 통계 조회 성공
        schema:
          type: object
          properties:

            success:
              type: boolean
              description: 요청 성공 여부
              example: true

            completed_orders:
              type: integer
              description: 전체 완료 주문 건수
              example: 10

            mbti_stats:
              type: array
              description: MBTI별 완료 주문 통계
              items:
                type: object
                properties:

                  rank:
                    type: integer
                    description: 완료 주문 수 기준 MBTI 순위
                    example: 1

                  mbti:
                    type: string
                    description: MBTI 유형
                    example: ENTP

                  count:
                    type: integer
                    description: 해당 MBTI의 완료 주문 수
                    example: 5

                  ratio:
                    type: number
                    format: float
                    description: 전체 완료 주문 중 해당 MBTI가 차지하는 비율(%)
                    example: 50.0

            keycap_color_stats:
              type: object
              description: 키캡 색상별 사용 통계
              additionalProperties:
                type: object
                properties:

                  count:
                    type: integer
                    description: 해당 색상의 키캡 사용 개수
                    example: 15

                  ratio:
                    type: number
                    format: float
                    description: 전체 사용 키캡 중 해당 색상이 차지하는 비율(%)
                    example: 37.5

              example:
                r:
                  count: 15
                  ratio: 37.5
                g:
                  count: 8
                  ratio: 20.0
                b:
                  count: 10
                  ratio: 25.0
                y:
                  count: 7
                  ratio: 17.5

            top_keycap_combo:
              type: object
              nullable: true
              description: 가장 많이 선택된 키캡 색상 조합
              properties:

                colors:
                  type: array
                  description: 키캡 색상 조합
                  items:
                    type: string
                  example:
                    - r
                    - r
                    - b
                    - g

                count:
                  type: integer
                  description: 해당 색상 조합이 선택된 완료 주문 수
                  example: 4

        examples:
          application/json:
            success: true
            completed_orders: 10
            mbti_stats:
              - rank: 1
                mbti: ENTP
                count: 5
                ratio: 50.0
              - rank: 2
                mbti: ENFP
                count: 3
                ratio: 30.0
              - rank: 3
                mbti: ISTJ
                count: 2
                ratio: 20.0

            keycap_color_stats:
              r:
                count: 15
                ratio: 37.5
              g:
                count: 8
                ratio: 20.0
              b:
                count: 10
                ratio: 25.0
              y:
                count: 7
                ratio: 17.5

            top_keycap_combo:
              colors:
                - r
                - r
                - r
                - r
              count: 4

      400:
        description: 대시보드 통계 조회 실패
        schema:
          type: object
          properties:

            success:
              type: boolean
              description: 요청 성공 여부
              example: false

            error:
              type: string
              description: 오류 메시지
              example: 통계 정보를 조회하지 못했습니다.
    """

    try:
        # ==========================================
        # 1. MBTI 통계
        # dashboard:stats:mbti
        # ==========================================
        raw_mbti = r.hgetall(
            "dashboard:stats:mbti"
        )

        mbti_counts = {}

        for mbti, count in raw_mbti.items():
            mbti_counts[mbti] = int(count)


        # 완료 주문 총 건수
        completed_orders = sum(
            mbti_counts.values()
        )


        # MBTI 순위
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
                    count / completed_orders * 100,
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
        # dashboard:stats:keycap_color
        # ==========================================
        raw_colors = r.hgetall(
            "dashboard:stats:keycap_color"
        )

        color_counts = {}

        for color, count in raw_colors.items():
            color_counts[color] = int(count)


        total_keycaps = sum(
            color_counts.values()
        )

        keycap_color_stats = {}

        for color, count in color_counts.items():

            ratio = (
                round(
                    count / total_keycaps * 100,
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
        # 3. 키캡 조합 통계
        # dashboard:stats:keycap_combo
        # ==========================================
        raw_combos = r.hgetall(
            "dashboard:stats:keycap_combo"
        )

        combo_counts = {}

        for combo, count in raw_combos.items():
            combo_counts[combo] = int(count)


        # 가장 많이 선택된 조합
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
        print("[dashboard/statistics ERROR]", e)

        return jsonify({
            "success": False,
            "error": "통계 정보를 조회하지 못했습니다."
        }), 400