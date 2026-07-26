import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AxisSelectScreen extends StatelessWidget {
  final Set<String> soldOutAxes;

  const AxisSelectScreen({
    super.key,
    required this.soldOutAxes,
  });

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
          children: [
            _AxisOption(
              keyLabel: '1',
              color: Color(0xFF3E7CE0),
              title: '청축',
              soldOut: soldOutAxes.contains('blue'),
            ),
            _AxisOption(
              keyLabel: '2',
              color: Color(0xFF9C6B3F),
              title: '갈축',
              soldOut: soldOutAxes.contains('brown'),
            ),
            _AxisOption(
              keyLabel: '3',
              color: Color(0xFFD5473C),
              title: '적축',
              soldOut: soldOutAxes.contains('red'),
            ),
            _AxisOption(
              keyLabel: '4',
              color: Color(0xFF2B2B2B),
              title: '흑축',
              soldOut: soldOutAxes.contains('black'),
            ),
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
  final bool soldOut;

  const _AxisOption(
      {required this.keyLabel,
      required this.color,
      required this.title,
      required this.soldOut});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: soldOut ? Colors.grey.shade400 : color,
            border: Border.all(
              color: soldOut ? Colors.grey.shade600 : AppColors.ink,
              width: 2,
            ),
          ),
          child: Text(
            soldOut ? '재고없음' : keyLabel,
            style: TextStyle(
              fontSize: soldOut ? 17 : 40,
              fontWeight: FontWeight.w900,
              color: soldOut ? Colors.grey.shade800 : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: soldOut ? Colors.grey : AppColors.ink,
            )),
      ],
    );
  }
}
