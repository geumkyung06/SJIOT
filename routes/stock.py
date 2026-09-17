from flask import Blueprint, jsonify

from services.stock import get_stocks, get_out_of_stock, get_status

bp = Blueprint('stock', __name__)


@bp.route('/stock', methods=["GET"])
def get_all_of_stock_status():
    """
    전체 재고 조회
    ---
    tags:
      - Stock
    responses:
      200:
        description: 카트리지 36칸의 남은 수량
        schema:
          type: object
          example: {"keycap": {"E_r": 50, "E_y": 48}, "board": {"r": 30, "b": 12}}
      503:
        description: 재고 정보를 아직 캐시하지 못함 (카트리지 구독 알림 미수신)
    """
    stocks = get_stocks()
    if stocks is None:
        return jsonify({"error": '재고 정보를 아직 불러오지 못했습니다'}), 503
    return jsonify(stocks), 200


@bp.route('/stock/out', methods=['GET'])
def get_out_of_stock_status():
    """
    품절 항목 조회
    ---
    tags:
      - Stock
    responses:
      200:
        description: 주문받을 수 없는 항목. 멀쩡한 카테고리는 키 자체가 응답에 없음.
        schema:
          type: object
          properties:
            board:
              type: array
              items: {type: string}
              description: 주문 표기(POST /order의 board 값과 같은 표기)
              example: ["blue"]
            keycap:
              type: array
              items: {type: string}
              description: 글자_색상 조합
              example: ["E_r", "J_b"]
      503:
        description: 재고 정보를 아직 캐시하지 못함
    """
    out = get_out_of_stock()
    if out is None:
        return jsonify({'error': '재고 정보를 아직 불러오지 못했습니다'}), 503
    return jsonify(out), 200


@bp.route('/stock/status', methods=['GET'])
def get_cartridge_status():
    """
    카트리지 상태 조회 (idle / busy / empty / disable)
    ---
    tags:
      - Stock
    responses:
      200:
        description: 카트리지 36칸의 최신 status. 한 번도 못 받은 칸은 unknown.
        schema:
          type: object
          example: {"keycap": {"E_r": "idle", "E_y": "busy"}, "board": {"r": "idle"}}
    """
    return jsonify(get_status()), 200
