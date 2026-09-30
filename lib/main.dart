import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'debug/app_log.dart';
import 'device_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  _installErrorHandlers();

  final String mode = kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug';

  AppLog.i(LogTag.app, '앱 시작 (mode=$mode, debugLog=${AppLog.enabled})');

  runApp(const DeviceApp());
}

/// 처리되지 않은 예외를 [ERROR] 태그로 터미널에 남긴다.
///
/// - FlutterError.onError: build · layout · 버튼 콜백 안에서 난 오류
///   (예: `_order!`가 null인 채로 화면을 그릴 때)
/// - PlatformDispatcher.onError: Timer 콜백 · async 함수 등
///   프레임워크 밖에서 잡히지 않은 오류
void _installErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLog.e(
      LogTag.error,
      '프레임워크 오류: ${details.exceptionAsString()}'
      '${details.context == null ? '' : ' (${details.context})'}',
      // 디버그 모드에서는 아래 presentError가 위젯 위치까지 포함한
      // 전체 리포트를 출력하므로 스택은 생략한다.
      stack: kDebugMode ? null : details.stack,
    );

    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLog.e(LogTag.error, '처리되지 않은 비동기 오류: $error', stack: stack);

    // true: 처리했음으로 보고 앱을 계속 실행한다.
    return true;
  };
}
