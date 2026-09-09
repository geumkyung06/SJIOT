import os
from zoneinfo import ZoneInfo

QUEUE_KEY = os.getenv("QUEUE_KEY", "order:queue")
WAREHOUSE_KEY = os.getenv("WAREHOUSE_KEY", "warehouse:occupancy")
STATION_KEY = os.getenv("STATION_KEY", "station:occupancy")
AGV_KEY = os.getenv("AGV_KEY", "agv:occupancy")

FAULT_KEY = os.getenv("FAULT_KEY", "order:fault")

WAREHOUSE_ORDER_KEY = os.getenv("WAREHOUSE_ORDER_KEY", "warehouse:current_order")
WAREHOUSE_KEYCAP_DISPENSE_KEY = os.getenv("WAREHOUSE_DISPENSE_KEY", "warehouse:current_order:keycap")
WAREHOUSE_BOARD_DISPENSE_KEY = os.getenv("WAREHOUSE_DISPENSE_KEY", "warehouse:current_order:board")
STATION_ORDER_PREFIX = os.getenv("STATION_ORDER_PREFIX", "station:current_order")
MAX_QUEUE_LEN = 3  # 조립대 개수와 동일 (그 이상 대기시켜봤자 처리 못 함)

STATION_VERIFIED_PREFIX = os.getenv("STATION_VERIFIED_PREFIX", "station:verified_at")
STATION_TIMEOUT_SEC = int(os.getenv("STATION_TIMEOUT_SEC", "600"))  # 10분

ORDER_COUNTER_KEY = os.getenv("ORDER_COUNTER_KEY", "order:counter")

ORDER_PAGE_BASE = os.getenv("ORDER_PAGE_BASE", "https://sjiot-backend-294910862364.asia-northeast1.run.app")

STATION_RESET_PASSWORD = os.getenv("STATION_RESET_PASSWORD")

MBTI_AXES = [("E", "I"), ("S", "N"), ("T", "F"), ("J", "P")]

# 테스트 기간 전용: 설정돼 있으면 건드리는 키마다 이 초만큼 TTL을 계속 갱신함.
# 운영 전환 시 이 env var만 빼면(또는 0으로) 원래대로 영구 보존됨.
TEST_KEY_TTL = int(os.getenv("TEST_KEY_TTL", "0")) or None
ORDER_TTL = int(os.getenv("TEST_KEY_TTL"))

COLOR_LIST = [c.strip() for c in os.getenv("COLOR_LIST", "r,y,g,b").split(",")]
BOARD_LIST = [b.strip() for b in os.getenv("BOARD_LIST", "red,yellow,green,blue").split(",")]

MP_URL = os.getenv("MP_URL")  
CB = os.getenv("CB", "Mobius")
AE_RN = os.getenv("AE_RN")   
ORIGIN = os.getenv("MOBIUS_ORIGIN")
API_KEY = os.getenv("MOBIUS_API_KEY")
LECTURE_ID = os.getenv("X-AUTH-CUSTOM-LECTURE")
CREATOR_ID = os.getenv("X-AUTH-CUSTOM-CREATOR")

STAGE_ORDER = ["queued",
               "assigned",
               "keycap_mismatched",
               "keycap_dispensed",
               "keycap_reached",
               "keycap_packed",
               "tray_reached",
               "board_mismatched",
               "pickup_reached",
               "loaded",
               "arrived",
               "uncalimed",
               "verified",
               "received",
               "completed"
               ]

STAGE_BUSY = {
    "assigned":         ["tray_robot_arm", "keycap_cartridge"],
    "keycap_mismatched":   ["keycap_cartridge"],
    "keycap_dispensed": ["keycap_conveyor"],
    "keycap_reached":   ["keycap_robot_arm"],
    "keycap_packed":    ["tray_conveyor"],
    "tray_reached":     ["board_robot_arm"],
    "board_mismatched": ["board_robot_arm"],
    "board_packed":     ["tray_conveyor"],
    "pickup_reached":   ["agv"],
    "loaded":   ["agv"],
    "arrived":   ["agv"],
    "unclaimed":   ["agv"],
    "verified":   ["agv"],
    "received":   ["agv"], # agv : parked 보고해야 다음 주문 가능
    }

SUB_CNT_KEYCAP_PARENT = os.getenv("SUB_CNT_KEYCAP_PARENT", "cnt_keycap_status")
SUB_CNT_BOARD_PARENT  = os.getenv("SUB_CNT_BOARD_PARENT",  "cnt_board_status")

SUB_CNT_KEYCAP = [c.strip() for c in os.getenv("SUB_CNT_KEYCAP", "").split(",") if c.strip()]
SUB_CNT_BOARD  = [c.strip() for c in os.getenv("SUB_CNT_BOARD",  "").split(",") if c.strip()]

# Redis warehouse:stock 의 필드명 (cnt_ 뗀 형태)
KEYCAP_SLOTS = [c.removeprefix("cnt_") for c in SUB_CNT_KEYCAP]   # E_r
BOARD_SLOTS  = [c.removeprefix("cnt_") for c in SUB_CNT_BOARD]    # r
ALL_SLOTS    = set(KEYCAP_SLOTS) | set(BOARD_SLOTS)               # 36개, 콜백 유효성 검사용

BOARD_SLOT_MAP = dict(
    p.split(":", 1) for p in os.getenv("BOARD_SLOT_MAP", "").split(",") if ":" in p
)

KST = ZoneInfo("Asia/Seoul")