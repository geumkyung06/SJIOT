import redis
import os

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6380")
r = redis.from_url(REDIS_URL, decode_responses=True)

def init_robot_status():
    if not r.exists("robot:status"):
        r.hset("robot:status", mapping={"1": "idle", "2": "idle", "3": "idle"})