import json

from infra.extensions import r
from infra.logger import logger

def get_stocks_from_redis():
    raw = r.get("warehouse:stock")
    if raw is None:
        return None
    stocks = json.loads(raw)

    return stocks

def get_out_of_stock():
    stocks = get_stocks_from_redis()
    out = {}
    for color, qty in stocks.get("board", {}).items():
        if int(qty or 0) <= 0:
            out.setdefault("board", []).append(color)

    for letter, colors in stocks.get("keycap", {}).items():
        for color, qty in colors.items():
            if int(qty or 0) <= 0:
                out.setdefault("keycap", []).append(f"{letter}_{color}")

    return out