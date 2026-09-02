import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 인증 완료 화면 공통 레이아웃
class DevicePageLayout extends StatelessWidget {
  final String label;
  final String title;
  final List<Widget> children;

  static const double designWidth = 1340;
  static const double designHeight = 800;

  const DevicePageLayout({
    super.key,
    required this.label,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: designWidth,
          height: designHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(64, 110, 64, 60),
            child: SingleChildScrollView(
              child: Column(
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
                  const SizedBox(height: 44),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
