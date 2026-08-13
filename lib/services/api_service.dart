import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String action;
  final int statusCode;
  final String body;
  final Map<String, dynamic>? data;

  ApiException({
    required this.action,
    required this.statusCode,
    required this.body,
    this.data,
  });

  @override
  String toString() {
    return '$action 실패 ($statusCode): $body';
  }
}

/// Flask 백엔드(POST /order, GET /order/<id>/status) 연동.
/// baseUrl은 실제 EC2 도메인으로 교체해서 쓰세요.
class ApiService {
  final String baseUrl =
      'https://sjiot-backend-294910862364.asia-northeast1.run.app';

  Future<Map<String, dynamic>> getOrder(String orderId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/order/$orderId/status'),
      headers: {'Accept': 'application/json'},
    );

    Map<String, dynamic>? body;

    try {
      final decoded = jsonDecode(res.body);

      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {
      body = null;
    }

    if (res.statusCode == 200 && body != null) {
      return body;
    }

    throw Exception(body?['error'] ?? '주문 조회 실패 (${res.statusCode})');
  }

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

  Future<Map<String, dynamic>> startStation({
    required String orderId,
    required int stationId,
  }) async {
    final uri = Uri.parse('$baseUrl/station/$orderId/start');

    final requestBody = {'station_id': stationId};

    debugPrint('========== 조립 시작 API ==========');
    debugPrint('POST $uri');
    debugPrint('보내는 order_id: $orderId');
    debugPrint('보내는 station_id: $stationId');
    debugPrint('body: ${jsonEncode(requestBody)}');

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    debugPrint('statusCode: ${res.statusCode}');
    debugPrint('response body: ${res.body}');
    debugPrint('==================================');

    Map<String, dynamic>? data;

    try {
      final decoded = jsonDecode(res.body);

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {
      data = null;
    }

    if (res.statusCode == 200) {
      return data ?? <String, dynamic>{};
    }

    throw ApiException(
      action: 'START',
      statusCode: res.statusCode,
      body: res.body,
      data: data,
    );
  }

  Future<Map<String, dynamic>> completeStation({
    required int stationId,
    required String orderId,
  }) async {
    final uri = Uri.parse('$baseUrl/station/$stationId/complete');

    final requestBody = {'order_id': orderId};

    debugPrint('========== 조립 완료 API ==========');
    debugPrint('POST $uri');
    debugPrint('보내는 station_id: $stationId');
    debugPrint('보내는 order_id: $orderId');
    debugPrint('body: ${jsonEncode(requestBody)}');

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    debugPrint('statusCode: ${res.statusCode}');
    debugPrint('response body: ${res.body}');
    debugPrint('==================================');

    Map<String, dynamic>? data;

    try {
      final decoded = jsonDecode(res.body);

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {
      data = null;
    }

    if (res.statusCode == 200) {
      return data ?? <String, dynamic>{};
    }

    throw ApiException(
      action: 'COMPLETE',
      statusCode: res.statusCode,
      body: res.body,
      data: data,
    );
  }
}
