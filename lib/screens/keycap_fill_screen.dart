import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class KeycapFillScreen extends StatelessWidget {
  final String boardShape; // '1x4' | '2x2'
  final List<String> letters; // 이미 MBTI 결과로 채워진 상태 (수정 불가)
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
    final filled = letters.asMap().entries.where((e) => colorAt(e.key) != AppColors.tileEmpty).length;
    final complete = filled == letters.length;
    final cols = boardShape == '2x2' ? 2 : 4;
    final rows = boardShape == '2x2' ? 2 : 1;
    final boardWidth = cols == 4 ? 460.0 : 260.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('STEP 06 / 07', style: AppTextStyles.label),
        const SizedBox(height: 8),
        const Text('키캡 색을 선택하세요', style: AppTextStyles.heading),
        const SizedBox(height: 8),
        const Text(
          '숫자 1~4 → 색상 선택(자동으로 다음 칸 이동)  ·  화살표 → 이동  ·  ENTER로 제작',
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Stack(
          children: [
            Positioned(
              left: -8,
              top: -8,
              child: Container(width: boardWidth, height: rows == 2 ? boardWidth : 150, color: AppColors.yellow),
            ),
            Container(
              width: boardWidth,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.ink, width: 2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(rows, (r) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(cols, (c) {
                        final i = r * cols + c;
                        final isCursor = i == cursor;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
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
                          ),
                        );
                      }),
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
                const Text('색상 선택', style: AppTextStyles.body),
                const SizedBox(height: 8),
                _legendRow('1', KeycapColors.green, '초록'),
                _legendRow('2', KeycapColors.yellow, '노랑'),
                _legendRow('3', KeycapColors.blue, '파랑'),
                _legendRow('4', KeycapColors.red, '빨강'),
                const SizedBox(height: 8),
                Text('$filled / ${letters.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(width: 48),
            const _ArrowKeys(),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          width: boardWidth,
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
                complete ? '엔터! 제작!' : '색을 모두 선택하세요',
                style: TextStyle(color: complete ? AppColors.green : Colors.white70, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendRow(String num, Color color, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
            child: Text(num, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          Container(width: 18, height: 18, color: color),
          const SizedBox(width: 8),
          Text(name, style: AppTextStyles.body),
        ],
      ),
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