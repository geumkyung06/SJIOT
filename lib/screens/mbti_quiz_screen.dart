import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MbtiQuizScreen extends StatelessWidget {
  final int questionIndex; // 0~3
  final int totalQuestions;
  final String question;
  final List<String> optionTexts; // 4개

  const MbtiQuizScreen({
    super.key,
    required this.questionIndex,
    required this.totalQuestions,
    required this.question,
    required this.optionTexts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('STEP 02 / 07  ·  질문 ${questionIndex + 1} / $totalQuestions', style: AppTextStyles.label),
        const SizedBox(height: 12),
        SizedBox(
          width: 560,
          child: Text(question, textAlign: TextAlign.center, style: AppTextStyles.heading),
        ),
        const SizedBox(height: 8),
        const Text('숫자 1~4 를 눌러 선택하세요', style: AppTextStyles.body),
        const SizedBox(height: 32),
        Column(
          children: List.generate(optionTexts.length, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                width: 560,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      color: AppColors.ink,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(optionTexts[i], style: AppTextStyles.body)),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
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