"""조립대 종료 경로. 배정 자체는 services/dispatch.py 가 맡는다."""
from datetime import datetime

from config import (STATION_KEY,
                    STATION_ORDER_PREFIX,
                    STATION_VERIFIED_PREFIX,
                    KST,
                    STATION_TIMEOUT_SEC,
                   )
from infra.extensions import r
from infra.logger import logger

from services.process import set_stage
from services.dispatch import release_station, try_assign_next


def _complete_station(station_id):
    """완료 버튼 / 조립 타임아웃 공통 경로."""
    station_id = str(station_id)
    order_id = r.get(f"{STATION_ORDER_PREFIX}{station_id}")
    if not order_id:
        return None                      # 조기 반환. 아무것도 건드리지 않는다.

    r.delete(f"{STATION_VERIFIED_PREFIX}{station_id}")
    set_stage(order_id, "completed")     # cnt_process push + 워치독 해제

    # cnt_station은 배정 시점에만 올린다. 배정이 되면 _assign이 올리고,
    # 안 되면 조립대가 빈 채로 남으므로 다음 배정 때 한 번에 반영된다.
    release_station(station_id)
    return order_id


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
            _complete_station(station_id)
