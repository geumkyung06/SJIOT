import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;

/// Flask 백엔드(POST /order, GET /order/<id>/status) 연동.
/// baseUrl은 실제 EC2 도메인으로 교체해서 쓰세요.
class ApiService {
  static const String baseUrl =
      'https://sjiot-backend-294910862364.asia-northeast1.run.app';

  // [신규] 학교/전시장 네트워크(또는 이 PC에 걸린 프록시)의 SSL 검사
  // 장비가 발급한 루트 인증서를 신뢰 목록에 "추가"해서 HandshakeException
  // (CERTIFICATE_VERIFY_FAILED)을 해결하기 위한 커스텀 클라이언트.
  //
  // 사용법:
  //   1. 학교/건물 IT 담당 부서에서 SSL 검사용 루트 인증서 파일을
  //      (.crt 또는 .pem, 텍스트로 열면 "-----BEGIN CERTIFICATE-----"로
  //      시작하는 형식) 받습니다.
  //   2. 그 파일 내용을 assets/certs/custom_root.pem 에 그대로 덮어씁니다.
  //   3. pubspec.yaml의 flutter: assets: 에 이미 등록해뒀으니 별도 설정은
  //      필요 없습니다. flutter pub get 후 다시 빌드하세요.
  //
  // 인증서 파일이 없거나(placeholder 상태) 로드에 실패하면 기존 방식
  // (기본 신뢰 목록만 사용)으로 자동 폴백하므로, 아직 파일을 못 구한
  // 상태에서 빌드해도 앱 자체는 정상 실행됩니다(단, 그 경우 이전과
  // 동일한 HandshakeException이 다시 날 수 있습니다).
  static http.Client? _client;

  static Future<http.Client> _getClient() async {
    if (_client != null) return _client!;

    try {
      final certData = await rootBundle.load(
        'assets/certs/custom_root.pem',
      );
      final context = SecurityContext(withTrustedRoots: true);
      context.setTrustedCertificatesBytes(
        certData.buffer.asUint8List(),
      );
      final httpClient = HttpClient(context: context);
      _client = http_io.IOClient(httpClient);
      // ignore: avoid_print
      print('>>> [DEBUG] 커스텀 인증서 로드 성공, 신뢰 목록에 추가됨');
    } catch (e) {
      // ignore: avoid_print
      print('>>> [DEBUG] 커스텀 인증서 로드 실패, 기본 클라이언트 사용: $e');
      _client = http.Client();
    }

    return _client!;
  }

  Future<Map<String, dynamic>> createOrder({
    // [수정] Mobius cnt_order 스펙 변경: 판(board) 크기 선택이 사라지고
    // 판 "색상"을 고르는 방식으로 바뀌면서 board가 int(칸 수)가 아니라
    // 색상 문자열이 됨: 'red' | 'yellow' | 'green' | 'blue'
    // (주의: 'red'는 화면에는 핑크로 보이지만 백엔드/코드상 색상 키는 그대로 'r'/'red'를 씁니다.)
    required String board,
    required String keycap,
    required List<String> colors,
    // [삭제] switch(축) 필드는 제품에서 완전히 제외되어 더 이상 보내지 않음
    required String idempotencyKey, // [신규] 같은 주문이 중복 처리되지 않도록 하는 키
  }) async {
    final payload = {
      'board': board,
      'keycap': keycap,
      'colors': colors,
    };

    // [수정] http.post 실행 직전에 로그를 남깁니다.
    print(">>> [DEBUG] 전송 시작! (Idempotency-Key: $idempotencyKey)");
    print(">>> [DEBUG] 전송 데이터: ${jsonEncode(payload)}");

    final client = await _getClient();
    final res = await client
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
    final client = await _getClient();
    final res = await client.get(Uri.parse('$baseUrl/order/$orderId/status'));
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
    final client = await _getClient();
    final res = await client.get(Uri.parse('$baseUrl/order/$orderId/qr'));

    if (res.statusCode != 200) {
      throw Exception('QR 코드 조회 실패 (${res.statusCode})');
    }

    return res.bodyBytes;
  }

  Future<Map<String, dynamic>> getQueueStatus() async {
    final client = await _getClient();
    final res = await client.get(Uri.parse('$baseUrl/queue/status'));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? '대기열 조회 실패 (${res.statusCode})');
    }
    return body;
  }

  // [수정] /stock/out 응답 구조가 "품절 리스트"(List<String>)에서 "색상별
  // 재고 수량"(Map)으로 바뀔 예정입니다. 다만 백엔드 배포 시점이 프론트와
  // 맞지 않을 수 있으므로, 여기서 실제로 온 값의 타입을 보고 두 형태를
  // 모두 안전하게 처리합니다.
  //   - 신규(Map) 형태: { "keycap": { "E": {"r":0,"y":3,...}, ... },
  //                        "board": {"r":3,"y":3,"b":3,"g":3} }
  //     → 수량이 0 이하인 조합만 품절로 판정
  //   - 기존(List) 형태: { "keycap": ["E_r", "I_g", ...],
  //                        "board": ["r", ...] }
  //     → 이미 품절 코드 목록이므로 그대로 사용
  // main.dart를 포함한 나머지 로직은 그대로
  //   - keycap: "LETTER_color" 형태의 품절 코드 Set<String>
  //   - board : "color" 형태의 품절 코드 Set<String>
  // 을 기대하므로, 최종적으로 이 형태로 통일해서 반환합니다.
  // switch(축)는 제품에서 제외되어 더 이상 조회하지 않습니다.
  Future<Map<String, Set<String>>> getSoldOutStock() async {
    final client = await _getClient();
    final res = await client.get(
      Uri.parse('$baseUrl/stock/out'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final Map<String, dynamic> body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      int asInt(dynamic v) {
        if (v is num) return v.toInt();
        return int.tryParse(v.toString()) ?? 0;
      }

      // keycap 파싱: Map(신규, 수량) / List(기존, 이미 품절 코드) 둘 다 대응
      final Set<String> soldOutKeycaps = {};
      final dynamic keycapRaw = body['keycap'];
      if (keycapRaw is Map) {
        keycapRaw.forEach((letter, colors) {
          if (colors is Map) {
            colors.forEach((color, qty) {
              if (asInt(qty) <= 0) soldOutKeycaps.add('${letter}_$color');
            });
          }
        });
      } else if (keycapRaw is List) {
        soldOutKeycaps.addAll(keycapRaw.map((e) => e.toString()));
      }

      // board 파싱: Map(신규, 수량) / List(기존, 이미 품절 코드) 둘 다 대응
      final Set<String> soldOutBoards = {};
      final dynamic boardRaw = body['board'];
      if (boardRaw is Map) {
        boardRaw.forEach((color, qty) {
          if (asInt(qty) <= 0) soldOutBoards.add(color.toString());
        });
      } else if (boardRaw is List) {
        soldOutBoards.addAll(boardRaw.map((e) => e.toString()));
      }

      return {
        'board': soldOutBoards,
        'keycap': soldOutKeycaps,
      };
    }

    if (res.statusCode == 503) {
      throw Exception('재고 정보가 아직 준비되지 않았습니다.');
    }

    throw Exception('재고 조회 실패 (${res.statusCode})');
  }
}
