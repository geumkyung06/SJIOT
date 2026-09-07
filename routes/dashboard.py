from flask import Blueprint, jsonify
from services.extensions import r

bp = Blueprint("dashboard", __name__)


@bp.route("/dashboard/status", methods=["GET"])
def get_dashboard_status():
    return jsonify({
        "ok": True,
        "message": "대시보드 API 연결 성공"
    }), 200