import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MbtiResultScreen extends StatelessWidget {
  final String mbti;

  const MbtiResultScreen({super.key, required this.mbti});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('STEP 03 / 07', style: AppTextStyles.label),
        const SizedBox(height: 8),
        const Text('당신의 MBTI는', style: AppTextStyles.body),
        const SizedBox(height: 24),
        Stack(
          children: [
            Positioned(left: -8, top: -8, child: Container(width: 320, height: 140, color: AppColors.yellow)),
            Container(
              width: 320,
              height: 140,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.ink, width: 3)),
              child: Text(
                mbti,
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                  letterSpacing: 4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.muted,
                child: const Text('ENTER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              const Text('다음으로', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ],
    );
  }
}