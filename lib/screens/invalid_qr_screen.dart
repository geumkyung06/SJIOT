import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_buttons.dart';
import '../widgets/auto_return_countdown.dart';
import '../widgets/error_badge.dart';
import '../widgets/screen_canvas.dart';

class InvalidQrScreen extends StatefulWidget {
  final VoidCallback onRetry;
  final VoidCallback onCallStaff;

  const InvalidQrScreen({
    super.key,
    required this.onRetry,
    required this.onCallStaff,
  });

  @override
  State<InvalidQrScreen> createState() => _InvalidQrScreenState();
}

class _InvalidQrScreenState extends State<InvalidQrScreen>
    with AutoReturnCountdown<InvalidQrScreen> {
  @override
  int get countdownSeconds => 7;

  @override
  void onCountdownFinished() => widget.onRetry();

  @override
  Widget build(BuildContext context) {
    return ScreenCanvas.column(
      children: [
        const ErrorBadge(),

        const SizedBox(height: 26),

        const Text(
          '인식할 수 없는 QR 코드',
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
          '스캔한 QR 코드를 인식하지 못했습니다.\n'
          '영수증에 인쇄된 QR 코드를 사용하고 있는지 확인하세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            height: 1.65,
            color: AppColors.textSub,
          ),
        ),

        const SizedBox(height: 48),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 330,
              height: 96,
              child: PrimaryButton(
                text: '다시 시도',
                onPressed: widget.onRetry,
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              width: 330,
              height: 96,
              child: OutlineButton(
                text: '직원 호출',
                onPressed: widget.onCallStaff,
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        Text(
          '$secondsLeft초 후 대기 화면으로 돌아갑니다.',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textSub,
          ),
        ),

        const SizedBox(height: 16),

        const ErrorCodeChip('ERR_QR_INVALID'),
      ],
    );
  }
}
