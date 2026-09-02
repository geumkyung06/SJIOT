import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'screen_canvas.dart';

/// 라벨 + 큰 제목 + 내용으로 이어지는 공통 화면 레이아웃
class DevicePageLayout extends StatelessWidget {
  final String label;
  final String title;
  final List<Widget> children;

  const DevicePageLayout({
    super.key,
    required this.label,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ScreenCanvas.column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: AppColors.textSub,
            letterSpacing: 5,
          ),
        ),

        const SizedBox(height: 16),

        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 68,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
          ),
        ),

        const SizedBox(height: 40),

        ...children,
      ],
    );
  }
}
