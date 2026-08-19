import 'dart:convert';
import 'dart:typed_data';
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
    required String idempotencyKey, // [신규] 같은 주문이 중복 처리되지 않도록 하는 키
  }) async {
    final payload = {
      'board': board,
      'keycap': keycap,
      'colors': colors,
      // [수정] 축 정보는 필드명을 axis가 아닌 switch로 보냄
      if (axis != null) 'switch': axis,
    };

    // [수정] http.post 실행 직전에 로그를 남깁니다.
    print(">>> [DEBUG] 전송 시작! (Idempotency-Key: $idempotencyKey)");
    print(">>> [DEBUG] 전송 데이터: ${jsonEncode(payload)}");

    final res = await http
        .post(
          Uri.parse('$baseUrl/order'),
          headers: {
            'Content-Type': 'application/json',
            // [신규] 같은 uuid로 재시도해도 서버가 같은 주문으로 취급하게 하는 헤더
            'Idempotency-Key': idempotencyKey,
          },
          body: jsonEncode(payload),
        )
        // 응답이 영영 안 오는 상황(네트워크 문제)에 무한 대기하지 않도록 타임아웃을 둡니다.
        // 타임아웃이 나면 TimeoutException이 발생하고, main.dart에서 "응답을 못 받은
        // 경우"로 판단해 같은 idempotencyKey로 재시도합니다.
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? '주문 생성 실패 (${res.statusCode})');
    }

    // [수정] 이전에는 body['order_status'] 안쪽 내용만 반환해서, 그 바깥(최상위)에
    // order_seq 같은 필드가 있는 경우 통째로 유실되고 있었습니다.
    // 최상위 필드와 order_status 안쪽 필드를 모두 합쳐서 반환합니다.
    final orderStatusRaw = body['order_status'];
    final orderStatus = orderStatusRaw is Map
        ? Map<String, dynamic>.from(orderStatusRaw)
        : <String, dynamic>{};

    return {
      ...body,
      ...orderStatus,
    };
  }

  Future<Map<String, dynamic>> getOrderStatus(String orderId) async {
    final res = await http.get(Uri.parse('$baseUrl/order/$orderId/status'));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? '상태 조회 실패 (${res.statusCode})');
    }
    return body;
  }

  /// GET /order/{order_id}/qr — 주문 상태 페이지 QR 코드 생성.
  /// [주의] 서버가 QR 이미지(PNG 등)를 응답 바디에 그대로 실어 보내는
  /// 경우를 기준으로 작성했습니다. 만약 실제로는 JSON
  /// (예: {"qr_base64": "..."} 또는 {"qr_url": "..."})으로 온다면
  /// 그 형태를 알려주시면 파싱 방식을 맞춰 수정하겠습니다.
  Future<Uint8List> getOrderQr(String orderId) async {
    final res = await http.get(Uri.parse('$baseUrl/order/$orderId/qr'));

    if (res.statusCode != 200) {
      throw Exception('QR 코드 조회 실패 (${res.statusCode})');
    }

    return res.bodyBytes;
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
