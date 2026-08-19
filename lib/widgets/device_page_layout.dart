import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 인증 완료·조립 중 화면 공통 레이아웃
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 90, 40, 40),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gray,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 64,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 100),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
