import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MbtiManualScreen extends StatelessWidget {
  final int questionIndex; // 0~3
  final int totalQuestions;
  final String letterA;
  final String letterB;

  final bool letterASoldOut;
  final bool letterBSoldOut;

  const MbtiManualScreen({
    super.key,
    required this.questionIndex,
    required this.totalQuestions,
    required this.letterA,
    required this.letterB,
    required this.letterASoldOut,
    required this.letterBSoldOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('STEP 02 / 07  ·  질문 ${questionIndex + 1} / $totalQuestions',
            style: AppTextStyles.label),
        const SizedBox(height: 8),
        const Text('MBTI를 직접 입력하세요', style: AppTextStyles.heading),
        const SizedBox(height: 8),
        const Text('키보드에서 해당하는 알파벳을 눌러주세요', style: AppTextStyles.body),
        const SizedBox(height: 48),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LetterBadge(
              letter: letterA,
              soldOut: letterASoldOut,
            ),
            const SizedBox(width: 20),
            const Text('입니까?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(width: 40),
            _LetterBadge(
              letter: letterB,
              soldOut: letterBSoldOut,
            ),
            const SizedBox(width: 20),
            const Text('입니까?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            totalQuestions,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 14,
              height: 14,
              color: i <= questionIndex ? AppColors.green : AppColors.tileEmpty,
            ),
          ),
        ),
      ],
    );
  }
}

class _LetterBadge extends StatelessWidget {
  final String letter;
  final bool soldOut;

  const _LetterBadge({required this.letter, required this.soldOut});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: AppColors.ink,
              width: 3,
            ),
          ),
          child: Text(
            letter,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (soldOut)
          const Text(
            '재고없음',
            style: TextStyle(
              color: Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          )
        else
          const SizedBox(height: 16),
      ],
    );
  }
}
