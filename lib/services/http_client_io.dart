// [신규] 데스크톱/모바일(dart:io 가 있는 플랫폼) 전용 HTTP 클라이언트.
// 기존 api_service.dart 의 _getClient() 안에 있던 로직을 그대로 옮긴 것이며
// 동작은 이전과 100% 동일합니다.
//
// 학교/전시장 네트워크(또는 이 PC에 걸린 프록시)의 SSL 검사 장비가 발급한
// 루트 인증서를 신뢰 목록에 "추가"해서 HandshakeException
// (CERTIFICATE_VERIFY_FAILED)을 해결하기 위한 커스텀 클라이언트입니다.
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
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;

Future<http.Client> createHttpClient() async {
  try {
    final certData = await rootBundle.load(
      'assets/certs/custom_root.pem',
    );
    final context = SecurityContext(withTrustedRoots: true);
    context.setTrustedCertificatesBytes(
      certData.buffer.asUint8List(),
    );
    final httpClient = HttpClient(context: context);
    // ignore: avoid_print
    print('>>> [DEBUG] 커스텀 인증서 로드 성공, 신뢰 목록에 추가됨');
    return http_io.IOClient(httpClient);
  } catch (e) {
    // ignore: avoid_print
    print('>>> [DEBUG] 커스텀 인증서 로드 실패, 기본 클라이언트 사용: $e');
    return http.Client();
  }
}
