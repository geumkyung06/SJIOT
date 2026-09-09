"""큐 → 조립대 배정.

배정 게이트 셋.
    1. 창고가 비었나        warehouse:occupancy == idle   (주문 1건씩 처리)
    2. 조립대 빈 칸이 있나   station:current_order:{1,2,3}
    3. 이 주문이 쓰는 카트리지 5칸이 멀쩡한가   stock.blockers()

카트리지 idle/busy는 게이트로 쓰지 않는다. 창고가 idle이면 카트리지도 idle이어야 하고,
idle CIN 하나만 유실돼도(주문당 카트리지 콜백이 10건) 그 칸이 영구히 busy로 남아 교착된다.

배정 트리거 — 배정을 막던 조건이 풀리는 지점 전부에서 try_assign_next()를 부른다.
창고 busy거나 빈 조립대가 없으면 즉시 None으로 빠지므로 값이 싸다.
    POST /order 접수 직후          큐에 새 주문
    pickup_reached                 창고가 비었음 (트레이가 픽업대 도착, 벨트 비었음)
    completed / unclaimed          조립대가 비었음
    카트리지 정상 복귀              막혀 있던 주문이 풀림
"""
import json

from config import QUEUE_KEY, WAREHOUSE_KEY, STATION_KEY, WAREHOUSE_ORDER_KEY, STATION_ORDER_PREFIX
from infra.extensions import r
from infra.logger import logger
from infra.keys import _touch, _touch_order, _get_free_station
from infra.mobius import _dispatch_order, _push_station_snapshot

from services import stock, collector
from services.process import set_stage, push_process

STATIONS = ("1", "2", "3")

# True  = 앞 주문이 재고로 막히면 건너뛰고 뒤 주문을 먼저 배정
# False = FIFO 엄수. 앞이 막히면 전부 대기
SKIP_BLOCKED = True


def try_assign_next():
    """큐 앞에서부터 훑어 처음으로 배치 가능한 주문 1건을 배정. 배정했으면 order_id."""
    if r.get(WAREHOUSE_KEY) != "idle" or r.get(WAREHOUSE_ORDER_KEY):
        return None

    station_id = _get_free_station()
    if not station_id:
        return None

    # lpop으로 꺼내면 건너뛸 수 없다. 훑고, 실제로 가져갈 것만 lrem 한다.
    for order_id in r.lrange(QUEUE_KEY, 0, -1):
        if not r.exists(f"order:{order_id}"):
            r.lrem(QUEUE_KEY, 1, order_id)
            logger.warning(f"[assign] 만료된 주문 정리 ({order_id})")
            continue

        blocked = stock.blockers(order_id)
        if not blocked:
            return _assign(order_id, station_id)

        logger.warning(f"[assign] {order_id} 보류 — {blocked}")
        r.hset(f"order:{order_id}", "blocked_by", json.dumps(blocked, ensure_ascii=False))
        if not SKIP_BLOCKED:
            return None

    return None


def _assign(order_id, station_id):
    okey = f"order:{order_id}"

    r.lrem(QUEUE_KEY, 1, order_id)
    r.hset(okey, "station_id", station_id)
    r.hdel(okey, "blocked_by")

    r.set(f"{STATION_ORDER_PREFIX}{station_id}", order_id)
    r.hset(STATION_KEY, station_id, "busy")

    r.set(WAREHOUSE_KEY, "busy")
    r.set(WAREHOUSE_ORDER_KEY, order_id)

    # 키캡 4개 기대 목록. 이게 있어야 cnt_keycap_dispense 콜백이 소진할 게 생긴다.
    # arm을 빼먹으면 dispense가 전부 unexpected로 떨어져 곧장 mismatched가 된다.
    collector.arm(order_id, "keycap", stock.parts_of(order_id, "keycap"))
    collector.reset_gate(order_id)

    _touch(WAREHOUSE_KEY, WAREHOUSE_ORDER_KEY, STATION_KEY, f"{STATION_ORDER_PREFIX}{station_id}")
    _touch_order(order_id)

    # cnt_order 기록. 실패하면 배정을 통째로 되돌린다 — 창고가 못 받은 주문을 진행 중으로 두면 안 된다.
    if not _dispatch_order(order_id):
        logger.error(f"[assign] cnt_order 기록 실패 → 배정 롤백 ({order_id})")
        _rollback(order_id, station_id)
        return None

    logger.info(f"[assign] {order_id} → station {station_id}")
    set_stage(order_id, "assigned")     # cnt_process push까지 여기서 일어난다
    _push_station_snapshot()
    return order_id


def _rollback(order_id, station_id):
    r.set(WAREHOUSE_KEY, "idle")
    r.delete(WAREHOUSE_ORDER_KEY)
    r.hset(STATION_KEY, station_id, "idle")
    r.delete(f"{STATION_ORDER_PREFIX}{station_id}")
    collector.clear(order_id, "keycap")
    collector.reset_gate(order_id)
    if r.exists(f"order:{order_id}"):
        r.hset(f"order:{order_id}", "stage", "queued")
        r.hdel(f"order:{order_id}", "station_id")
        r.lpush(QUEUE_KEY, order_id)                 # 큐 맨 앞으로
    _touch(WAREHOUSE_KEY, STATION_KEY, QUEUE_KEY)
    # cnt_station push는 _assign 성공 후에만 일어난다. 롤백 시점엔 올린 게 없다.


def release_warehouse():
    """pickup_reached — 트레이가 픽업대에 도착해 벨트가 비었다. 다음 주문을 받을 수 있다."""
    r.set(WAREHOUSE_KEY, "idle")
    r.delete(WAREHOUSE_ORDER_KEY)
    _touch(WAREHOUSE_KEY)
    return try_assign_next()


def release_station(station_id):
    """completed / unclaimed — 조립대를 비운다."""
    r.delete(f"{STATION_ORDER_PREFIX}{station_id}")
    r.hset(STATION_KEY, str(station_id), "idle")
    _touch(STATION_KEY)
    return try_assign_next()


def on_stock_recovered():
    """카트리지가 empty/disable에서 정상으로 돌아왔을 때.
    이게 없으면 재고를 채워도 blocked_by가 붙은 주문이 다음 종료까지 대기한다."""
    assigned = try_assign_next()
    if assigned is None:
        push_process()          # 배정이 안 돼도 restock 목록은 갱신해서 내보낸다
    return assigned
