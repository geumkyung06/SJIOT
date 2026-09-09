import json
from datetime import datetime, timezone, timedelta

from infra.extensions import r
from infra.logger import logger
from infra.keys import _touch
from infra.mobius import create_cin

from config import KST, STAGE_ORDER

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

def set_stage(order_id, stage):
    """stage 전이 + cnt_process push. 콜백은 항상 이걸로만 stage를 바꾼다."""
    key = f"order:{order_id}"
    prev = r.hget(key, "stage")
    r.hset(key, "stage", stage)
    _touch(key)
    logger.info(f"[stage] {order_id} {prev} -> {stage}")
    push_process()

def set_fault(order_id, fault):
    """fault만 세우고 stage는 그대로 둔다
    관리자가 fault를 지우면 그 자리에서 이어진다."""
    key = f"order:{order_id}"
    r.hset(key, "fault", fault)
    _touch(key)
    logger.error(f"[fault] {order_id} <- {fault} (stage={r.hget(key, 'stage')} 유지)")
    push_process()

def clear_fault(order_id):
    r.hdel(f"order:{order_id}", "fault")
    _touch(f"order:{order_id}")
    push_process()


# cnt_process 스냅샷
def active_order_ids():
    """진행 중 주문 = 조립대에 배정된 주문. queued는 스냅샷에 올리지 않는다."""
    oids = []
    for sid in ("1", "2", "3"):
        oid = r.get(f"station:current_order:{sid}")
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
            "colors": json.loads(o.get("colors") or "[]"),
            "fault": o.get("fault") or None,
        }

    body = {"orders": orders}
    # 스냅샷은 전량이므로 수신측은 '키 없음 = 빈 목록'으로 읽어야 한다 
    key_restock = restock_list("keycap")
    if key_restock:
        body["key_restock"] = key_restock

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
                f"key_restock={body.get('key_restock')} board_restock={body.get('board_restock')}")
    return create_cin("cnt_process", con)

def restock_list(kind):
    """warehouse:stock에서 재고가 바닥난 칸 목록.
    """
    out = []
    for cid, raw in (r.hgetall("warehouse:stock") or {}).items():
        try:
            s = json.loads(raw)
        except (ValueError, TypeError):
            continue
        is_board = "_" not in cid                    # 보드는 'r', 키캡은 'E_r'
        if (kind == "board") != is_board:
            continue
        if int(s.get("count") or 0) <= 0 or s.get("status") == "empty":
            out.append(cid)
    return sorted(out)      # 순서가 흔들리면 내용이 같은데 fingerprint가 달라진다