import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STEP 02A — MBTI 퀴즈
/// 피그마 `App.tsx > MbtiQuizScreen` 모션 1:1 이식.
class MbtiQuizScreen extends StatefulWidget {
  final int questionIndex; // 0~3
  final int totalQuestions;
  final String question;
  final List<String> optionTexts; // 4개

  const MbtiQuizScreen({
    super.key,
    required this.questionIndex,
    required this.totalQuestions,
    required this.question,
    required this.optionTexts,
  });

  @override
  State<MbtiQuizScreen> createState() => _MbtiQuizScreenState();
}

class _MbtiQuizScreenState extends State<MbtiQuizScreen> with TickerProviderStateMixin {
  static const int _durationMs = 700;

  late final AnimationController _controller;

  late final Animation<double> _labelOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleY;
  late final Animation<double> _subtitleOpacity;
  late final List<Animation<double>> _optOpacity;
  late final List<Animation<double>> _optX;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: _durationMs));

    Animation<double> fadeIn(double s, double e) => CurvedAnimation(
          parent: _controller,
          curve: Interval(s / _durationMs, e / _durationMs, curve: Curves.easeOut),
        );
    Animation<double> slide(double s, double e, double from) => Tween<double>(begin: from, end: 0).animate(
          CurvedAnimation(parent: _controller, curve: Interval(s / _durationMs, e / _durationMs, curve: Curves.easeOut)),
        );

    _labelOpacity = fadeIn(40, 340);
    _titleOpacity = fadeIn(60, 360);
    _titleY = slide(60, 360, 10);
    _subtitleOpacity = fadeIn(100, 400);

    _optOpacity = List.generate(4, (i) => fadeIn(120 + i * 60, 420 + i * 60));
    _optX = List.generate(4, (i) => slide(120 + i * 60, 420 + i * 60, 18));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(covariant MbtiQuizScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionIndex != widget.questionIndex) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Fade(
          opacity: _labelOpacity,
          child: Text(
            'STEP 02 / 06  ·  질문 ${widget.questionIndex + 1} / ${widget.totalQuestions}',
            style: AppTextStyles.label,
          ),
        ),
        const SizedBox(height: 12),
        _FadeSlideY(
          opacity: _titleOpacity,
          y: _titleY,
          child: SizedBox(
            width: 560,
            child: Text(widget.question, textAlign: TextAlign.center, style: AppTextStyles.heading),
          ),
        ),
        const SizedBox(height: 8),
        _Fade(
          opacity: _subtitleOpacity,
          child: const Text('숫자 1~4 를 눌러 선택하세요', style: AppTextStyles.body),
        ),
        const SizedBox(height: 32),
        Column(
          children: List.generate(widget.optionTexts.length, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _FadeSlideX(
                opacity: _optOpacity[i],
                x: _optX[i],
                child: Container(
                  width: 560,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        color: AppColors.ink,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Text(widget.optionTexts[i], style: AppTextStyles.body)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        _ProgressDots(total: widget.totalQuestions, current: widget.questionIndex),
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

class _FadeSlideX extends StatelessWidget {
  final Animation<double> opacity;
  final Animation<double> x;
  final Widget child;
  const _FadeSlideX({required this.opacity, required this.x, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([opacity, x]),
      builder: (context, child) => Opacity(
        opacity: opacity.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(x.value, 0), child: child),
      ),
      child: child,
    );
  }
}

class _ProgressDots extends StatefulWidget {
  final int total;
  final int current;
  const _ProgressDots({required this.total, required this.current});

  @override
  State<_ProgressDots> createState() => _ProgressDotsState();
}

class _ProgressDotsState extends State<_ProgressDots> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _pulseController.forward();
  }

  @override
  void didUpdateWidget(covariant _ProgressDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseScale,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.total, (i) {
            final isCurrent = i == widget.current;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 14,
              height: 14,
              transform: isCurrent ? (Matrix4.identity()..scale(_pulseScale.value)) : Matrix4.identity(),
              transformAlignment: Alignment.center,
              color: i <= widget.current ? AppColors.green : AppColors.tileEmpty,
            );
          }),
        );
      },
    );
  }
}