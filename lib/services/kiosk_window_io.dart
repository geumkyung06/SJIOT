// [신규] 데스크톱(Windows/macOS/Linux) 빌드 전용 키오스크 창 설정.
// 기존 main.dart 의 main() 안에 있던 window_manager 코드를 그대로 옮긴 것이며
// 동작은 이전과 100% 동일합니다.
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// 창을 항상 지정 해상도로 전체화면 표시하고, 뜨는 즉시 강제로 포커스를 줘서
/// 마우스/터치 입력이 다른 창에 뺏기지 않게 합니다. 키오스크 터치 문제
/// 원인 파악용 조치이며, 원인이 확인되면(오버레이 프로그램 등) 정리해도 됩니다.
Future<void> initKioskWindow({required bool kioskMode}) async {
  await windowManager.ensureInitialized();

  final windowOptions = WindowOptions(
    // [세로 전환] 세로 키오스크(2160 x 3840)에 맞춘 9:16 창.
    // kioskMode가 true면 어차피 전체화면이라 이 값은 창모드에서만 쓰입니다.
    // 노트북에서 창모드로 테스트할 땐 Size(540, 960)처럼 줄여서 쓰세요.
    size: const Size(1080, 1920),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: kioskMode ? TitleBarStyle.hidden : TitleBarStyle.normal,
    fullScreen: kioskMode,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    // 다른 창(사이니지 오버레이 등)이 위로 올라오지 못하게 최상단 고정.
    // 개발 중엔 VS Code/터미널을 가리므로 kioskMode일 때만 켭니다.
    if (kioskMode) {
      await windowManager.setAlwaysOnTop(true);
    }
  });
}

/// 하단 사업단 로고 7회 터치(5초 이내) + PIN 입력으로 앱을 종료할 때 호출됩니다.
Future<void> closeKioskWindow() async {
  await windowManager.close();
}
