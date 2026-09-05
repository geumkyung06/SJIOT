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
    size: const Size(1920, 1080), // 키오스크 실제 해상도에 맞춰 조정하세요.
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

/// 좌측 상단 5회 터치 + PIN 입력으로 앱을 종료할 때 호출됩니다.
Future<void> closeKioskWindow() async {
  await windowManager.close();
}
