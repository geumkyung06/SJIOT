from datetime import datetime

from infra.extensions import r

from config import (QUEUE_KEY,
                    WAREHOUSE_KEY,
                    STATION_KEY,
                    AGV_KEY,
                    FAULT_KEY,
                    WAREHOUSE_ORDER_KEY,
                    STATION_ORDER_PREFIX,
                    MAX_QUEUE_LEN,
                    STATION_VERIFIED_PREFIX,
                    STATION_TIMEOUT_SEC,
                    ORDER_COUNTER_KEY,
                    ORDER_PAGE_BASE,
                    STATION_RESET_PASSWORD,
                    MBTI_AXES,
                    TEST_KEY_TTL,
                    COLOR_LIST,
                    BOARD_LIST,
                    STAGE_TO_STATION_STATUS,
                    KST,
                    STAGE_ORDER
                   )

def _order_counter_key():
    today = datetime.now(KST).strftime("%Y%m%d")
    return f"{ORDER_COUNTER_KEY}:{today}"

def _touch(*keys):
    """테스트 모드일 때 해당 키들의 TTL을 TEST_KEY_TTL로 (재)설정"""
    if not TEST_KEY_TTL:
        return
    for key in keys:
        r.expire(key, TEST_KEY_TTL)

def _ensure_initial_state():
    """warehouse/station 상태키가 없으면 초기값으로 세팅"""
    if not r.exists(WAREHOUSE_KEY):
        r.set(WAREHOUSE_KEY, "idle") # 키캡별로, 로봇팔 설정 필요
    if not r.exists(STATION_KEY):
        r.hset(STATION_KEY, mapping={"1": "idle", "2": "idle", "3": "idle"})
    if not r.exists(AGV_KEY):
        r.set(AGV_KEY, "idle")
    _touch(WAREHOUSE_KEY, STATION_KEY, AGV_KEY)

def _get_free_station():
    station_status = r.hgetall(STATION_KEY)
    return next((sid for sid in ("1", "2", "3") if station_status.get(sid, "idle") == "idle"), None)

