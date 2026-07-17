import 'dart:convert';
import 'package:http/http.dart' as http;

/// Flask 백엔드(POST /order, GET /order/<id>/status) 연동.
/// baseUrl은 실제 EC2 도메인으로 교체해서 쓰세요.
class ApiService {
  static const String baseUrl = 'https://sjiot-backend-294910862364.asia-northeast1.run.app';

  Future<Map<String, dynamic>> createOrder({
    required int board,
    required String keycap,
    required List<String> colors,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/order'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'board': board, 'keycap': keycap, 'colors': colors}),
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
}
