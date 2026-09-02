import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/conveyor_belt.dart';
import '../widgets/screen_canvas.dart';

// 대기 중 화면
class WaitingScreen extends StatefulWidget {
  final String workstationNumber;
  final VoidCallback onCountdownFinished;

  const WaitingScreen({
    super.key,
    required this.workstationNumber,
    required this.onCountdownFinished,
  });

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  static const int _waitingSeconds = 7;

  Timer? _countdownTimer;
  int _secondsLeft = _waitingSeconds;

  @override
  void initState() {
    super.initState();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsLeft <= 1) {
        timer.cancel();
        widget.onCountdownFinished();
        return;
      }

      setState(() {
        _secondsLeft--;
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenCanvas.column(
      children: [
        Container(
          width: 620,
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 30),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const ConveyorBelt(),
        ),

        const SizedBox(height: 34),

        Text(
          '조립대 ${widget.workstationNumber}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 76,
            height: 1,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
          ),
        ),

        const SizedBox(height: 24),

        const Text(
          '인증이 완료되었습니다.\n'
          '로봇이 부품을 내려놓기 전까지 기다려 주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 23,
            height: 1.6,
            color: AppColors.textSub,
          ),
        ),

        const SizedBox(height: 36),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$_secondsLeft초 후 조립 화면으로 이동합니다.',
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              height: 1,
              color: AppColors.textSub,
            ),
          ),
        ),
      ],
    );
  }
}
