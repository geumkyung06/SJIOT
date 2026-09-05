// [신규] 웹(Chrome) 빌드 전용 HTTP 클라이언트.
//
// 브라우저는 TLS 인증서 검증을 자체적으로 처리하므로 커스텀 루트 인증서를
// 신뢰 목록에 추가하는 로직이 필요 없고, 애초에 dart:io / SecurityContext /
// HttpClient / IOClient 는 웹에 존재하지 않습니다.
// 따라서 여기서는 기본 클라이언트만 돌려줍니다.
//
// 주의: 웹에서는 브라우저 CORS 정책이 적용되므로, 백엔드(Flask)에서
// Access-Control-Allow-Origin / Allow-Headers(Content-Type, Idempotency-Key)를
// 허용해줘야 API 호출이 성공합니다.
import 'package:http/http.dart' as http;

Future<http.Client> createHttpClient() async {
  return http.Client();
}
