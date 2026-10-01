"""영업 상태 — 새 주문 접수를 받을지 말지.

    open     POST /order 를 받는다
    closed   **접수만** 막는다. 이미 받은 주문(대기열·진행 중)은 끝까지 돈다.

막는 건 POST /order 하나뿐이다. 콜백(/mobius/callback/*)·조립대(/station/*)·관리자(/admin/*)까지
막으면 마감 순간 진행 중 주문이 멈춘다 — AGV·창고 보고가 버려지고 워치독이 stage_timeout 을
줄줄이 건다. 대기열에 이미 들어간 주문은 배정 트리거(services/dispatch.py 주석)가 그대로 돌아서
자연히 빠진다(drain). 남은 주문 수와 '장비를 꺼도 되는지'는 summary() 가 알려준다.

키가 없으면 closed 로 본다. 리셋 직후나 Redis 를 잃은 뒤, 아무도 확인하지 않은 상태로 주문이
들어오지 않게 하려는 것이다. 같은 이유로 POST /admin/reset 은 모드와 상관없이 closed 로 둔다
(services/recovery.py). **그래서 오픈 때 POST /admin/line {"status": "open"} 을 반드시 눌러야 한다.**
"""
from datetime import datetime
from functools import wraps

from flask import jsonify

from config import (AGV_KEY,
                    KST,
                    LINE_CHANGED_AT_KEY,
                    LINE_STATUS_KEY,
                    QUEUE_KEY,
                    STATION_ORDER_PREFIX,
                    WAREHOUSE_ORDER_KEY,
                   )
from infra.extensions import r
from infra.logger import logger

OPEN = "open"
CLOSED = "closed"
STATUSES = (OPEN, CLOSED)
STATIONS = ("1", "2", "3")


def status():
    """open 이라고 적혀 있을 때만 open. 키 없음·이상한 값은 전부 closed."""
    return OPEN if r.get(LINE_STATUS_KEY) == OPEN else CLOSED


def is_open():
    return status() == OPEN


def set_status(value):
    """전환하고 직전 값을 돌려준다. 같은 값으로 다시 눌러도 changed_at 은 그대로 둔다."""
    if value not in STATUSES:
        raise ValueError(f"status 는 {STATUSES} 중 하나여야 합니다: {value!r}")
    prev = status()
    r.set(LINE_STATUS_KEY, value)
    if value != prev or not r.exists(LINE_CHANGED_AT_KEY):
        r.set(LINE_CHANGED_AT_KEY, datetime.now(KST).isoformat(timespec="seconds"))
    logger.warning(f"[line] {prev} -> {value}")
    return prev


def summary():
    """관리자 페이지용. 마감 뒤 '언제 장비를 꺼도 되나'를 여기서 본다.

    remaining  대기열 + 조립대 + 창고가 잡고 있는 주문 (중복 제거).
               노쇼(unclaimed)는 AGV 가 폐기를 마칠 때까지 조립대를 잡으므로 여기 남는다.
    drained    남은 주문이 없고 AGV 가 대기장소로 돌아왔다(idle) — 장비를 꺼도 된다.
    """
    queue = r.lrange(QUEUE_KEY, 0, -1)
    held = [oid for oid in (r.get(f"{STATION_ORDER_PREFIX}{s}") for s in STATIONS) if oid]
    wh = r.get(WAREHOUSE_ORDER_KEY)
    if wh:
        held.append(wh)
    in_progress = list(dict.fromkeys(held))
    remaining = list(dict.fromkeys([*queue, *in_progress]))
    agv = r.get(AGV_KEY) or "idle"
    return {
        "status": status(),
        "changed_at": r.get(LINE_CHANGED_AT_KEY),
        "queue": len(queue),
        "in_progress": len(in_progress),
        "remaining": len(remaining),
        "agv": agv,
        "drained": not remaining and agv == "idle",
    }


def require_open(view):
    """POST /order 전용. closed 면 503 — 키오스크는 이 응답으로 마감 화면을 띄운다.

    Idempotency-Key 를 잡기 전에 걸러야 한다. 그래서 라우트 함수 안이 아니라 데코레이터다.
    """
    @wraps(view)
    def wrapper(*args, **kwargs):
        if not is_open():
            return jsonify({"error": "오늘 주문 접수가 마감되었습니다", "line": CLOSED}), 503
        return view(*args, **kwargs)
    return wrapper
