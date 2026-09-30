import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_buttons.dart';
import '../widgets/device_page_layout.dart';
import '../widgets/keycap_board_3d.dart';

/// (테스트 전용) 인증 완료 화면.
///
/// 실제 흐름에서는 QR 인증(start 200) 뒤 바로 부품 도착 대기(waiting)로 가므로
/// 이 화면을 거치지 않는다. DemoMenu「2. 인증 완료」로만 들어온다.
class AuthenticatedScreen extends StatefulWidget {
  final String mbti;
  final List<String> colors;
  final VoidCallback onStart;

  const AuthenticatedScreen({
    super.key,
    required this.mbti,
    required this.colors,
    required this.onStart,
  });

  @override
  State<AuthenticatedScreen> createState() => _AuthenticatedScreenState();
}

class _AuthenticatedScreenState extends State<AuthenticatedScreen> {
  Timer? _autoStartTimer;

  @override
  void initState() {
    super.initState();

    _autoStartTimer = Timer(const Duration(seconds: 5), widget.onStart);
  }

  void _startAssembly() {
    _autoStartTimer?.cancel();
    widget.onStart();
  }

  @override
  void dispose() {
    _autoStartTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DevicePageLayout(
      label: '인증 완료',
      title: 'MBTI 키캡 키링',
      children: [
        Container(
          width: 640,
          height: 250,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(28),
          ),
          child: KeycapBoard3D(
            mbti: widget.mbti,
            colors: widget.colors,
            viewScale: 0.85,
          ),
        ),
        const SizedBox(height: 34),
        SizedBox(
          width: 380,
          height: 96,
          child: PrimaryButton(text: '조립 시작', onPressed: _startAssembly),
        ),
        const SizedBox(height: 22),
        const Text(
          '5초 후 자동으로 조립을 시작합니다.',
          style: TextStyle(fontSize: 23, color: AppColors.textSub),
        ),
      ],
    );
  }
}
