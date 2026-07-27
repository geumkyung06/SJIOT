import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MbtiChoiceScreen extends StatelessWidget {
  const MbtiChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('STEP 01 / 07', style: AppTextStyles.label),
        const SizedBox(height: 8),
        const Text('MBTI를 알고 계신가요?', style: AppTextStyles.heading),
        const SizedBox(height: 8),
        const Text('키보드 1 또는 2 를 눌러 선택하세요', style: AppTextStyles.body),
        const SizedBox(height: 48),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _ChoiceOption(
              accent: AppColors.yellow,
              keyLabel: '1',
              title: 'MBTI 몰라요',
              subtitle: '간단한 질문으로 찾아드릴게요',
            ),
            SizedBox(width: 56),
            _ChoiceOption(
              accent: AppColors.coral,
              keyLabel: '2',
              title: 'MBTI 알아요',
              subtitle: '직접 입력할게요',
            ),
          ],
        ),
      ],
    );
  }
}

class _ChoiceOption extends StatelessWidget {
  final Color accent;
  final String keyLabel;
  final String title;
  final String subtitle;

  const _ChoiceOption({
    required this.accent,
    required this.keyLabel,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Positioned(
              left: -8,
              top: -8,
              child: Container(width: 260, height: 150, color: accent),
            ),
            Container(
              width: 260,
              height: 150,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.ink, width: 2)),
              child: Text(
                keyLabel,
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: AppColors.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTextStyles.body),
      ],
    );
  }
}