import json
from datetime import datetime, timezone, timedelta

from infra.extensions import r
from infra.logger import logger
from infra.keys import _touch_order
from infra.mobius import create_cin

from config import KST, STAGE_ORDER, STATION_ORDER_PREFIX
from services import stock, watchdog

_ALIAS = {
    "keycap_mismatched": "assigned",
    "board_mismatched": "tray_reached",
    "unclaimed": "arrived",
}
_RANK = {s: i for i, s in enumerate(STAGE_ORDER)}


def rank(stage):
    return _RANK.get(_ALIAS.get(stage, stage), -1)

def is_at_or_past(stage, target):
    """이미 그 단계를 지났는가 — 재전송 알림을 거르는 가드."""
    return rank(stage) >= rank(target)


# ── 라우트 가드용 원본 순번 ──────────────────────────────────────────
# rank()는 _ALIAS로 unclaimed를 arrived에 접는다. 재전송을 거를 땐 그게 맞지만
# (노쇼는 arrived의 곁가지지 그 다음 단계가 아니다), 라우트 가드는 둘을 구분해야 한다.
# unclaimed 주문에 /start가 들어오면 rank 기준으론 arrived와 동급이라 그냥 통과한다.
# 그래서 가드는 STAGE_ORDER 배열 순서를 그대로 쓴다.

def stage_index(stage):
    """STAGE_ORDER 원본 순번. 모르는 값은 -1."""
    return _RANK.get(stage, -1)

def is_before(stage, target):
    """STAGE_ORDER 기준 target보다 앞인가. stage가 None이면 True(아직 안 왔다)."""
    return stage_index(stage) < stage_index(target)

def is_after(stage, target):
    """STAGE_ORDER 기준 target보다 뒤인가."""
    return stage_index(stage) > stage_index(target)

TERMINAL = {"completed", "unclaimed"}


def set_stage(order_id, stage):
    """stage 전이 + cnt_process push. 콜백은 항상 이걸로만 stage를 바꾼다."""
    key = f"order:{order_id}"
    prev = r.hget(key, "stage")
    r.hset(key, "stage", stage)
    _touch_order(order_id)
    logger.info(f"[stage] {order_id} {prev} -> {stage}")

    if stage in TERMINAL:
        watchdog.disarm(order_id)
    else:
        watchdog.arm(order_id, stage)

    # push 성공 여부를 돌려준다 — 명령 채널이 cnt_process 하나뿐이라
    # '창고가 이 주문을 받았는가'의 판정 근거가 이것밖에 없다 (dispatch._assign).
    return push_process()

def set_fault(order_id, fault, section=None):
    """fault만 세우고 stage는 그대로 둔다
    관리자가 fault를 지우면 그 자리에서 이어진다.

    section 은 '어디가 문제냐' — fault 가 '무엇이 고장났나'이므로 두 축을 한 문자열에 섞지 않는다.
    형식은 part[:scope[:slot]] (services/stock.py::section_of). 없으면 지운다 —
    앞 fault 의 section 이 남으면 엉뚱한 부품을 가리킨다.
    """
    key = f"order:{order_id}"
    if section:
        r.hset(key, mapping={"fault": fault, "fault_section": section})
    else:
        r.hset(key, "fault", fault)
        r.hdel(key, "fault_section")
    _touch_order(order_id)
    watchdog.disarm(order_id)
    logger.error(f"[fault] {order_id} <- {fault}" + (f" @{section}" if section else "")
                 + f" (stage={r.hget(key, 'stage')} 유지)")
    push_process()

def clear_fault(order_id):
    """관리자 해제 — stage는 그대로이므로 그 자리에서 이어지고, 시계만 다시 건다."""
    key = f"order:{order_id}"
    r.hdel(key, "fault", "fault_section")
    _touch_order(order_id)
    watchdog.arm(order_id, r.hget(key, "stage"))
    push_process()


# cnt_process 스냅샷
def active_order_ids():
    """진행 중 주문 = 조립대에 배정된 주문. queued는 스냅샷에 올리지 않는다."""
    oids = []
    for sid in ("1", "2", "3"):
        oid = r.get(f"{STATION_ORDER_PREFIX}{sid}")
        if oid:
            oids.append(oid)
    return oids

def _build_body():
    """스냅샷의 '내용' 부분. seq·updated_at은 뺀다 — 매번 달라져서 비교가 안 되므로."""
    orders = {}
    for oid in active_order_ids():
        o = r.hgetall(f"order:{oid}")
        if not o:
            continue
        orders[oid] = {
            "station_id": o.get("station_id"),
            "order_seq": int(o.get("order_seq") or 0),
            "status": o.get("stage"),          # Redis stage → 스냅샷 status
            "board": o.get("board"),
            "keycap": o.get("keycap"),
            "colors": [c for c in (o.get("colors") or "").split(",") if c],
            "fault": o.get("fault") or None,
            "fault_section": o.get("fault_section") or None,   # 어느 부품·선반인지
        }

    body = {"orders": orders}
    # 스냅샷은 전량이므로 수신측은 '키 없음 = 빈 목록'으로 읽어야 한다 
    keycap_restock = restock_list("keycap")
    if keycap_restock:
        body["keycap_restock"] = keycap_restock

    board_restock = restock_list("board")
    if board_restock:
        body["board_restock"] = board_restock

    return body

def push_process(periodic=False):
    """진행 중 주문 전체를 통째로 push. 변경분만 보내면 머신이 상태를 들게 된다.

    내용이 직전 push와 같으면 아예 올리지 않는다.
      - 아무 데서나 push_process()를 불러도 안전하고 (재고 콜백 34개 포함)
      - seq가 '내용이 바뀔 때만' 오른다는 약속이 실제로 지켜진다.

    periodic=True 는 주기 재전송용 — 내용이 그대로면 seq를 유지한 채 다시 올린다.
    수신측의 'seq 같으면 무시' 필터가 여기서 작동한다.
    """
    body = _build_body()
    fingerprint = json.dumps(body, sort_keys=True, ensure_ascii=False)
    changed = fingerprint != r.get("process:last")

    if not changed and not periodic:
        return True

    if changed:
        seq = r.incr("process:seq")
        r.set("process:last", fingerprint)
    else:
        seq = int(r.get("process:seq") or 0)

    con = {
        "seq": seq,
        "updated_at": datetime.now(KST).isoformat(timespec="seconds"),
        **body,
    }
    logger.info(f"[process] push seq={seq} orders={list(body['orders'])} "
                f"keycap_restock={body.get('keycap_restock')} board_restock={body.get('board_restock')}")
    return create_cin("cnt_process", con)

def restock_list(kind):
    """채워야 할 칸 목록. 순서가 흔들리면 내용이 같은데 fingerprint가 달라지므로 stock에서 정렬해 준다."""
    return stock.restock_list(kind)
