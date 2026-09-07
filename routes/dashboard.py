import json

from flask import Blueprint, jsonify
from services.extensions import r


bp = Blueprint(
    "dashboard",
    __name__,
    url_prefix="/dashboard",
)


@bp.route("/stocks", methods=["GET"])
def get_dashboard_stocks():
    """Redis에 저장된 최신 창고 재고 조회."""

    raw_stock = r.get("warehouse:stock")

    if raw_stock is None:
        return jsonify({
            "error": "저장된 재고 정보가 없습니다."
        }), 404

    try:
        # Redis가 bytes로 반환하는 경우
        if isinstance(raw_stock, bytes):
            raw_stock = raw_stock.decode("utf-8")

        stock_data = json.loads(raw_stock)

    except (UnicodeDecodeError, json.JSONDecodeError):
        return jsonify({
            "error": "Redis 재고 데이터 형식이 올바르지 않습니다."
        }), 500

    return jsonify({
        "success": True,
        "stock": stock_data,
    }), 200