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


# =========================================================
# 1. 재고 현황
# GET /dashboard/stocks
# =========================================================

@bp.route("/stocks", methods=["GET"])
def get_dashboard_stocks():
    try:
        raw_stock = r.hgetall("warehouse:stock")

        print("===== REDIS DEBUG =====")
        print("connection:", r.connection_pool.connection_kwargs)
        print("exists:", r.exists("warehouse:stock"))
        print("type:", r.type("warehouse:stock"))
        print("hlen:", r.hlen("warehouse:stock"))
        print("raw_stock:", raw_stock)
        print("=======================")

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

        # -----------------------------------------
        # 1. 총 주문 건수
        # 전시회 전체 기간의 order:counter 합산
        # -----------------------------------------

        total_orders = 0

        for date in get_exhibition_dates():
            count = r.get(f"order:counter:{date}")
            total_orders += int(count or 0)


        # -----------------------------------------
        # 2. 오늘 주문 건수
        # order:counter:{YYYYMMDD}
        # -----------------------------------------

        today_orders = int(
            r.get(f"order:counter:{today}") or 0
        )


        # -----------------------------------------
        # 3. 현재 대기 주문 건수
        # order:queue List 길이
        # -----------------------------------------

        waiting_orders = r.llen("order:queue")


        # -----------------------------------------
        # 4. 오늘 완료 건수
        # stats:completed:{YYYYMMDD}
        # -----------------------------------------

        completed_today = int(
            r.get(f"stats:completed:{today}") or 0
        )


        return jsonify({
            "total_orders": total_orders,
            "today_orders": today_orders,
            "waiting_orders": waiting_orders,
            "completed_today": completed_today
        }), 200


    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 400


# =========================================================
# 3. 색상별 주문 수
# GET /dashboard/statistics/colors
# =========================================================


# =========================================================
# 4. MBTI 순위
# GET /dashboard/statistics/mbti
# =========================================================


# =========================================================
# 5. 최다 키캡 조합
# GET /dashboard/statistics/top-combination
# =========================================================
