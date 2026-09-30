"""
GET /dashboard/station
=========================================================
조립대(1, 2, 3)의 실시간 현황 조회

Redis 읽기 흐름
    station:current_order:{station_id}   (STRING)  -> order_id
    order:{order_id}                     (HASH)    -> order_seq, stage

응답
    {
      "success": true,
      "stations": [
        {"station_id": 1, "order_id": "ord_xxx", "order_seq": 4, "stage": "queued"},
        {"station_id": 2, "order_id": null,      "order_seq": null, "stage": "idle"},
        {"station_id": 3, "order_id": "ord_yyy", "order_seq": 7, "stage": "assembling"}
      ]
    }

- 조립대에 걸린 주문이 없으면(키 없음) stage = "idle", order_id/order_seq = null
- station 3칸은 항상 응답에 포함됨 (대시보드가 빈 칸을 그대로 그릴 수 있도록)
- Redis 왕복은 총 2회 (MGET 1회 + 파이프라인 1회) — Upstash 명령 수 절약
"""

import logging

from flask import Blueprint, jsonify

logger = logging.getLogger(__name__)

# 조립대 번호
STATION_IDS = (1, 2, 3)

# 주문이 걸려있지 않을 때의 기본 stage
IDLE_STAGE = "idle"

dashboard_station_bp = Blueprint("dashboard_station", __name__)


# =========================================================
# 내부 헬퍼
# =========================================================

def _text(value):
    """redis 클라이언트가 decode_responses=False 여도 안전하게 문자열로."""
    if isinstance(value, bytes):
        value = value.decode("utf-8", "replace")
    if value is None:
        return None
    value = str(value).strip()
    return value or None


def _int(value):
    """order_seq 는 Redis 에 문자열("4")로 들어있으므로 정수로 변환. 실패하면 None."""
    text = _text(value)
    if text is None:
        return None
    try:
        return int(text)
    except ValueError:
        logger.warning("[dashboard/station] order_seq 정수 변환 실패: %r", text)
        return None


def _empty_station(station_id):
    return {
        "station_id": station_id,
        "order_id": None,
        "order_seq": None,
        "stage": IDLE_STAGE,
    }


# =========================================================
# 조회 로직 (라우트와 분리 — 테스트/재사용 용)
# =========================================================

def get_station_status(redis_client):
    """조립대 1~3의 현재 주문 순번과 공정 상태를 조회한다."""

    # 1) 조립대별 현재 order_id — MGET 1회
    current_order_keys = [f"station:current_order:{sid}" for sid in STATION_IDS]
    order_ids = [_text(v) for v in redis_client.mget(current_order_keys)]

    # 2) order:{order_id} 에서 order_seq / stage 만 — 파이프라인 1회
    pipe = redis_client.pipeline()
    pending_station_ids = []

    for station_id, order_id in zip(STATION_IDS, order_ids):
        if order_id:
            pipe.hmget(f"order:{order_id}", "order_seq", "stage")
            pending_station_ids.append(station_id)

    fetched = pipe.execute() if pending_station_ids else []

    # 3) station_id -> 주문 정보
    order_fields = dict(zip(pending_station_ids, fetched))
    order_id_by_station = dict(zip(STATION_IDS, order_ids))

    stations = []

    for station_id in STATION_IDS:
        order_id = order_id_by_station.get(station_id)

        # 조립대가 비어 있음
        if not order_id:
            stations.append(_empty_station(station_id))
            continue

        raw = order_fields.get(station_id) or [None, None]
        order_seq = _int(raw[0])
        stage = _text(raw[1])

        # 포인터는 있는데 order 해시가 없는 경우 (주문 만료/삭제 등)
        if order_seq is None and stage is None:
            logger.warning(
                "[dashboard/station] station %s -> order:%s 해시를 찾을 수 없음",
                station_id,
                order_id,
            )
            stations.append(_empty_station(station_id))
            continue

        stations.append(
            {
                "station_id": station_id,
                "order_id": order_id,
                "order_seq": order_seq,
                "stage": stage or IDLE_STAGE,
            }
        )

    return stations


# =========================================================
# 라우트
# =========================================================

@dashboard_station_bp.route("/dashboard/station", methods=["GET"])
def dashboard_station():
    # 프로젝트 구조에 맞게 redis 클라이언트를 가져오세요.
    #   예) from app import redis_client
    #   예) redis_client = current_app.config["REDIS"]
    from app import redis_client  # noqa: PLC0415  <- 본인 프로젝트 경로로 수정

    try:
        stations = get_station_status(redis_client)

    except Exception as exc:  # redis 연결 실패 등
        logger.exception("[dashboard/station] 조회 실패")
        return (
            jsonify({"success": False, "error": f"조립대 현황 조회 실패: {exc}"}),
            500,
        )

    return jsonify({"success": True, "stations": stations})


# =========================================================
# app.py 등록 예시
# =========================================================
#
#   from dashboard_station import dashboard_station_bp
#   app.register_blueprint(dashboard_station_bp)
#
# Blueprint 를 쓰지 않는다면 app.py 에 아래처럼 직접 붙여도 동일합니다.
#
#   @app.route("/dashboard/station", methods=["GET"])
#   def dashboard_station():
#       from dashboard_station import get_station_status
#       return jsonify({"success": True, "stations": get_station_status(redis_client)})
#
# 확인:
#   curl http://127.0.0.1:5000/dashboard/station
