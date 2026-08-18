import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STEP 04 — 축(스위치) 선택 (보드 선택 단계 제외로 05→04)
/// 피그마 `App.tsx > SwitchSelectScreen` 모션 1:1 이식.
class AxisSelectScreen extends StatefulWidget {
  final Set<String> soldOutAxes;
  final void Function(int digit)? onSelect; // 터치 지원: 1~4번 축 선택

  const AxisSelectScreen({
    super.key,
    required this.soldOutAxes,
    this.onSelect,
  });

  @override
  State<AxisSelectScreen> createState() => _AxisSelectScreenState();
}

class _AxisSelectScreenState extends State<AxisSelectScreen> with TickerProviderStateMixin {
  static const int _durationMs = 750;

  late final AnimationController _controller;

  late final Animation<double> _labelOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleY;
  late final Animation<double> _subtitleOpacity;
  late final List<Animation<double>> _optOpacity;
  late final List<Animation<double>> _optY;

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

    _labelOpacity = fadeIn(40, 340);
    _titleOpacity = fadeIn(70, 370);
    _titleY = slideY(70, 370, 10);
    _subtitleOpacity = fadeIn(120, 420);

    _optOpacity = List.generate(4, (i) => fadeIn(140 + i * 70, 440 + i * 70));
    _optY = List.generate(4, (i) => slideY(140 + i * 70, 440 + i * 70, 22));

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
    final options = [
      (keyLabel: '1', color: const Color(0xFF3E7CE0), title: '청축', key: 'blue'),
      (keyLabel: '2', color: const Color(0xFF9C6B3F), title: '갈축', key: 'brown'),
      (keyLabel: '3', color: const Color(0xFFD5473C), title: '적축', key: 'red'),
      (keyLabel: '4', color: const Color(0xFF2B2B2B), title: '흑축', key: 'black'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Fade(
          opacity: _labelOpacity,
          child: const Text('STEP 04 / 06', style: AppTextStyles.label),
        ),
        const SizedBox(height: 8),
        _FadeSlideY(
          opacity: _titleOpacity,
          y: _titleY,
          child: const Text('축(스위치) 선택', style: AppTextStyles.heading),
        ),
        const SizedBox(height: 8),
        _Fade(
          opacity: _subtitleOpacity,
          child: const Text('키보드 1~4 를 눌러 선택하세요 (또는 탭)', style: AppTextStyles.body),
        ),
        const SizedBox(height: 40),
        Wrap(
          spacing: 32,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          children: List.generate(options.length, (i) {
            final o = options[i];
            final soldOut = widget.soldOutAxes.contains(o.key);
            return _FadeSlideY(
              opacity: _optOpacity[i],
              y: _optY[i],
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: (widget.onSelect == null || soldOut) ? null : () => widget.onSelect!(i + 1),
                child: _AxisOption(
                  keyLabel: o.keyLabel,
                  color: o.color,
                  title: o.title,
                  soldOut: soldOut,
                ),
              ),
            );
          }),
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

class _AxisOption extends StatelessWidget {
  final String keyLabel;
  final Color color;
  final String title;
  final bool soldOut;

  const _AxisOption({
    required this.keyLabel,
    required this.color,
    required this.title,
    required this.soldOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: soldOut ? Colors.grey.shade400 : color,
            border: Border.all(
              color: soldOut ? Colors.grey.shade600 : AppColors.ink,
              width: 2,
            ),
          ),
          child: Text(
            soldOut ? '재고없음' : keyLabel,
            style: TextStyle(
              fontSize: soldOut ? 17 : 40,
              fontWeight: FontWeight.w900,
              color: soldOut ? Colors.grey.shade800 : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: soldOut ? Colors.grey : AppColors.ink,
            )),
      ],
    );
  }
}
