import 'dart:convert';
import 'package:http/http.dart' as http;

/// Flask 백엔드(POST /order, GET /order/<id>/status) 연동.
/// baseUrl은 실제 EC2 도메인으로 교체해서 쓰세요.
class ApiService {
  static const String baseUrl =
      'https://sjiot-backend-294910862364.asia-northeast1.run.app';

  Future<Map<String, dynamic>> createOrder({
    required int board,
    required String keycap,
    required List<String> colors,
    String? axis, // 'blue' | 'brown' | 'red' | 'black' — 백엔드에는 'switch' 키로 전송
  }) async {
    final payload = {
      'board': board,
      'keycap': keycap,
      'colors': colors,
      // [수정] 축 정보는 필드명을 axis가 아닌 switch로 보냄
      if (axis != null) 'switch': axis,
    };

    // [수정] http.post 실행 직전에 로그를 남깁니다.
    print(">>> [DEBUG] 전송 시작!");
    print(">>> [DEBUG] 전송 데이터: ${jsonEncode(payload)}");

    final res = await http.post(
      Uri.parse('$baseUrl/order'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? '주문 생성 실패 (${res.statusCode})');
    }
    return Map<String, dynamic>.from(body['order_status']);
  }

  Future<Map<String, dynamic>> getOrderStatus(String orderId) async {
    final res = await http.get(Uri.parse('$baseUrl/order/$orderId/status'));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? '상태 조회 실패 (${res.statusCode})');
    }
    return body;
  }

  Future<Map<String, dynamic>> getQueueStatus() async {
    final res = await http.get(Uri.parse('$baseUrl/queue/status'));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? '대기열 조회 실패 (${res.statusCode})');
    }
    return body;
  }

  Future<Map<String, List<String>>> getSoldOutStock() async {
    final res = await http.get(
      Uri.parse('$baseUrl/stock/out'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final Map<String, dynamic> body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      return {
        // 품절 항목이 없는 카테고리는 응답에 키가 없을 수 있으므로
        // 없으면 빈 리스트로 처리
        'board': List<String>.from(body['board'] ?? []),
        'keycap': List<String>.from(body['keycap'] ?? []),
        'switch': List<String>.from(body['switch'] ?? []),
      };
    }

    if (res.statusCode == 503) {
      throw Exception('재고 정보가 아직 준비되지 않았습니다.');
    }

    throw Exception('재고 조회 실패 (${res.statusCode})');
  }
}
