import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_buttons.dart';
import '../widgets/device_page_layout.dart';
import '../widgets/keycap_board_3d.dart';

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
          height: 260,
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
        const SizedBox(height: 44),
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
