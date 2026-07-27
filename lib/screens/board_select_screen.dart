import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BoardSelectScreen extends StatelessWidget {
  const BoardSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('STEP 04 / 06', style: AppTextStyles.label),
        const SizedBox(height: 8),
        const Text('판 크기 선택', style: AppTextStyles.heading),
        const SizedBox(height: 8),
        const Text('키보드 1 또는 2 를 눌러 선택하세요', style: AppTextStyles.body),
        const SizedBox(height: 48),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _BoardOption(
              accent: AppColors.yellow,
              keyLabel: '1',
              title: '1 × 4',
              subtitle: '가로형 4칸',
              rows: 1,
              cols: 4,
            ),
            SizedBox(width: 56),
            _BoardOption(
              accent: AppColors.coral,
              keyLabel: '2',
              title: '2 × 2',
              subtitle: '정방형 4칸',
              rows: 2,
              cols: 2,
            ),
          ],
        ),
      ],
    );
  }
}

class _BoardOption extends StatelessWidget {
  final Color accent;
  final String keyLabel;
  final String title;
  final String subtitle;
  final int rows;
  final int cols;

  const _BoardOption({
    required this.accent,
    required this.keyLabel,
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.cols,
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
              child: _GridPreview(rows: rows, cols: cols),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
          child: Text(keyLabel, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        Text(subtitle, style: AppTextStyles.body),
      ],
    );
  }
}

class _GridPreview extends StatelessWidget {
  final int rows;
  final int cols;
  const _GridPreview({required this.rows, required this.cols});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        rows,
        (r) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              cols,
              (c) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.tileEmpty, border: Border.all(color: AppColors.muted)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}