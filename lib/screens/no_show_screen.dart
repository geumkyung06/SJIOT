import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_buttons.dart';
import '../widgets/error_badge.dart';

/// 호출 후 정해진 시간 안에 QR 인증이 없어 주문이 취소된 화면.
/// 안내를 잠깐 보여준 뒤 자동으로 주문 호출 대기 화면으로 돌아간다.
class NoShowScreen extends StatefulWidget {
  final String? orderNumber;
  final VoidCallback onAutoReturn;
  final VoidCallback onCallStaff;

  const NoShowScreen({
    super.key,
    this.orderNumber,
    required this.onAutoReturn,
    required this.onCallStaff,
  });

  @override
  State<NoShowScreen> createState() => _NoShowScreenState();
}

class _NoShowScreenState extends State<NoShowScreen> {
  int secondsLeft = 5;

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
    final String? orderNumber = widget.orderNumber;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(64, 110, 64, 60),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const ErrorBadge(),

              const SizedBox(height: 26),

              const Text(
                '호출 시간이 초과되었습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 68,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                orderNumber == null
                    ? '5분 동안 QR 인증이 없어 주문이 취소되었습니다.\n'
                          '취소된 주문은 카운터에서 다시 확인해 주세요.'
                    : '주문번호 $orderNumber번, 5분 동안 QR 인증이 없어 주문이 취소되었습니다.\n'
                          '취소된 주문은 카운터에서 다시 확인해 주세요.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  height: 1.65,
                  color: AppColors.textSub,
                ),
              ),

              const SizedBox(height: 48),

              SizedBox(
                width: 330,
                height: 96,
                child: OutlineButton(
                  text: '직원 호출',
                  onPressed: widget.onCallStaff,
                ),
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

              const ErrorCodeChip('ERR_NO_SHOW'),
            ],
          ),
        ),
      ),
    );
  }
}
