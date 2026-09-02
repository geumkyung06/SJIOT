import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 모든 화면 위에 항상 떠 있는 로고 바.
///
/// 왼쪽 로고를 [_secretTapWindow] 안에 [_secretTapCount]번 누르면
/// [onSecretTap]이 호출된다. (관리자 종료 진입)
class AppTopBar extends StatefulWidget {
  final VoidCallback onSecretTap;

  const AppTopBar({super.key, required this.onSecretTap});

  /// 바 높이 — 아래 화면 영역 계산에 쓴다.
  static const double height = 75;

  @override
  State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar> {
  /// 2초 안에 7번
  static const int _secretTapCount = 7;
  static const Duration _secretTapWindow = Duration(seconds: 2);

  final List<DateTime> _tapTimes = [];

  void _handleLogoTap() {
    final DateTime now = DateTime.now();

    _tapTimes.add(now);

    // 2초보다 오래된 탭은 버린다.
    _tapTimes.removeWhere((t) => now.difference(t) > _secretTapWindow);

    if (_tapTimes.length >= _secretTapCount) {
      _tapTimes.clear();

      widget.onSecretTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppTopBar.height,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 왼쪽: 사업단 로고 (숨은 종료 버튼)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleLogoTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Image.asset(
                'assets/images/logo_iotcoss.png',
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 오른쪽: 학교 심볼
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Image.asset(
              'assets/images/logo_sejong.png',
              height: 44,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
