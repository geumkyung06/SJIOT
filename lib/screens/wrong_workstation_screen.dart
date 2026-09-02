import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/error_badge.dart';
import '../widgets/screen_canvas.dart';

class WrongWorkstationScreen extends StatefulWidget {
  final String currentWorkstation;
  final String assignedWorkstation;
  final VoidCallback onAutoReturn;

  const WrongWorkstationScreen({
    super.key,
    required this.currentWorkstation,
    required this.assignedWorkstation,
    required this.onAutoReturn,
  });

  @override
  State<WrongWorkstationScreen> createState() => _WrongWorkstationScreenState();
}

class _WrongWorkstationScreenState extends State<WrongWorkstationScreen> {
  int secondsLeft = 7;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  Future<void> _startCountdown() async {
    while (secondsLeft > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      setState(() {
        secondsLeft--;
      });
    }

    if (mounted) {
      widget.onAutoReturn();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenCanvas.column(
      children: [
        const ErrorBadge(),

        const SizedBox(height: 26),

        const Text(
          '잘못된 조립대입니다',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 68,
            height: 1.12,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
          ),
        ),

        const SizedBox(height: 24),

        const Text(
          '이 QR 코드는 다른 조립대에 배정되어 있습니다.\n'
          '배정된 조립대로 이동한 후 다시 스캔하세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            height: 1.65,
            color: AppColors.textSub,
          ),
        ),

        const SizedBox(height: 44),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            WorkstationBox(
              label: '현재 위치',
              number: widget.currentWorkstation,
              accentColor: AppColors.pink,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 35),
              child: Padding(
                padding: EdgeInsets.only(top: 30),
                child: Icon(
                  Icons.arrow_forward,
                  size: 34,
                  color: AppColors.textSub,
                ),
              ),
            ),

            WorkstationBox(
              label: '배정된 조립대',
              number: widget.assignedWorkstation,
              accentColor: AppColors.green,
            ),
          ],
        ),

        const SizedBox(height: 36),

        Text(
          '$secondsLeft초 후 대기 화면으로 돌아갑니다.',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textSub,
          ),
        ),

        const SizedBox(height: 16),

        const ErrorCodeChip('ERR_WS_MISMATCH'),
      ],
    );
  }
}

class WorkstationBox extends StatelessWidget {
  final String label;
  final String number;
  final Color accentColor;

  const WorkstationBox({
    super.key,
    required this.label,
    required this.number,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppColors.textSub,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 140,
          height: 140,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}
