from datetime import datetime

from config import (QUEUE_KEY,
                    WAREHOUSE_KEY,
                    STATION_KEY,
                    WAREHOUSE_ORDER_KEY,
                    STATION_ORDER_PREFIX,
                    STATION_VERIFIED_PREFIX,
                    KST,
                    STATION_TIMEOUT_SEC
                   )

from infra.extensions import r
from infra.keys import _touch, _get_free_station
from infra.mobius import _push_station_snapshot, _dispatch_order
from infra.logger import logger

def _complete_station(station_id):
    station_id = str(station_id)
    order_key = f"{STATION_ORDER_PREFIX}{station_id}"
    order_id = r.get(order_key)

    if not order_id:
        return None  # 여기서 조기 반환, 아무 것도 건드리지 않음

    r.hset(STATION_KEY, station_id, "idle")
    r.delete(order_key)
    r.delete(f"{STATION_VERIFIED_PREFIX}{station_id}")
    _touch(STATION_KEY)

    r.hset(f"order:{order_id}", "stage", "completed")
    _touch(f"order:{order_id}")

    if _try_assign_next() is None:
        _push_station_snapshot()
    return order_id

def _try_assign_next():
    """
    idle 상태인 카트리지 확인, 가능한 주문 확인 후 빈 조립대가 있으면 큐에서 다음 주문을 꺼내 배정.
    """

    # 대부분 완료 후 전체 카트리지가 idle 상태이겠지만 재고나 장애 발생했을 경우 busy(empty, disable) 확인 후 FIFO 규칙 깨고 주문 배치 필요
    if r.get(WAREHOUSE_KEY) != "idle":
        return None

    free_station = _get_free_station()
    if not free_station:
        return None

    # 큐에서 '살아있는' 주문이 나올 때까지 꺼냄
    while True:
        next_order_id = r.lpop(QUEUE_KEY)
        if not next_order_id:
            return None                                  # 큐가 비었음 → 배정할 게 없음
        if r.exists(f"order:{next_order_id}"):
            break                                        # 정상 주문 찾음 → 루프 탈출
        logger.warning(f"[assign] 만료된 주문 건너뜀 ({next_order_id})")
        # exists가 False면 lpop으로 이미 큐에서 빠졌으니 그냥 버리고 다음 반복

    r.set(WAREHOUSE_KEY, "busy")
    r.set(WAREHOUSE_ORDER_KEY, next_order_id)  # 창고가 지금 이 주문의 부품을 꺼내는 중
    r.hset(STATION_KEY, free_station, "busy")
    r.set(f"{STATION_ORDER_PREFIX}{free_station}", next_order_id)  # 이 조립대에 배정된 주문
    r.hset(f"order:{next_order_id}", mapping={
        "stage": "assigned",
        "station_id": free_station
    })

    _touch(
        WAREHOUSE_KEY, WAREHOUSE_ORDER_KEY, STATION_KEY,
        f"{STATION_ORDER_PREFIX}{free_station}", f"order:{next_order_id}"
    )
    if not _dispatch_order(next_order_id):
        logger.error(f"[assign] 불출 지시 실패 → 배정 롤백 ({next_order_id})")
        r.set(WAREHOUSE_KEY, "idle")
        r.delete(WAREHOUSE_ORDER_KEY)
        r.hset(STATION_KEY, free_station, "idle")
        r.delete(f"{STATION_ORDER_PREFIX}{free_station}")
        if r.exists(f"order:{next_order_id}"):          # 해시가 살아있을 때만 큐 복귀
            r.hset(f"order:{next_order_id}", "stage", "queued")
            r.hdel(f"order:{next_order_id}", "station_id")
            r.lpush(QUEUE_KEY, next_order_id)           # 큐 맨 앞으로
        _touch(WAREHOUSE_KEY, STATION_KEY, QUEUE_KEY)
        _push_station_snapshot()
        return None

    _push_station_snapshot()
    return next_order_id

def check_station_timeouts():
    """in_progress 상태로 STATION_TIMEOUT_SEC 넘은 조립대를 자동 완료 처리."""
    now = datetime.now(KST)
    started_keys = r.keys(f"{STATION_VERIFIED_PREFIX}*")

    for key in started_keys:
        station_id = key.replace(STATION_VERIFIED_PREFIX, "")
        station_id = str(station_id)
        verified_at = datetime.fromisoformat(r.get(key))

        if (now - verified_at).total_seconds() > STATION_TIMEOUT_SEC:
            _complete_station(station_id)

