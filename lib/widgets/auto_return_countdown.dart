import 'dart:async';

import 'package:flutter/widgets.dart';

import '../debug/app_log.dart';

/// 오류·완료 화면 공통: [countdownSeconds]초 카운트다운 후 자동 복귀.
///
/// ```dart
/// class _FooState extends State<Foo> with AutoReturnCountdown<Foo> {
///   @override
///   int get countdownSeconds => 7;
///
///   @override
///   void onCountdownFinished() => widget.onAutoReturn();
/// }
/// ```
///
/// - 화면이 뜨면(initState) 바로 1초 간격으로 [secondsLeft]를 줄인다.
/// - 0이 되면 [onCountdownFinished]를 한 번 호출한다.
/// - 버튼 등으로 먼저 화면이 바뀌면 dispose에서 타이머가 정리된다.
mixin AutoReturnCountdown<T extends StatefulWidget> on State<T> {
  /// 자동 복귀까지 걸리는 시간(초)
  int get countdownSeconds;

  /// 카운트다운이 끝났을 때 호출된다.
  void onCountdownFinished();

  /// 화면에 표시할 남은 시간(초)
  late int secondsLeft = countdownSeconds;

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        secondsLeft--;
      });

      if (secondsLeft <= 0) {
        timer.cancel();

        AppLog.d(
          LogTag.screen,
          '[${widget.runtimeType}] $countdownSeconds초 경과 → 자동 복귀',
        );

        onCountdownFinished();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
