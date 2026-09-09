import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STEP 02A — MBTI 퀴즈
/// [디자인 교체] 시안 톤(흰 카드 · 연한 테두리 보기 · 잉크 번호 뱃지).
/// 문항/선택 처리 동작과 애니메이션 타이밍은 이전과 동일합니다.
class MbtiQuizScreen extends StatefulWidget {
  final int questionIndex; // 0~3
  final int totalQuestions;
  final String question;
  final List<String> optionTexts; // 4개
  // [신규] 각 보기가 가리키는 글자(E/I/N/S/F/T/J/P)의 모든 색상이 품절이면
  // true. mbti_manual_screen.dart에는 있었는데 이 화면엔 빠져있던 것을
  // 추가함 — 안 그러면 관람객이 품절된 보기를 눌러도 왜 안 되는지
  // 알 방법이 없었음.
  final List<bool> optionSoldOut; // 4개
  final void Function(int digit)? onSelect; // 터치 지원: 1~4번 보기 선택

  const MbtiQuizScreen({
    super.key,
    required this.questionIndex,
    required this.totalQuestions,
    required this.question,
    required this.optionTexts,
    this.optionSoldOut = const [false, false, false, false],
    this.onSelect,
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
        const SizedBox(height: 18),
        _FadeSlideY(
          opacity: _titleOpacity,
          y: _titleY,
          child: SizedBox(
            width: 1040,
            child: Text(widget.question, textAlign: TextAlign.center, style: AppTextStyles.heading),
          ),
        ),
        const SizedBox(height: 14),
        _Fade(
          opacity: _subtitleOpacity,
          child: const Text('숫자 1~4 를 눌러 선택하세요', style: AppTextStyles.body),
        ),
        const SizedBox(height: 40),
        Column(
          children: List.generate(widget.optionTexts.length, (i) {
            final soldOut = i < widget.optionSoldOut.length && widget.optionSoldOut[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _FadeSlideX(
                opacity: _optOpacity[i],
                x: _optX[i],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: (widget.onSelect == null || soldOut) ? null : () => widget.onSelect!(i + 1),
                  child: Container(
                    width: 1000,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
                    decoration: AppDeco.outlined(
                      radius: 20,
                      borderColor: soldOut ? AppColors.disabledLine : AppColors.border,
                      fill: soldOut ? AppColors.disabledBg : AppColors.surface,
                    ),
                    child: Row(
                      children: [
                        KeyNumBadge(
                          label: '${i + 1}',
                          filled: !soldOut,
                          disabled: soldOut,
                          size: 50,
                          fontSize: 24,
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: Text(
                            widget.optionTexts[i],
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              color: soldOut ? AppColors.disabledText : AppColors.ink,
                            ),
                          ),
                        ),
                        if (soldOut) const SoldOutPill(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 30),
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

/// [디자인] 시안의 사각 점 인디케이터 (9x9 · radius 2 → 캔버스 배율 적용)
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
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 18,
              height: 18,
              transform: isCurrent ? (Matrix4.identity()..scale(_pulseScale.value)) : Matrix4.identity(),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                color: i <= widget.current ? AppColors.accent : AppColors.border,
                borderRadius: BorderRadius.circular(5),
              ),
            );
          }),
        );
      },
    );
  }
}
