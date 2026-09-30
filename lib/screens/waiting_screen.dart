import 'dart:async';
import 'package:flutter/material.dart';

import '../debug/app_log.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/conveyor_belt.dart';
import '../widgets/screen_canvas.dart';

// 대기 중 화면
class WaitingScreen extends StatefulWidget {
  final String workstationNumber;
  final String orderId;
  final VoidCallback onReceived;

  const WaitingScreen({
    super.key,
    required this.workstationNumber,
    required this.orderId,
    required this.onReceived,
  });

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  final ApiService _apiService = ApiService();

  Timer? _statusTimer;

  bool _isChecking = false;
  bool _hasTransitioned = false;

  @override
  void initState() {
    super.initState();

    // 화면 진입 즉시 한 번 확인
    _checkOrderStatus();

    // 이후 1초마다 주문 상태 확인
    _statusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkOrderStatus(),
    );
  }

  Future<void> _checkOrderStatus() async {
    // 중복 요청 / 중복 화면 전환 방지
    if (_isChecking || _hasTransitioned) {
      return;
    }

    _isChecking = true;

    try {
      final data = await _apiService.getOrderStatus(orderId: widget.orderId);

      final stage = data['stage']?.toString();

      AppLog.d(
        LogTag.screen,
        '[WaitingScreen] order_id=${widget.orderId}, stage=$stage',
      );

      // 부품 도착 완료
      if (stage == 'received') {
        _hasTransitioned = true;

        // 더 이상 polling 하지 않음
        _statusTimer?.cancel();

        if (!mounted) return;

        // 조립 화면으로 전환
        widget.onReceived();
      }
    } on ApiException catch (e) {
      AppLog.w(
        LogTag.screen,
        '[WaitingScreen] 주문 상태 조회 실패 (${e.statusCode})',
      );
    } catch (e) {
      AppLog.w(LogTag.screen, '[WaitingScreen] 주문 상태 조회 오류: $e');
    } finally {
      _isChecking = false;
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
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
          style: TextStyle(fontSize: 23, height: 1.6, color: AppColors.textSub),
        ),

        const SizedBox(height: 36),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            '부품 도착을 기다리고 있습니다.',
            style: TextStyle(
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
