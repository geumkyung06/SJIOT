import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_buttons.dart';

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

class _InvalidQrScreenState extends State<InvalidQrScreen> {
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
      widget.onRetry();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 100, 40, 40),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                '오류',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.red,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                '인식할 수 없는 QR 코드',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 60,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                '스캔한 QR 코드를 인식하지 못했습니다.\n'
                '영수증에 인쇄된 QR 코드를 사용하고 있는지 확인하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.6,
                  color: AppColors.gray,
                ),
              ),

              const SizedBox(height: 48),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 330,
                    height: 92,
                    child: PrimaryButton(
                      text: '다시 시도',
                      onPressed: widget.onRetry,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 330,
                    height: 92,
                    child: OutlineButton(
                      text: '직원 호출',
                      onPressed: widget.onCallStaff,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Text(
                '$secondsLeft초 후 대기 화면으로 돌아갑니다.',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'ERR_QR_INVALID',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.gray,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
