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
    """지정한 cnt에 CIN 하나 추가. 성공 시 True, 실패 시 False."""
    url = f"{MP_URL}/{CB}/{AE_RN}/{cnt_rn}"
    body = {"m2m:cin": {"con": json.dumps(con_dict, ensure_ascii=False)}}
    res = requests.post(url, headers=_headers(ty=4), json=body)
    return res.status_code in (200, 201)

def get_latest_con(cnt_rn):
    url = f"{MP_URL}/{CB}/{AE_RN}/{cnt_rn}/la"
    res = requests.get(url, headers=_headers())
    logger.info(f"[get_latest_con] url={url} status={res.status_code} body={res.text[:500]}")
    if res.status_code != 200:
        return None
    con = res.json()["m2m:cin"]["con"]
    return json.loads(con) if isinstance(con, str) else con

# order
def send_order_cin(order_id, board, switch, keycap, colors):
    con = {
        "order_id": order_id,
        "board": board,
        "colors": colors,
        "keycap": keycap,
        "switch": switch,
    }
    return create_cin("cnt_order", con)


# stock
def handle_stock_notification(con):
    """Mobius subscription 콜백에서 호출. cnt_stock의 최신 con으로 Redis 캐시 갱신."""
    r.set("warehouse:stock", json.dumps(con))

def get_out_of_stock():
    """cnt_stock 최신 con을 Mobius에서 직접 가져와 재고 0인 항목만 추림."""
    stock = get_latest_con("cnt_stock")
    if stock is None:
        return None

    out = {}
    for board, qty in stock.get("board", {}).items():
        if qty <= 0:
            out.setdefault("board", []).append(board)

    for switch, qty in stock.get("switch", {}).items():
        if qty <= 0:
            out.setdefault("switch", []).append(switch)

    for letter, colors in stock.get("keycap", {}).items():
        for color, qty in colors.items():
            if qty <= 0:
                out.setdefault("keycap", []).append(f"{letter}_{color}")

    return out

# table
def _update_station(station_id, status, order_id=None):
    con = get_latest_con("cnt_table") or {"tables": {}}
    con["tables"][str(station_id)] = {"status": status, "order_id": order_id}
    return create_cin("cnt_table", con)

def mark_station_in_progress(station_id, order_id):
    return _update_station(station_id, "in_progress", order_id)

def mark_station_empty(station_id):
    return _update_station(station_id, "empty", None)

# queue
def send_table_cin(tables):
    """
    tables: {"1": {"status": "empty"|"in_progress"|"done", "order_id": str|None}, ...}
    조립대 3개 전체 상태를 cnt_table 통짜로 업데이트 (AGV가 구독).
    """
    con = {"tables": tables}
    return create_cin("cnt_table", con)