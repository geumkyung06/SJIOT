import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StatusCircle(),

            const SizedBox(height: 28),

            Text(
              '조립대 ${widget.workstationNumber}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 72,
                height: 1,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              '인증이 완료되었습니다.\n'
              '로봇이 부품을 내려놓기 전까지 기다려 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                height: 1.5,
                color: AppColors.gray,
              ),
            ),

            const SizedBox(height: 32),

            Text(
              '$_secondsLeft초 후 조립 화면으로 이동합니다.',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.gray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 대기 중 원형 표시
/// 대기 중 원형 애니메이션
class StatusCircle extends StatefulWidget {
  const StatusCircle({super.key});

  @override
  State<StatusCircle> createState() => _StatusCircleState();
}

class _StatusCircleState extends State<StatusCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _outerScale;
  late final Animation<double> _middleScale;
  late final Animation<double> _centerScale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // 바깥 원
    _outerScale = Tween<double>(
      begin: 0.92,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // 가운데 원
    _middleScale = Tween<double>(begin: 0.94, end: 1.03).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 1.0, curve: Curves.easeInOut),
      ),
    );

    // 중앙 점
    _centerScale = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 바깥 원
          ScaleTransition(
            scale: _outerScale,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.lightGray, width: 3),
              ),
            ),
          ),

          // 가운데 원
          ScaleTransition(
            scale: _middleScale,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.lightGray, width: 3),
              ),
            ),
          ),

          // 중앙 점
          ScaleTransition(
            scale: _centerScale,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF444444),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
