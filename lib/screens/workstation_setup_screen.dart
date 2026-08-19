import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class WorkstationSetupScreen extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const WorkstationSetupScreen({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '초기 설정',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.gray,
                letterSpacing: 4,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              '조립대 번호',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 64,
                height: 1.15,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              '선택한 번호는 앱을 종료하기 전까지 유지됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, color: AppColors.gray),
            ),

            const SizedBox(height: 52),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                WorkstationSelectButton(
                  number: '01',
                  onPressed: () => onSelected('01'),
                ),
                const SizedBox(width: 20),
                WorkstationSelectButton(
                  number: '02',
                  onPressed: () => onSelected('02'),
                ),
                const SizedBox(width: 20),
                WorkstationSelectButton(
                  number: '03',
                  onPressed: () => onSelected('03'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WorkstationSelectButton extends StatelessWidget {
  final String number;
  final VoidCallback onPressed;

  const WorkstationSelectButton({
    super.key,
    required this.number,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 150,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.black,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.black, width: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '조립대',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.gray,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              number,
              style: const TextStyle(
                fontSize: 52,
                height: 1,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
