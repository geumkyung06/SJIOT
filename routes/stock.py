from flask import Blueprint, jsonify
from services.mobius import get_out_of_stock

bp = Blueprint('stock', __name__)

@bp.route('/stock/out', methods=['GET'])
def get_out_of_stock_status():
    """
    품절 항목 조회
    ---
    tags:
      - Stock
    responses:
      200:
        description: 카테고리별 품절 항목. 재고 있는 카테고리는 키 자체가 응답에 없음.
        schema:
          type: object
          properties:
            board:
              type: array
              items:
                type: string
              example: ["blue"]
            keycap:
              type: array
              items:
                type: string
              description: 글자_색상 조합 형식
              example: ["E_r", "J_b"]
      503:
        description: 재고 정보를 아직 캐시하지 못함 (cnt_stock 구독 알림 미수신)
    """
    out = get_out_of_stock()
    if out is None:
        return jsonify({'error': '재고 정보를 아직 불러오지 못했습니다'}), 503
    return jsonify(out), 200