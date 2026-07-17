import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class KeycapFillScreen extends StatelessWidget {
  final String boardShape; // '1x4' | '2x2'
  final List<String> letters;
  final int cursor;
  final Color Function(int index) colorAt;

  const KeycapFillScreen({
    super.key,
    required this.boardShape,
    required this.letters,
    required this.cursor,
    required this.colorAt,
  });

  @override
  Widget build(BuildContext context) {
    final filled = letters.where((l) => l.isNotEmpty).length;
    final complete = filled == letters.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('STEP 02 / 03', style: AppTextStyles.label),
        const SizedBox(height: 8),
        const Text('키를 눌러 채우세요', style: AppTextStyles.heading),
        const SizedBox(height: 8),
        const Text(
          '알파벳 키 → 글자 입력  ·  화살표 → 이동  ·  TAB → 색상 변경  ·  ENTER로 완료',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 40),
        Stack(
          children: [
            Positioned(left: -8, top: -8, child: Container(width: 460, height: 180, color: AppColors.yellow)),
            Container(
              width: 460,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.ink, width: 2)),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: List.generate(letters.length, (i) {
                  final isCursor = i == cursor;
                  return Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorAt(i),
                      border: Border.all(color: isCursor ? AppColors.ink : Colors.transparent, width: 3),
                    ),
                    child: Text(
                      letters[i],
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('채움', style: AppTextStyles.body),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(
                    letters.length,
                    (i) => Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: 18,
                      height: 18,
                      color: letters[i].isNotEmpty ? colorAt(i) : AppColors.tileEmpty,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('$filled / ${letters.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(width: 48),
            const _ArrowKeys(),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          width: 460,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          color: complete ? AppColors.ink : AppColors.muted,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Colors.white,
                child: const Text('ENTER', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Text(
                '제작 시작',
                style: TextStyle(color: complete ? AppColors.green : Colors.white70, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArrowKeys extends StatelessWidget {
  const _ArrowKeys();

  @override
  Widget build(BuildContext context) {
    Widget key(IconData icon) => Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
          child: Icon(icon, size: 18),
        );
    return Column(
      children: [
        key(Icons.arrow_upward),
        Row(children: [key(Icons.arrow_back), key(Icons.arrow_downward), key(Icons.arrow_forward)]),
      ],
    );
  }
}