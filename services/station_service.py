"""조립대 종료 경로. 배정 자체는 services/dispatch.py 가 맡는다."""
import math
from datetime import datetime

from config import (STATION_KEY,
                    STATION_ORDER_PREFIX,
                    STATION_VERIFIED_PREFIX,
                    KST,
                    STATION_TIMEOUT_SEC,
                    STATION_UNCLAIM_MIN_SEC,
                   )
from infra.extensions import r
from infra.logger import logger

from services.archive import finish_order


def _complete_station(station_id, reason=None):
    """완료 버튼 / 조립 타임아웃 공통 경로.

    아카이브·집계·자원 해제는 services/archive.finish_order 가 전부 맡는다.
    cnt_station은 배정 시점에만 올린다 — 배정이 되면 _assign이 올리고,
    안 되면 조립대가 빈 채로 남으므로 다음 배정 때 한 번에 반영된다.
    """
    station_id = str(station_id)
    order_id = r.get(f"{STATION_ORDER_PREFIX}{station_id}")
    if not order_id:
        return None                      # 조기 반환. 아무것도 건드리지 않는다.
    return finish_order(order_id, "completed", reason=reason)


def elapsed_since_arrival(order_data):
    """arrived_at 이후 경과 초. 기록이 없거나 깨졌으면 None."""
    raw = order_data.get("arrived_at")
    if not raw:
        return None
    try:
        return (datetime.now(KST) - datetime.fromisoformat(raw)).total_seconds()
    except ValueError:
        logger.warning(f"[station] arrived_at 파싱 실패 {raw!r}")
        return None


def unclaim_guard(order_data):
    """노쇼 처리해도 되는 시점인가. (ok, elapsed_sec, remain_sec)

    3분 카운트는 프론트가 돌리지만 그건 클라이언트 값이다. 그대로 믿으면 도착 직후에도
    요청 하나로 노쇼 처리가 되므로 서버가 arrived_at 으로 다시 잰다.
    arrived_at 이 없으면(서버 재시작 등) 막지 않는다 — 막으면 조립대가 영영 안 비고,
    그 경우는 워치독 arrived(300초)가 어차피 정리한다.
    """
    elapsed = elapsed_since_arrival(order_data)
    if elapsed is None:
        return True, None, 0
    if elapsed < STATION_UNCLAIM_MIN_SEC:
        return False, int(elapsed), math.ceil(STATION_UNCLAIM_MIN_SEC - elapsed)
    return True, int(elapsed), 0


def check_station_timeouts():
    """QR 인증 후 STATION_TIMEOUT_SEC를 넘긴 조립대를 자동 완료 처리.

    order:deadlines 워치독과 겹치는 경로다. received→completed(600초)를 워치독이 이미 보므로,
    이건 verified_at 기준 백업으로만 남긴다.
    """
    now = datetime.now(KST)
    for key in r.scan_iter(f"{STATION_VERIFIED_PREFIX}*"):
        station_id = key.replace(STATION_VERIFIED_PREFIX, "")
        raw = r.get(key)
        if not raw:
            continue
        try:
            verified_at = datetime.fromisoformat(raw)
        except ValueError:
            logger.warning(f"[timeout] verified_at 파싱 실패 (station={station_id}) {raw!r}")
            continue
        if (now - verified_at).total_seconds() > STATION_TIMEOUT_SEC:
            logger.info(f"[timeout] station {station_id} 조립 타임아웃 → completed")
            _complete_station(station_id, reason="timeout")
