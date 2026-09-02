import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 안드로이드 화면 고정(lock task) 제어.
///
/// 고정 중에는 홈·최근앱 버튼이 동작하지 않아 앱 밖으로 나갈 수 없고,
/// 관리자 비밀번호를 통과했을 때만 [stop]으로 풀고 종료한다.
/// 안드로이드가 아니면 모두 무시한다.
class KioskService {
  static const MethodChannel _channel = MethodChannel('device_app/kiosk');

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// 화면 고정 시작. 기기 소유자로 등록돼 있지 않으면
  /// 시스템이 확인 창을 한 번 띄운다.
  static Future<bool> start() async {
    if (!_supported) return false;

    try {
      final bool? ok = await _channel.invokeMethod<bool>('startLockTask');

      debugPrint('화면 고정 시작: $ok');

      return ok ?? false;
    } catch (e) {
      debugPrint('화면 고정 실패: $e');

      return false;
    }
  }

  /// 화면 고정 해제.
  static Future<bool> stop() async {
    if (!_supported) return false;

    try {
      final bool? ok = await _channel.invokeMethod<bool>('stopLockTask');

      debugPrint('화면 고정 해제: $ok');

      return ok ?? false;
    } catch (e) {
      debugPrint('화면 고정 해제 실패: $e');

      return false;
    }
  }

  /// 지금 고정 상태인지.
  static Future<bool> isLocked() async {
    if (!_supported) return false;

    try {
      return await _channel.invokeMethod<bool>('isLocked') ?? false;
    } catch (e) {
      debugPrint('화면 고정 상태 조회 실패: $e');

      return false;
    }
  }
}
