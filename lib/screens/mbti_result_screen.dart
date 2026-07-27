import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STEP 03 — MBTI 결과
/// 피그마 `App.tsx > MbtiResultScreen` 모션 1:1 이식.
class MbtiResultScreen extends StatefulWidget {
  final String mbti;

  const MbtiResultScreen({super.key, required this.mbti});

  @override
  State<MbtiResultScreen> createState() => _MbtiResultScreenState();
}

class _MbtiResultScreenState extends State<MbtiResultScreen> with TickerProviderStateMixin {
  static const int _durationMs = 800;

  late final AnimationController _controller;

  late final Animation<double> _labelOpacity;
  late final Animation<double> _leadOpacity;
  late final Animation<double> _badgeOpacity;
  late final Animation<double> _badgeScale;
  late final Animation<double> _buttonOpacity;
  late final Animation<double> _buttonY;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: _durationMs));

    Animation<double> fadeIn(double s, double e) => CurvedAnimation(
          parent: _controller,
          curve: Interval(s / _durationMs, e / _durationMs, curve: Curves.easeOut),
        );
    Animation<double> slideY(double s, double e, double from) => Tween<double>(begin: from, end: 0).animate(
          CurvedAnimation(parent: _controller, curve: Interval(s / _durationMs, e / _durationMs, curve: Curves.easeOut)),
        );
    Animation<double> springScale(double s, double e, double from) => Tween<double>(begin: from, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Interval(s / _durationMs, e / _durationMs, curve: Curves.easeOutBack)),
        );

    _labelOpacity = fadeIn(40, 340);
    _leadOpacity = fadeIn(80, 380);
    _badgeOpacity = fadeIn(140, 540);
    _badgeScale = springScale(140, 540, 0.82);
    _buttonOpacity = fadeIn(380, 680);
    _buttonY = slideY(380, 680, 10);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Fade(
          opacity: _labelOpacity,
          child: const Text('STEP 03 / 06', style: AppTextStyles.label),
        ),
        const SizedBox(height: 8),
        _Fade(
          opacity: _leadOpacity,
          child: const Text('당신의 MBTI는', style: AppTextStyles.body),
        ),
        const SizedBox(height: 24),
        _FadeScale(
          opacity: _badgeOpacity,
          scale: _badgeScale,
          child: Stack(
            children: [
              Positioned(left: -8, top: -8, child: Container(width: 320, height: 140, color: AppColors.yellow)),
              Container(
                width: 320,
                height: 140,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.ink, width: 3)),
                child: Text(
                  widget.mbti,
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        _FadeSlideY(
          opacity: _buttonOpacity,
          y: _buttonY,
          child: AnimatedBuilder(
            animation: _pulseOpacity,
            builder: (context, child) => Opacity(opacity: _pulseOpacity.value, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppColors.muted,
                    child: const Text('ENTER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  const Text('다음으로', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Fade extends StatelessWidget {
  final Animation<double> opacity;
  final Widget child;
  const _Fade({required this.opacity, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: opacity,
      builder: (context, child) => Opacity(opacity: opacity.value.clamp(0.0, 1.0), child: child),
      child: child,
    );
  }
}

class _FadeSlideY extends StatelessWidget {
  final Animation<double> opacity;
  final Animation<double> y;
  final Widget child;
  const _FadeSlideY({required this.opacity, required this.y, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([opacity, y]),
      builder: (context, child) => Opacity(
        opacity: opacity.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, y.value), child: child),
      ),
      child: child,
    );
  }
}

class _FadeScale extends StatelessWidget {
  final Animation<double> opacity;
  final Animation<double> scale;
  final Widget child;
  const _FadeScale({required this.opacity, required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([opacity, scale]),
      builder: (context, child) => Opacity(
        opacity: opacity.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: scale.value, child: child),
      ),
      child: child,
    );
  }
}