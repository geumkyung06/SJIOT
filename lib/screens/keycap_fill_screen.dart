import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class KeycapFillScreen extends StatelessWidget {
  final String boardShape; // '1x4' | '2x2'
  final List<String> letters; // 이미 MBTI 결과로 채워진 상태 (수정 불가)
  final int cursor;
  final Color Function(int index) colorAt;

  final Set<String> soldOutColors;
  final String? message;
  final bool stockLoading;

  const KeycapFillScreen({
    super.key,
    required this.boardShape,
    required this.letters,
    required this.cursor,
    required this.colorAt,
    required this.soldOutColors,
    this.message,
    required this.stockLoading,
  });

  @override
  Widget build(BuildContext context) {
    final filled = letters
        .asMap()
        .entries
        .where((e) => colorAt(e.key) != AppColors.tileEmpty)
        .length;
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
              child: Container(
                  width: boardWidth,
                  height: rows == 2 ? boardWidth : 150,
                  color: AppColors.yellow),
            ),
            Container(
              width: boardWidth,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.ink, width: 2)),
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
                              border: Border.all(
                                  color: isCursor
                                      ? AppColors.ink
                                      : Colors.transparent,
                                  width: 3),
                            ),
                            child: Text(
                              letters[i],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900),
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
                _legendRow('1', 'g', KeycapColors.green, '초록'),
                _legendRow('2', 'y', KeycapColors.yellow, '노랑'),
                _legendRow('3', 'b', KeycapColors.blue, '파랑'),
                _legendRow('4', 'r', KeycapColors.red, '빨강'),
                const SizedBox(height: 8),
                Text('$filled / ${letters.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(width: 48),
            const _ArrowKeys(),
          ],
        ),
        if (stockLoading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              '재고 확인 중...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          )
        else if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Colors.white,
                child: const Text('ENTER',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Text(
                complete ? '엔터! 제작!' : '색을 모두 선택하세요',
                style: TextStyle(
                    color: complete ? AppColors.green : Colors.white70,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendRow(
    String num,
    String colorCode,
    Color color,
    String name,
  ) {
    final isSoldOut = soldOutColors.contains(colorCode);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // 번호 칸은 항상 같은 크기 유지
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSoldOut ? Colors.grey.shade300 : Colors.transparent,
              border: Border.all(
                color: isSoldOut ? Colors.grey.shade500 : AppColors.ink,
                width: 2,
              ),
            ),
            child: Text(
              num,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isSoldOut ? Colors.grey.shade600 : AppColors.ink,
              ),
            ),
          ),

          const SizedBox(width: 14),

          // 색상 표시
          Container(
            width: 36,
            height: 36,
            color: isSoldOut ? Colors.grey.shade400 : color,
          ),

          const SizedBox(width: 14),

          // 색상 이름
          SizedBox(
            width: 70,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: isSoldOut ? Colors.grey.shade600 : AppColors.ink,
              ),
            ),
          ),

          // 품절 표시
          if (isSoldOut)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '재고 없음',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
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
          decoration:
              BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
          child: Icon(icon, size: 18),
        );
    return Column(
      children: [
        key(Icons.arrow_upward),
        Row(children: [
          key(Icons.arrow_back),
          key(Icons.arrow_downward),
          key(Icons.arrow_forward)
        ]),
      ],
    );
  }
}
