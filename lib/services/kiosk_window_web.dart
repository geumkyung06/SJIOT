// [신규] 웹(Chrome) 빌드 전용 창 제어 stub.
//
// 브라우저에서는 앱이 창 크기 / 전체화면 / 최상단 고정 / 창 종료를
// 제어할 수 없으므로 전부 no-op 입니다.
// (전체화면이 필요하면 브라우저의 F11 을 사용하세요.)
Future<void> initKioskWindow({required bool kioskMode}) async {
  // 웹에서는 아무것도 하지 않습니다.
}

Future<void> closeKioskWindow() async {
  // 웹에서는 앱이 스스로 창을 닫을 수 없습니다.
}
