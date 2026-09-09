from config import (QUEUE_KEY,
                    WAREHOUSE_KEY,
                    STATION_KEY,
                    MBTI_AXES,
                    WAREHOUSE_ORDER_KEY,
                    STATION_ORDER_PREFIX,
                    MBTI_AXES,
                   )

from infra.logger import logger

def _is_valid_mbti(keycap: str) -> bool:
    """4글자가 각각 해당 자리 축(E/I, S/N, T/F, J/P)에 속하는지 확인."""
    if len(keycap) != 4:
        return False
    return all(
        letter.upper() in axis
        for letter, axis in zip(keycap, MBTI_AXES)
    )

