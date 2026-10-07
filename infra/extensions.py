import redis
import os

REDIS_URL = os.getenv("REDIS_URL", "localhost")
r = redis.from_url(REDIS_URL, decode_responses=True)
