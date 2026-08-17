import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STEP 06 — 디자인 확인 (완성된 키캡 디자인 미리보기)
///
/// 중요: 이 화면에서는 어떤 주문/제작 정보도 서버로 전송하지 않습니다.
/// 순수하게 지금까지 고른 디자인을 보여주기만 합니다.
///   - Enter: 이때 비로소 main.dart가 실제 주문 정보를 서버로 전송하고
///            영수증 화면으로 이동합니다.
///   - Esc  : 아무 정보도 전송하지 않고, 선택했던 모든 값을 초기화한 뒤
///            STEP 01(MBTI를 아는지 선택하는 화면)로 돌아갑니다.
/// (실제 Enter/Esc 키 처리는 main.dart의 KeyboardListener에서 담당합니다.
///  이 위젯은 화면 표시만 담당합니다.)
class DesignConfirmScreen extends StatefulWidget {
  final String boardShape; // '1x4' | '2x2'
  final List<String> letters;
  final Color Function(int index) colorAt;
  final String axisLabel; // 예: 청축 / 갈축 / 적축 / 흑축
  final Color axisColor;

  const DesignConfirmScreen({
    super.key,
    required this.boardShape,
    required this.letters,
    required this.colorAt,
    required this.axisLabel,
    required this.axisColor,
  });

  @override
  State<DesignConfirmScreen> createState() => _DesignConfirmScreenState();
}

class _DesignConfirmScreenState extends State<DesignConfirmScreen>
    with TickerProviderStateMixin {
  static const int _durationMs = 750;

  late final AnimationController _controller;

  late final Animation<double> _labelOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleY;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _plateOpacity;
  late final Animation<double> _plateScale;
  late final Animation<double> _axisOpacity;
  late final Animation<double> _axisY;
  late final Animation<double> _hintOpacity;
  late final Animation<double> _hintY;

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
            curve: Interval(s / _durationMs, e / _durationMs, curve: Curves.easeOut),
          ),
        );
    Animation<double> springScale(double s, double e, double from) =>
        Tween<double>(begin: from, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(s / _durationMs, e / _durationMs, curve: Curves.easeOutBack),
          ),
        );

    _labelOpacity = fadeIn(40, 340);
    _titleOpacity = fadeIn(70, 370);
    _titleY = slideY(70, 370, 10);
    _subtitleOpacity = fadeIn(120, 420);
    _plateOpacity = fadeIn(160, 560);
    _plateScale = springScale(160, 560, 0.86);
    _axisOpacity = fadeIn(360, 620);
    _axisY = slideY(360, 620, 12);
    _hintOpacity = fadeIn(420, 720);
    _hintY = slideY(420, 720, 12);

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
    final cols = widget.boardShape == '2x2' ? 2 : widget.letters.length;
    final rows = widget.boardShape == '2x2' ? 2 : 1;
    final plateWidth = widget.boardShape == '2x2' ? 260.0 : 460.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Fade(
          opacity: _labelOpacity,
          child: const Text('STEP 06 / 06', style: AppTextStyles.label),
        ),
        const SizedBox(height: 8),
        _FadeSlideY(
          opacity: _titleOpacity,
          y: _titleY,
          child: const Text('디자인이 완성되었어요', style: AppTextStyles.heading),
        ),
        const SizedBox(height: 8),
        _Fade(
          opacity: _subtitleOpacity,
          child: const Text(
            '마음에 들면 Enter, 다시 고르려면 Esc',
            style: AppTextStyles.body,
          ),
        ),
        const SizedBox(height: 40),
        AnimatedBuilder(
          animation: Listenable.merge([_plateOpacity, _plateScale]),
          builder: (context, child) => Opacity(
            opacity: _plateOpacity.value.clamp(0.0, 1.0),
            child: Transform.scale(scale: _plateScale.value, child: child),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -8,
                top: -8,
                child: Container(
                  width: plateWidth,
                  height: rows == 2 ? plateWidth : 150,
                  color: AppColors.yellow,
                ),
              ),
              Container(
                width: plateWidth,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(rows, (r) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(cols, (c) {
                          final i = r * cols + c;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Container(
                              width: 84,
                              height: 84,
                              alignment: Alignment.center,
                              color: widget.colorAt(i),
                              child: Text(
                                widget.letters[i],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _FadeSlideY(
          opacity: _axisOpacity,
          y: _axisY,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('축', style: TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                Container(width: 20, height: 20, color: widget.axisColor),
                const SizedBox(width: 10),
                Text(
                  widget.axisLabel,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        _FadeSlideY(
          opacity: _hintOpacity,
          y: _hintY,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _KeyHint(keyLabel: 'ENTER', text: '접수하기', accent: AppColors.green),
              const SizedBox(width: 32),
              _KeyHint(keyLabel: 'ESC', text: '다시 만들기', accent: AppColors.coral),
            ],
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

class _KeyHint extends StatelessWidget {
  final String keyLabel;
  final String text;
  final Color accent;
  const _KeyHint({required this.keyLabel, required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: AppColors.muted,
            child: Text(
              keyLabel,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: accent)),
        ],
      ),
    );
  }
}
