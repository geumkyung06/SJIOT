import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/keycap_board_3d.dart';
import '../widgets/screen_canvas.dart';

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
  static const int _resetSeconds = 10;

  int secondsLeft = _resetSeconds;
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
    final double progress = (_resetSeconds - secondsLeft) / _resetSeconds;

    // 화면 전체를 공통 캔버스(1340 x 725) 좌표계 위에 그립니다.
    return ScreenCanvas(
      padding: const EdgeInsets.fromLTRB(72, 80, 72, 56),
      shrinkContent: false,
      child: Row(
        children: [
          SizedBox(
            width: 470,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '완료',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textSub,
                    letterSpacing: 5,
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  '조립 완료!',
                  style: TextStyle(
                    fontSize: 80,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'MBTI 키캡 키링이 완성되었습니다.',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),

                const SizedBox(height: 36),

                const _BelongingsNotice(),

                const SizedBox(height: 36),

                Text(
                  '조립대를 다음 사용자를 위해 초기화하는 중 · $secondsLeft초',
                  style: const TextStyle(fontSize: 22, color: AppColors.textSub),
                ),

                const SizedBox(height: 12),

                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    width: 300,
                    height: 6,
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.textSub,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                TextButton(
                  onPressed: widget.onRestart,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.text,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '지금 초기화',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.border,
                      decorationThickness: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 72),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(28),
              ),
              child: ScaleTransition(
                scale: _previewScale,
                child: KeycapBoard3D(
                  mbti: widget.mbti,
                  colors: widget.colors,
                  viewScale: 1.12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 소지품 안내 — 왼쪽 8px 노란 액센트
class _BelongingsNotice extends StatelessWidget {
  const _BelongingsNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 8, color: AppColors.yellow),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 30, 26),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.yellow,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          '!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          '소지품을 꼭 챙겨가세요.',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
