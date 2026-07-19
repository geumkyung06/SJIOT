import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AxisSelectScreen extends StatelessWidget {
  const AxisSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('STEP 05 / 07', style: AppTextStyles.label),
        const SizedBox(height: 8),
        const Text('축(스위치) 선택', style: AppTextStyles.heading),
        const SizedBox(height: 8),
        const Text('키보드 1~4 를 눌러 선택하세요', style: AppTextStyles.body),
        const SizedBox(height: 40),
        Wrap(
          spacing: 32,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          children: const [
            _AxisOption(keyLabel: '1', color: Color(0xFF3E7CE0), title: '청축'),
            _AxisOption(keyLabel: '2', color: Color(0xFF9C6B3F), title: '갈축'),
            _AxisOption(keyLabel: '3', color: Color(0xFFD5473C), title: '적축'),
            _AxisOption(keyLabel: '4', color: Color(0xFF2B2B2B), title: '흑축'),
          ],
        ),
      ],
    );
  }
}

class _AxisOption extends StatelessWidget {
  final String keyLabel;
  final Color color;
  final String title;

  const _AxisOption({required this.keyLabel, required this.color, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, border: Border.all(color: AppColors.ink, width: 2)),
          child: Text(
            keyLabel,
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }
}