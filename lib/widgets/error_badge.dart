import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 오류 배지 — 빨강 대신 분홍 키캡색, 몇 초마다 짧게 흔들립니다.
class ErrorBadge extends StatefulWidget {
  const ErrorBadge({super.key, this.text = '오류'});

  final String text;

  @override
  State<ErrorBadge> createState() => _ErrorBadgeState();
}

class _ErrorBadgeState extends State<ErrorBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 주기의 마지막 14% 구간에서만 좌우로 흔듭니다.
  double _offset(double t) {
    if (t < 0.86) return 0;
    final p = (t - 0.86) / 0.14;
    return sin(p * pi * 3) * 7 * (1 - p);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offset(_controller.value), 0),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.pink,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          widget.text,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            height: 1,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

/// 에러 코드 칩 — 흰 배경 + 모노스페이스
class ErrorCodeChip extends StatelessWidget {
  const ErrorCodeChip(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontSize: 20,
          height: 1,
          fontFamily: 'monospace',
          color: AppColors.textSub,
        ),
      ),
    );
  }
}
