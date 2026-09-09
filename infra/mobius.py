import os
import json
import requests
from datetime import datetime
from infra.logger import logger

from infra.extensions import r

from config import (STATION_ORDER_PREFIX,
                    KST,
                    MP_URL, 
                    CB,
                    AE_RN,
                    ORIGIN,
                    API_KEY,
                    LECTURE_ID,
                    CREATOR_ID,
                    STAGE_ORDER
                   )

def _headers(ty=None):
    h = {
        "X-API-KEY": API_KEY,
        "X-AUTH-CUSTOM-LECTURE": LECTURE_ID,
        "X-AUTH-CUSTOM-CREATOR": CREATOR_ID,
        "Accept": "application/json",
        "X-M2M-RI": os.urandom(4).hex(),
        "X-M2M-Origin": ORIGIN,
    }
    if ty:
        h["Content-Type"] = f"application/json;ty={ty}"
    return h

def create_cin(cnt_rn, con_dict):
    url = f"{MP_URL}/{CB}/{AE_RN}/{cnt_rn}"
    body = {"m2m:cin": {"con": json.dumps(con_dict, ensure_ascii=False)}}
    try:
        res = requests.post(url, headers=_headers(ty=4), json=body, timeout=(3, 5))
    except requests.RequestException as e:
        logger.error(f"[create_cin] {cnt_rn} 요청 실패: {e}")
        return False        # ← 예외를 여기서 흡수해야 _dispatch_order 롤백이 돌아감

    ok = res.status_code in (200, 201)
    if not ok:
        logger.error(f"[create_cin] {cnt_rn} {res.status_code} {res.text[:200]}")
    return ok

def get_latest_con(cnt_rn):
    """cnt의 최신 CIN con을 dict로 반환. 실패하면 None."""
    url = f"{MP_URL}/{CB}/{AE_RN}/{cnt_rn}/la"

    try:
        res = requests.get(url, headers=_headers(), timeout=(3, 5))
    except requests.RequestException as e:
        logger.error(f"[get_latest_con] {cnt_rn} 요청 실패: {e}")
        return None

    if res.status_code != 200:
        logger.error(f"[get_latest_con] {cnt_rn} {res.status_code} {res.text[:200]}")
        return None

    try:
        con = res.json()["m2m:cin"]["con"]
    except (ValueError, KeyError, TypeError) as e:
        logger.error(f"[get_latest_con] {cnt_rn} 응답 구조 이상: {e} body={res.text[:200]}")
        return None

    if isinstance(con, str):
        try:
            return json.loads(con)
        except json.JSONDecodeError:
            logger.error(f"[get_latest_con] {cnt_rn} con 파싱 실패: {con[:200]}")
            return None
    return con

# order
def send_order_cin(order_id, board, keycap, colors, station_id, order_seq):
    con = {
        "order_id": order_id,
        "station_id": station_id,
        "board": board,
        "colors": colors,
        "keycap": keycap,
        "order_seq": order_seq,
    }
    return create_cin("cnt_order", con)

def _dispatch_order(order_id):
    """배정된 주문을 창고에 불출 지시(cnt_order append). 성공 여부만 반환."""
    od = r.hgetall(f"order:{order_id}")
    required = ("board", "keycap", "colors", "station_id", "order_seq")
    if not od or any(k not in od for k in required):
        logger.error(f"[dispatch] order 데이터 불완전 (order_id={order_id}) od={od}")
        return False

    return send_order_cin(
        order_id,
        od["board"],
        od["keycap"],
        od["colors"].split(","),
        str(od["station_id"]),
        int(od["order_seq"]),
    )

# stock 캐시는 services/stock.py 로 이관 (warehouse:stock 은 hash)

# cnt_station
# 현재 배정되어있는 stations들만 업데이트
def send_station_cin(stations):
    # 나중에 tables 도 변경 필요
    con = {"stations": stations}
    return create_cin("cnt_station", con)

def _build_station_snapshot():
    stations = {}
    now = datetime.now(KST).isoformat()

    for sid in ("1", "2", "3"):
        order_id = r.get(f"{STATION_ORDER_PREFIX}{sid}")
        od = r.hgetall(f"order:{order_id}") if order_id else None

        if not od:
            # cin 폴링해야할 듯(cnt_process)
            # order_id 기준으로 찾아서 업뎃
            stations[sid] = {"order_id": None,
                             "order_seq": None, "updated_at": now}
            continue

        status = od.get("stage")
        if status is None:
            logger.warning(f"[station] 매핑 없는 stage={status} (station={sid})")
            # cin 폴링해야할 듯(cnt_process)
            status = "occupied"
        stations[sid] = {"order_id": order_id,
                         "order_seq": od.get("order_seq"), "updated_at": now}
    return stations

def _push_station_snapshot():
    """redis 기준 스냅샷을 cnt_table로 전송. 실패해도 로직은 계속."""
    ok = send_station_cin(_build_station_snapshot())
    if not ok:
        logger.warning("[table] cnt_table 스냅샷 전송 실패")
    return ok

# 명령은 cnt_process 하나로만 나간다 (services/process.push_process)

# supscription
def _extract_notification_con(data):
    """Mobius 알림 봉투에서 con을 dict로 꺼낸다. 못 꺼내면 None."""
    if not isinstance(data, dict):
        return None

    sgn = data.get("m2m:sgn")
    if sgn is None:
        return data or None

    con = (((sgn.get("nev") or {}).get("rep") or {})
           .get("m2m:cin") or {}).get("con")

    # dict가 될 때까지 푼다 (이중 인코딩 대비 최대 2회)
    for _ in range(2):
        if not isinstance(con, str):
            break
        try:
            con = json.loads(con)
        except json.JSONDecodeError:
            logger.warning(f"[callback] con 파싱 실패: {con[:200]}")
            return None

    if not isinstance(con, dict):
        logger.warning(f"[callback] con이 dict가 아님: {type(con).__name__} {str(con)[:200]}")
        return None

    # 있을 때만 정규화
    if "count" in con:
        try:
            con["count"] = int(con["count"])
        except (TypeError, ValueError):
            logger.warning(f"[callback] count 이상: {con['count']!r}")
            con["count"] = 0

    return con
