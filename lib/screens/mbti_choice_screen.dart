import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STEP 01 — MBTI를 알고 계신가요?
/// [디자인 교체] 시안 톤(흰 카드 · 얇은 테두리 · 큰 숫자)으로 다시 칠했습니다.
/// 애니메이션 타이밍과 콜백 동작은 이전과 동일합니다.
class MbtiChoiceScreen extends StatefulWidget {
  final void Function(int digit)? onSelect; // 터치 지원: 1=몰라요, 2=알아요

  const MbtiChoiceScreen({super.key, this.onSelect});

  @override
  State<MbtiChoiceScreen> createState() => _MbtiChoiceScreenState();
}

class _MbtiChoiceScreenState extends State<MbtiChoiceScreen> with TickerProviderStateMixin {
  static const int _durationMs = 700;

  late final AnimationController _controller;

  late final Animation<double> _labelOpacity;

  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleY;

  late final Animation<double> _subtitleOpacity;

  late final List<Animation<double>> _optionOpacity;
  late final List<Animation<double>> _optionY;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _durationMs),
    );

    Animation<double> fadeIn(double startMs, double endMs) {
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(startMs / _durationMs, endMs / _durationMs, curve: Curves.easeOut),
      );
    }

    Animation<double> slideY(double startMs, double endMs, double fromPx) {
      return Tween<double>(begin: fromPx, end: 0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(startMs / _durationMs, endMs / _durationMs, curve: Curves.easeOut),
        ),
      );
    }

    _labelOpacity = fadeIn(40, 340);

    _titleOpacity = fadeIn(70, 370);
    _titleY = slideY(70, 370, 10);

    _subtitleOpacity = fadeIn(120, 420);

    _optionOpacity = [fadeIn(160, 460), fadeIn(240, 540)];
    _optionY = [slideY(160, 460, 16), slideY(240, 540, 16)];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
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
          child: const Text('STEP 01 / 06', style: AppTextStyles.label),
        ),
        const SizedBox(height: 18),
        _FadeSlide(
          opacity: _titleOpacity,
          y: _titleY,
          child: const Text('MBTI를 알고 계신가요?', style: AppTextStyles.heading),
        ),
        const SizedBox(height: 14),
        _Fade(
          opacity: _subtitleOpacity,
          child: const Text('1 또는 2 를 눌러 선택하세요', style: AppTextStyles.body),
        ),
        const SizedBox(height: 72),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FadeSlide(
              opacity: _optionOpacity[0],
              y: _optionY[0],
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onSelect == null ? null : () => widget.onSelect!(1),
                child: const _ChoiceOption(
                  keyLabel: '1',
                  title: 'MBTI 몰라요',
                  subtitle: '간단한 질문으로 찾아드릴게요',
                ),
              ),
            ),
            const SizedBox(width: 100),
            _FadeSlide(
              opacity: _optionOpacity[1],
              y: _optionY[1],
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onSelect == null ? null : () => widget.onSelect!(2),
                child: const _ChoiceOption(
                  keyLabel: '2',
                  title: 'MBTI 알아요',
                  subtitle: '직접 입력할게요',
                ),
              ),
            ),
          ],
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

class _FadeSlide extends StatelessWidget {
  final Animation<double> opacity;
  final Animation<double> y;
  final Widget child;

  const _FadeSlide({required this.opacity, required this.y, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([opacity, y]),
      builder: (context, child) {
        return Opacity(
          opacity: opacity.value.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, y.value), child: child),
        );
      },
      child: child,
    );
  }
}

/// [디자인] 시안의 선택 카드 — 흰 배경 + 잉크 테두리 + 큰 숫자
class _ChoiceOption extends StatelessWidget {
  final String keyLabel;
  final String title;
  final String subtitle;

  const _ChoiceOption({
    required this.keyLabel,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 340,
          height: 208,
          alignment: Alignment.center,
          decoration: AppDeco.outlined(radius: 24, borderColor: AppColors.ink, width: 3),
          child: Text(
            keyLabel,
            style: const TextStyle(
              fontSize: 92,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(subtitle, style: AppTextStyles.body),
      ],
    );
  }
}
