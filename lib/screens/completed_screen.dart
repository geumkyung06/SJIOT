import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/keyring_preview.dart';

class CompletedScreen extends StatefulWidget {
  final String mbti;
  final List<String> colors;
  final VoidCallback onRestart;

  const CompletedScreen({
    super.key,
    required this.mbti,
    required this.colors,
    required this.onRestart,
  });

  @override
  State<CompletedScreen> createState() => _CompletedScreenState();
}

class _CompletedScreenState extends State<CompletedScreen>
    with SingleTickerProviderStateMixin {
  int secondsLeft = 10;
  late final AnimationController _previewController;
  late final Animation<double> _previewScale;

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _previewController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _previewScale = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(parent: _previewController, curve: Curves.easeOutBack),
    );

    _previewController.forward();

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
      widget.onRestart();
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
                '완료',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gray,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                '조립 완료!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 72,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'MBTI 키캡 키링이 완성되었습니다.',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),

              const SizedBox(height: 44),

              ScaleTransition(
                scale: _previewScale,
                child: KeyringPreview(
                  mbti: widget.mbti,
                  colors: widget.colors,
                  large: true,
                ),
              ),

              const SizedBox(height: 48),

              Container(
                width: 590,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.black, width: 2),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 25),
                    SizedBox(width: 14),
                    Flexible(
                      child: Text(
                        '소지품을 꼭 챙겨가세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 42),

              Text(
                '●  조립대를 다음 사용자를 위해 초기화하는 중... '
                '$secondsLeft초',
                style: const TextStyle(fontSize: 16, color: AppColors.gray),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: widget.onRestart,
                child: const Text('지금 초기화'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
