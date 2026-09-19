import redis
import os

REDIS_URL = os.getenv("REDIS_URL", "rediss://default:AakGAAIgcDFkZjlhYzIzYTMxYTY0YWNmOTliMjk0YmRkMGFiMGNkNg@proud-man-43270.upstash.io:6379")
r = redis.from_url(REDIS_URL, decode_responses=True)

