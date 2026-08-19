import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_buttons.dart';
import '../widgets/device_page_layout.dart';
import '../widgets/keyring_preview.dart';

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
        KeyringPreview(mbti: widget.mbti, colors: widget.colors),
        const SizedBox(height: 52),
        SizedBox(
          width: 330,
          height: 96,
          child: PrimaryButton(text: '조립 시작', onPressed: _startAssembly),
        ),
        const SizedBox(height: 20),
        const Text(
          '5초 후 자동으로 조립을 시작합니다.',
          style: TextStyle(fontSize: 17, color: AppColors.gray),
        ),
      ],
    );
  }
}
