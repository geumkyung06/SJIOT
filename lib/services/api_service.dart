import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

// [신규] 플랫폼별 HTTP 클라이언트 분기(조건부 임포트).
// - 웹(Chrome) 빌드  : http_client_web.dart  (기본 클라이언트)
// - 그 외 모든 빌드   : http_client_io.dart   (커스텀 루트 인증서 로직)
// dart:io / SecurityContext / IOClient 는 웹에 존재하지 않으므로 이렇게
// 격리해야 웹 빌드가 컴파일됩니다. 데스크톱 빌드에는 예전 코드가 그대로
// 들어가므로 Windows/macOS 동작은 변하지 않습니다.
import 'http_client_web.dart' if (dart.library.io) 'http_client_io.dart';

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
    // 실제 생성은 플랫폼별 구현에 위임합니다.
    //   http_client_io.dart  : 커스텀 루트 인증서를 신뢰 목록에 추가(기존 로직)
    //   http_client_web.dart : 브라우저가 TLS를 직접 처리하므로 기본 클라이언트
    _client = await createHttpClient();
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

  /// GET /order/{order_id}/qr — 주문 상태 페이지 QR 코드(PNG 이미지) 조회.
  /// 서버는 PNG 이미지를 응답 바디에 그대로 실어 보냅니다.
  ///
  /// [수정] 예전에는 main.dart에서 5초 한 번만 기다리고 끝냈기 때문에,
  /// 서버가 QR을 만드는 데 조금만 오래 걸려도(Cloud Run 인스턴스가 새로
  /// 뜨는 경우 등) 영수증에 QR이 빠졌습니다. 이제 아래처럼 재시도합니다.
  ///   - 한 번 요청에 최대 [perAttemptTimeout]까지 기다림
  ///   - 타임아웃 / 연결 실패 / 404(주문이 아직 조회되지 않음) / 429 / 5xx 이면
  ///     잠깐 쉬고 다시 요청 (최대 [maxAttempts]번)
  ///   - 전체 대기 시간은 [totalBudget]을 넘지 않음 (영수증이 너무 늦게
  ///     나오지 않도록)
  ///   - 그 외 응답(400 등)은 다시 요청해도 결과가 같으므로 바로 실패 처리
  Future<Uint8List> getOrderQr(
    String orderId, {
    int maxAttempts = 3,
    Duration perAttemptTimeout = const Duration(seconds: 7),
    Duration totalBudget = const Duration(seconds: 15),
  }) async {
    final client = await _getClient();
    final uri = Uri.parse('$baseUrl/order/$orderId/qr');
    final stopwatch = Stopwatch()..start();
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final remaining = totalBudget - stopwatch.elapsed;
      if (remaining <= Duration.zero) break;
      final timeout =
          remaining < perAttemptTimeout ? remaining : perAttemptTimeout;

      try {
        final res = await client.get(uri).timeout(timeout);

        if (res.statusCode == 200) {
          final bytes = res.bodyBytes;
          // 200인데 PNG가 아닌 내용(에러 페이지 등)이 오면 PDF 생성 자체가
          // 실패해서 영수증이 통째로 안 나오므로, 여기서 미리 걸러냅니다.
          if (!_isPng(bytes)) {
            throw Exception(
              'QR 응답이 PNG 이미지가 아닙니다 '
              '(${bytes.length} bytes, content-type: ${res.headers['content-type']})',
            );
          }
          print('>>> [QR] 조회 성공 — $attempt번째 시도, '
              '${stopwatch.elapsedMilliseconds}ms, ${bytes.length} bytes');
          return bytes;
        }

        final retryable = res.statusCode == 404 ||
            res.statusCode == 429 ||
            res.statusCode >= 500;
        lastError = Exception('QR 코드 조회 실패 (${res.statusCode})');
        print('>>> [QR] 응답 ${res.statusCode} — $attempt/$maxAttempts번째 시도');
        if (!retryable) break;
      } on TimeoutException {
        lastError = TimeoutException(
          'QR 응답 없음 (${timeout.inMilliseconds}ms 초과)',
        );
        print('>>> [QR] 응답 없음(타임아웃) — $attempt/$maxAttempts번째 시도');
      } on http.ClientException catch (e) {
        lastError = e;
        print('>>> [QR] 네트워크 연결 실패 — $attempt/$maxAttempts번째 시도: $e');
      }

      // 다음 시도 전 잠깐 대기 (1초, 2초 ...)
      if (attempt < maxAttempts) {
        final wait = Duration(seconds: attempt);
        if (stopwatch.elapsed + wait >= totalBudget) break;
        await Future.delayed(wait);
      }
    }

    throw lastError ?? TimeoutException('QR 조회 시간 초과');
  }

  static bool _isPng(Uint8List bytes) {
    const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  /// GET /queue/status — 대기열 현황 조회.
  ///
  /// 응답 예시:
  ///   {
  ///     "full": false,          // 대기열이 가득 찼는지 — 이 값만 보면 됨
  ///     "max_queue_len": 3,     // 대기열 최대 길이
  ///     "queue_length": 2,      // 현재 대기 중인 주문 수
  ///     "orders": [             // 대기 중인 주문 목록
  ///       {
  ///         "order_id": "ord_a1b2c3d4",
  ///         "order_seq": 7,
  ///         "position": 1,
  ///         "board": "blue",
  ///         "keycap": "ENTP",
  ///         "colors": ["b", "b", "r", "g"],
  ///         "blocked_by": [["P_b", "count_0"]]
  ///       }
  ///     ]
  ///   }
  ///
  /// [주의] queue_length < max_queue_len 이어도 서버 쪽 사정(부품 부족 등)으로
  /// full이 true일 수 있으므로, 길이를 직접 비교하지 말고 full을 그대로 쓰세요.
  Future<Map<String, dynamic>> getQueueStatus() async {
    final client = await _getClient();
    final res = await client
        .get(Uri.parse('$baseUrl/queue/status'))
        // [신규] 키오스크가 오류 처리 도중 멈춰 서지 않도록 짧은 타임아웃을 둡니다.
        .timeout(const Duration(seconds: 5));
    // [수정] 한글 에러 메시지가 깨지지 않도록 utf8로 직접 디코딩합니다.
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? '대기열 조회 실패 (${res.statusCode})');
    }
    return body;
  }

  /// [신규] "대기열이 가득 찼는가"만 알면 되는 곳에서 쓰는 헬퍼.
  /// 위 응답의 full 값 하나만 봅니다.
  ///
  /// 반환값:
  ///   true  — 가득 참
  ///   false — 여유 있음
  ///   null  — 판단 보류. 조회 자체가 실패했거나(네트워크/타임아웃/형식 오류)
  ///           응답에 full이 없거나 bool이 아닌 경우입니다. 호출하는 쪽에서
  ///           어떻게 처리할지(폴백) 정하세요.
  Future<bool?> isQueueFull() async {
    try {
      final body = await getQueueStatus();
      final full = body['full'];
      return full is bool ? full : null;
    } catch (e) {
      print('>>> [대기열] 조회 실패: $e');
      return null;
    }
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
