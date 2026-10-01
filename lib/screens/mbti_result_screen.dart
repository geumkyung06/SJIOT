import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STEP 03 — MBTI 결과
/// [디자인 교체] 시안 톤(흰 배경 · 잉크 테두리 · 큰 글자 박스).
/// 애니메이션 타이밍과 콜백 동작은 이전과 동일합니다.
class MbtiResultScreen extends StatefulWidget {
  final String mbti;
  final VoidCallback? onNext; // 터치 지원: ENTER(다음으로) 배지 탭

  const MbtiResultScreen({super.key, required this.mbti, this.onNext});

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
        const SizedBox(height: 18),
        _Fade(
          opacity: _leadOpacity,
          child: const Text('당신의 MBTI는', style: AppTextStyles.body),
        ),
        const SizedBox(height: 52),
        _FadeScale(
          opacity: _badgeOpacity,
          scale: _badgeScale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 108, vertical: 56),
            decoration: AppDeco.outlined(radius: 28, borderColor: AppColors.ink, width: 4),
            child: Text(
              widget.mbti,
              style: const TextStyle(
                fontSize: 108,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: 6,
                height: 1.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 64),
        _FadeSlideY(
          opacity: _buttonOpacity,
          y: _buttonY,
          child: AnimatedBuilder(
            animation: _pulseOpacity,
            builder: (context, child) => Opacity(opacity: _pulseOpacity.value, child: child),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onNext,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 68, vertical: 26),
                decoration: AppDeco.outlined(radius: 18, borderColor: AppColors.ink, width: 2),
                child: const Text(
                  '다음으로',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
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
