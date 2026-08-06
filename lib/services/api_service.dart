import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Flask 백엔드(POST /order, GET /order/<id>/status) 연동.
/// baseUrl은 실제 EC2 도메인으로 교체해서 쓰세요.
class ApiService {
  final String baseUrl =
      'https://sjiot-backend-294910862364.asia-northeast1.run.app';

  final Map<int, Future<Map<String, dynamic>>> _completeRequests = {};

  Future<Map<String, dynamic>> getOrder(String orderId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/order/$orderId'),
      headers: {'Accept': 'application/json'},
    );

    Map<String, dynamic>? body;

    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
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
    required int stationId,
    required String orderId,
  }) async {
    final url = Uri.parse('$baseUrl/station/$stationId/start');

    final body = {'order_id': orderId};

    debugPrint('===== API 요청 =====');
    debugPrint('요청 URL: $url');
    debugPrint('station_id: $stationId');
    debugPrint('order_id: $orderId');
    debugPrint('보내는 body: ${jsonEncode(body)}');
    debugPrint('====================');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    debugPrint('===== API 응답 =====');
    debugPrint('응답 코드: ${response.statusCode}');
    debugPrint('응답 내용: ${utf8.decode(response.bodyBytes)}');
    debugPrint('====================');

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }

    throw Exception(
      'START_FAILED_${response.statusCode}: '
      '${utf8.decode(response.bodyBytes)}',
    );
  }

  Future<Map<String, dynamic>> completeStation({required int stationId}) {
    // 같은 조립대에 완료 요청이 이미 진행 중이면
    // 새로운 POST를 보내지 않고 기존 요청 결과를 같이 사용
    final existingRequest = _completeRequests[stationId];

    if (existingRequest != null) {
      debugPrint('완료 API 중복 요청 차단: station_id=$stationId');
      return existingRequest;
    }

    final request = _completeStationRequest(stationId);

    _completeRequests[stationId] = request;

    request.whenComplete(() {
      _completeRequests.remove(stationId);
    });

    return request;
  }

  Future<Map<String, dynamic>> _completeStationRequest(int stationId) async {
    final uri = Uri.parse('$baseUrl/station/$stationId/complete');

    debugPrint('완료 API 요청: POST $uri');
    debugPrint('완료 API station_id: $stationId');

    final response = await http.post(uri);

    final responseBody = utf8.decode(response.bodyBytes).trim();

    debugPrint('완료 API 응답 코드: ${response.statusCode}');
    debugPrint('완료 API 응답 내용: $responseBody');

    if (response.statusCode != 200) {
      throw Exception('COMPLETE_FAILED_${response.statusCode}: $responseBody');
    }

    // 서버의 성공 응답은 JSON이 아니라
    // "ord_a90e8302" 같은 주문번호 문자열임.
    return {'ok': true, 'order_id': responseBody};
  }
  //   Future<Map<String, dynamic>> startStation({
  //   required int stationId,
  //   required String orderId,
  // }) async {
  //   final response = await http.post(
  //     Uri.parse('$baseUrl/station/$stationId/start'),
  //     headers: {
  //       'Content-Type': 'application/json',
  //     },
  //     body: jsonEncode({
  //       'order_id': orderId,
  //     }),
  //   );

  //   if (response.statusCode == 200) {
  //     return jsonDecode(utf8.decode(response.bodyBytes));
  //   }

  //   throw Exception('START_FAILED_${response.statusCode}');
  // }
}
