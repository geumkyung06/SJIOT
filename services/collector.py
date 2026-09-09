"""'전부 모여야 다음 단계' 공통 처리.

이 패턴이 4군데 나온다.

    keycap_dispense   ×4                        → keycap_dispensed
    keycap_conveyor   keycap1~4 done            → keycap_reached
    keycap_robot_arm  ×4                        → keycap_packed
    board_dispense(색 대조) + board_robot_arm    → board_packed

두 가지 도구를 둔다.

  1) 목록 소진형 (arm / consume)
     배정 시점에 '기대 목록'을 pending 리스트로 깔아두고,
     하나 들어올 때마다 LREM으로 지운다.
       - 지워지면 정상        → 남은 게 있으면 waiting, 비면 done
       - 못 지우면 오배출     → unexpected (4건 다 기다릴 필요 없이 그 자리에서 불일치)

     받은 개수를 세지 않고 '남은 것'을 세는 이유:
     재출고는 부족분만 내려보내므로(명세 8-2) 목표치가 4가 아니게 된다.
     개수를 세면 재출고 라운드마다 목표치를 따로 관리해야 하는데,
     pending은 그냥 이어서 소진되므로 분기가 필요 없다.

  2) 플래그 취합형 (mark / has_all)
     서로 다른 컨테이너의 신호가 모여야 한 단계가 되는 경우.
     board_packed = board_dispense(색 일치) + board_robot_arm(done).
     어느 쪽이 늦게 와도 마지막에 온 콜백이 완성을 확인한다.
"""
from infra.extensions import r
from config import ORDER_TTL

def _pending_key(order_id, slot):
    return f"order:{order_id}:{slot}:pending"

def _wrong_key(order_id, slot):
    return f"order:{order_id}:{slot}:wrong"

def _gate_key(order_id):
    return f"order:{order_id}:gate"


def arm(order_id, slot, items):
    """기대 목록을 깐다. 배정(assigned)·tray_reached 진입 시 1회.

        arm(oid, "keycap", ["E_r", "S_y", "F_b", "J_g"])
        arm(oid, "board",  ["b"])
    """
    pending = _pending_key(order_id, slot)
    pipe = r.pipeline()
    pipe.delete(pending, _wrong_key(order_id, slot))
    if items:
        pipe.rpush(pending, *items)
        pipe.expire(pending, ORDER_TTL)
    pipe.execute()


def consume(order_id, slot, item):
    """1건 수신. ("done" | "waiting" | "unexpected", 남은목록) 반환.

    Redis 갱신은 이 함수 안에서 끝난다. 호출부는 반환값만 보고 stage를 정한다.
    """
    pending = _pending_key(order_id, slot)
    wrong = _wrong_key(order_id, slot)

    if r.lrem(pending, 1, item) == 0:
        # 기대 목록에 없는 게 나왔다 = 오배출
        r.rpush(wrong, item)
        r.expire(wrong, ORDER_TTL)
        return "unexpected", r.lrange(pending, 0, -1)

    left = r.lrange(pending, 0, -1)
    if left:
        return "waiting", left
    if r.llen(wrong):
        # 남은 건 없지만 앞에서 오배출이 있었다
        return "unexpected", []
    return "done", []


def remaining(order_id, slot):
    """부족분. 재출고 명령에 그대로 싣는다."""
    return r.lrange(_pending_key(order_id, slot), 0, -1)


def wrong(order_id, slot):
    """오배출로 들어온 것들. 관리자 페이지 표시용."""
    return r.lrange(_wrong_key(order_id, slot), 0, -1)


def retry(order_id, slot):
    """재출고 라운드 시작. 오배출 기록만 비우고 부족분을 반환한다.
    pending은 남겨둔다 — 다음 라운드가 이어서 소진한다."""
    r.delete(_wrong_key(order_id, slot))
    return remaining(order_id, slot)


def clear(order_id, slot):
    r.delete(_pending_key(order_id, slot), _wrong_key(order_id, slot))


def mark(order_id, flag):
    r.hset(_gate_key(order_id), flag, "1")
    r.expire(_gate_key(order_id), ORDER_TTL)

def has_all(order_id, *flags):
    return all(r.hmget(_gate_key(order_id), list(flags)))

def reset_gate(order_id, *flags):
    if flags:
        r.hdel(_gate_key(order_id), *flags)
    else:
        r.delete(_gate_key(order_id))