import os
import json
import requests
from services.extensions import r
import logging
logger = logging.getLogger(__name__)

MP_URL = os.getenv("MP_URL")  
CB = os.getenv("CB", "Mobius")
AE_RN = os.getenv("AE_RN")   
ORIGIN = os.getenv("MOBIUS_ORIGIN")
API_KEY = os.getenv("MOBIUS_API_KEY")
LECTURE_ID = os.getenv("X-AUTH-CUSTOM-LECTURE")
CREATOR_ID = os.getenv("X-AUTH-CUSTOM-CREATOR")

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

# stock
def handle_stock_notification(con):
    """Mobius subscription 콜백에서 호출. cnt_stock의 최신 con으로 Redis 캐시 갱신."""
    r.set("warehouse:stock", json.dumps(con))

def get_out_of_stock():
    """캐시된 cnt_stock con에서 재고 0인 항목만 추림."""
    raw = r.get("warehouse:stock")
    if raw is None:
        return None
    stock = json.loads(raw)

    out = {}
    for color, qty in stock.get("board", {}).items():
        if int(qty or 0) <= 0:
            out.setdefault("board", []).append(color)

    for letter, colors in stock.get("keycap", {}).items():
        for color, qty in colors.items():
            if int(qty or 0) <= 0:
                out.setdefault("keycap", []).append(f"{letter}_{color}")

    return out

# table
def send_table_cin(tables):
    con = {"tables": tables}
    return create_cin("cnt_table", con)

# command
def send_agv_command_cin(order_id, station_id, status):
    con = {
        "order_id": order_id,
        "station_id": station_id,
        "status": status
    }
    return create_cin("cnt_agv_command", con)