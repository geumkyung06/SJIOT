import logging
import sys

logger = logging.getLogger("sjiot")

if not logger.handlers:
    _h = logging.StreamHandler(sys.stdout)
    _h.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logger.addHandler(_h)
    logger.setLevel(logging.DEBUG)
    logger.propagate = False