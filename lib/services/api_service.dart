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

/// Flask 백엔드(POST /order, GET /order/<order_id>/status) 연동.
/// baseUrl은 실제 EC2 도메인으로 교체해서 쓰세요.
class ApiService {
  final String baseUrl =
      'https://sjiot-backend-294910862364.asia-northeast1.run.app';

  Future<Map<String, dynamic>> getStationStatus({
    required int stationId,
  }) async {
    final uri = Uri.parse('$baseUrl/station/$stationId/status');

    debugPrint('========== 조립대 주문 조회 API ==========');
    debugPrint('GET $uri');
    debugPrint('station_id: $stationId');

    final res = await http.get(uri, headers: {'Accept': 'application/json'});

    debugPrint('statusCode: ${res.statusCode}');
    debugPrint('response body: ${res.body}');
    debugPrint('=========================================');

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
      action: 'STATION_STATUS',
      statusCode: res.statusCode,
      body: res.body,
      data: data,
    );
  }

  Future<Map<String, dynamic>> getOrderStatus({required String orderId}) async {
    final uri = Uri.parse('$baseUrl/order/$orderId/status');

    debugPrint('========== 주문 상태 조회 API ==========');
    debugPrint('GET $uri');
    debugPrint('order_id: $orderId');

    final res = await http.get(uri, headers: {'Accept': 'application/json'});

    debugPrint('statusCode: ${res.statusCode}');
    debugPrint('response body: ${res.body}');
    debugPrint('======================================');

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
      action: 'ORDER_STATUS',
      statusCode: res.statusCode,
      body: res.body,
      data: data,
    );
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

  /// 노쇼(호출 시간 초과) 처리
  ///
  /// POST /station/{station_id}/cancel
  /// 서버에서 주문 stage를 expired로 바꾸고 조립대를 비운 뒤
  /// 대기열의 다음 주문을 재배정한다.
  Future<Map<String, dynamic>> cancelStation({
    required int stationId,
    required String orderId,
  }) async {
    final uri = Uri.parse('$baseUrl/station/$stationId/unclaim');

    final requestBody = {'order_id': orderId};

    debugPrint('========== 조립대 취소(노쇼) API ==========');
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
    debugPrint('=========================================');

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
      action: 'UNCLAIM',
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
