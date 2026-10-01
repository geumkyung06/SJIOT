"""대시보드 AGV 이동경로.

구간은 agv:status(AGV 원보고) 기준으로 '장소 도착'에서 끊는다.
    arrived   → station:{id}  (오배송이어도 AGV가 실제로 선 조립대)
    parked    → parking       (대기장소 = 픽업대)
    discarded → discard
주문 stage 기준이 아니다 — 오배송·fault 로 전이를 버린 arrived 도 AGV는 그 자리에 서 있다.

도착 즉시 궤적을 지우지 않는다. 아직 마지막 점을 못 받은 대시보드가 있을 수 있어서
'체크포인트 다음 첫 이동'에서 새 구간을 열고, 도착점 하나만 출발점으로 남긴다.
그래서 agv:trail 에는 항상 '현재 구간(+ 출발점)'만 들어 있다.

점 형식 (agv:coord 와 agv:trail 원소 공통, JSON):
    {"seq": 12, "leg": 3, "coord": [1, 3], "ts": 1759280000000, "checkpoint": "station:1" | null}
"""
import json
import time

from config import AGV_COORD_KEY, AGV_TRAIL_KEY, AGV_SEQ_KEY, AGV_LEG_KEY
from infra.extensions import r

TRAIL_MAX = 100   # 한 구간이 이보다 길면 앞부분이 잘린다. TTL 대신 길이로 묶는다.

_PLACES = {"parked": "parking", "discarded": "discard"}


def _place(status, station_id):
    if status == "arrived":
        return f"station:{station_id}" if station_id else "station"
    return _PLACES.get(status)


def _load(raw):
    try:
        p = json.loads(raw) if raw else None
    except (json.JSONDecodeError, TypeError):
        return None
    return p if isinstance(p, dict) and "coord" in p else None


def current():
    """마지막 점. 없으면 None — 위치를 모른다(초기화 직후·첫 기동) → 대시보드는 마커를 숨긴다."""
    return _load(r.get(AGV_COORD_KEY))


def trail():
    return [p for p in (_load(x) for x in r.lrange(AGV_TRAIL_KEY, 0, -1)) if p]


def record(coord, status, station_id=None):
    """cnt_agv 보고 1건을 궤적에 반영한다. callbacks/agv.py 가 status 처리보다 먼저 부른다."""
    prev = current()
    place = _place(status, str(station_id or ""))

    if not coord:
        # 좌표 없는 도착 보고 → 직전 좌표에서 도착 처리.
        # 직전 좌표가 없으면(초기화 직후) 위치를 모르므로 아무것도 찍지 않는다.
        if not (place and prev):
            return
        coord = prev["coord"]

    # 같은 칸 재보고 / 같은 장소 재전송은 궤적에 쌓지 않는다.
    # (대기장소에서 parked 뒤 같은 좌표로 loaded 가 와도 빈 구간이 생기지 않게)
    if prev and prev["coord"] == coord and (place is None or place == prev.get("checkpoint")):
        return

    new_leg = bool(prev and prev.get("checkpoint"))
    leg = r.incr(AGV_LEG_KEY) if new_leg else int(r.get(AGV_LEG_KEY) or 0)

    point = json.dumps({
        "seq": r.incr(AGV_SEQ_KEY),
        "leg": leg,
        "coord": coord,
        "ts": int(time.time() * 1000),
        "checkpoint": place,
    })
    pipe = r.pipeline()
    if new_leg:
        pipe.ltrim(AGV_TRAIL_KEY, -1, -1)   # 직전 도착점만 새 구간의 출발점으로 남긴다
    pipe.set(AGV_COORD_KEY, point)
    pipe.rpush(AGV_TRAIL_KEY, point)
    pipe.ltrim(AGV_TRAIL_KEY, -TRAIL_MAX, -1)
    pipe.execute()


def reset():
    """AGV 완전 초기화(API 예정)에서 호출한다.

    위치를 모르는 상태로 돌린다. agv:coord 를 지워 대시보드가 마커를 숨기게 하고,
    구간 번호를 올려 다음 보고가 고장 난 자리부터 이어 그려지지 않게 한다.
    agv:coord:seq 는 지우지 않는다 — 대시보드의 since 가 꼬이지 않게 계속 오르게 둔다.
    """
    pipe = r.pipeline()
    pipe.delete(AGV_TRAIL_KEY, AGV_COORD_KEY)
    pipe.incr(AGV_LEG_KEY)
    pipe.execute()
