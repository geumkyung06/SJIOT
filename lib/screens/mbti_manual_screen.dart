import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STEP 02B — MBTI 직접 입력
/// 피그마 `App.tsx > MbtiDirectScreen` 모션 1:1 이식.
class MbtiManualScreen extends StatefulWidget {
  final int questionIndex; // 0~3
  final int totalQuestions;
  final String letterA;
  final String letterB;

  final bool letterASoldOut;
  final bool letterBSoldOut;
  final void Function(String letter)? onSelect; // 터치 지원: A/B 배지를 탭

  const MbtiManualScreen({
    super.key,
    required this.questionIndex,
    required this.totalQuestions,
    required this.letterA,
    required this.letterB,
    required this.letterASoldOut,
    required this.letterBSoldOut,
    this.onSelect,
  });

  @override
  State<MbtiManualScreen> createState() => _MbtiManualScreenState();
}

class _MbtiManualScreenState extends State<MbtiManualScreen>
    with TickerProviderStateMixin {
  static const int _durationMs = 700;

  late final AnimationController _controller;

  late final Animation<double> _labelOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleY;
  late final Animation<double> _subtitleOpacity;
  late final List<Animation<double>> _badgeOpacity;
  late final List<Animation<double>> _badgeScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _durationMs),
    );

    Animation<double> fadeIn(double s, double e) => CurvedAnimation(
      parent: _controller,
      curve: Interval(s / _durationMs, e / _durationMs, curve: Curves.easeOut),
    );
    Animation<double> slideY(double s, double e, double from) =>
        Tween<double>(begin: from, end: 0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(
              s / _durationMs,
              e / _durationMs,
              curve: Curves.easeOut,
            ),
          ),
        );
    Animation<double> springScale(double s, double e, double from) =>
        Tween<double>(begin: from, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(
              s / _durationMs,
              e / _durationMs,
              curve: Curves.easeOutBack,
            ),
          ),
        );

    _labelOpacity = fadeIn(40, 340);
    _titleOpacity = fadeIn(70, 370);
    _titleY = slideY(70, 370, 10);
    _subtitleOpacity = fadeIn(120, 420);

    _badgeOpacity = [fadeIn(160, 480), fadeIn(240, 560)];
    _badgeScale = [springScale(160, 480, 0.88), springScale(240, 560, 0.88)];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(covariant MbtiManualScreen oldWidget) {
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
        const SizedBox(height: 8),
        _FadeSlideY(
          opacity: _titleOpacity,
          y: _titleY,
          child: const Text('MBTI를 직접 입력하세요', style: AppTextStyles.heading),
        ),
        const SizedBox(height: 8),
        _Fade(
          opacity: _subtitleOpacity,
          child: const Text('키보드에서 해당하는 알파벳을 눌러주세요', style: AppTextStyles.body),
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FadeScale(
              opacity: _badgeOpacity[0],
              scale: _badgeScale[0],
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: (widget.onSelect == null || widget.letterASoldOut)
                    ? null
                    : () => widget.onSelect!(widget.letterA),
                child: Row(
                  children: [
                    _LetterBadge(
                      letter: widget.letterA,
                      soldOut: widget.letterASoldOut,
                    ),
                    const SizedBox(width: 20),
                    const Text(
                      '입니까?',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 40),
            _FadeScale(
              opacity: _badgeOpacity[1],
              scale: _badgeScale[1],
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: (widget.onSelect == null || widget.letterBSoldOut)
                    ? null
                    : () => widget.onSelect!(widget.letterB),
                child: Row(
                  children: [
                    _LetterBadge(
                      letter: widget.letterB,
                      soldOut: widget.letterBSoldOut,
                    ),
                    const SizedBox(width: 20),
                    const Text(
                      '입니까?',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        _ProgressDots(
          total: widget.totalQuestions,
          current: widget.questionIndex,
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
      builder: (context, child) =>
          Opacity(opacity: opacity.value.clamp(0.0, 1.0), child: child),
      child: child,
    );
  }
}

class _FadeSlideY extends StatelessWidget {
  final Animation<double> opacity;
  final Animation<double> y;
  final Widget child;
  const _FadeSlideY({
    required this.opacity,
    required this.y,
    required this.child,
  });

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
  const _FadeScale({
    required this.opacity,
    required this.scale,
    required this.child,
  });

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

class _LetterBadge extends StatelessWidget {
  final String letter;
  final bool soldOut;

  const _LetterBadge({required this.letter, required this.soldOut});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.ink, width: 3),
          ),
          child: Text(
            letter,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (soldOut)
          const Text(
            '재고없음',
            style: TextStyle(
              color: Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          )
        else
          const SizedBox(height: 16),
      ],
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

class _ProgressDotsState extends State<_ProgressDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseScale = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
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
              transform: isCurrent
                  ? (Matrix4.identity()..scale(_pulseScale.value))
                  : Matrix4.identity(),
              transformAlignment: Alignment.center,
              color: i <= widget.current
                  ? AppColors.green
                  : AppColors.tileEmpty,
            );
          }),
        );
      },
    );
  }
}