import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STEP 04 — 보드(케이스) 색상 선택
/// [수정] 원래는 1×4 / 2×2 "판 크기"를 고르는 화면이었으나, 팀 확정으로
/// 판 크기는 1×4로 고정되고 대신 "판 색상"을 고르는 화면으로 바뀌었습니다.
/// 애니메이션 구조(등장 타이밍 등)는 기존 화면과 동일하게 유지했습니다.
///
/// [디자인 교체] 시안 톤 — 색 판 위에 키캡이 꽂힐 자리를 뚫어 보여주고,
/// 그 아래 숫자 뱃지와 색 이름을 둡니다.
///
/// 색상 코드는 키캡 색상과 동일한 4가지(g/y/b/r)를 그대로 씁니다.
/// ⚠️ 'r' 코드는 화면에는 핑크로 보이지만, 백엔드에는 그대로 'red'/'r'로
/// 전송합니다(코드 키를 바꾸지 말 것 — 팀 확정 사항).
class BoardSelectScreen extends StatefulWidget {
  final Set<String> soldOutColors; // 품절된 보드 색상 코드(g/y/b/r)
  final void Function(int digit)? onSelect; // 터치 지원: 1~4 = g/y/b/r

  const BoardSelectScreen({super.key, this.soldOutColors = const {}, this.onSelect});

  @override
  State<BoardSelectScreen> createState() => _BoardSelectScreenState();
}

class _BoardSelectScreenState extends State<BoardSelectScreen> with TickerProviderStateMixin {
  static const int _durationMs = 700;

  late final AnimationController _controller;

  late final Animation<double> _labelOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleY;
  late final Animation<double> _subtitleOpacity;

  late final List<Animation<double>> _optionOpacity;
  late final List<Animation<double>> _optionY;

  // 순서는 keycap_fill_screen.dart의 범례(g,y,b,r = 1,2,3,4)와 동일하게 맞춤
  static const List<_BoardColorSpec> _colors = [
    _BoardColorSpec(digit: 1, code: 'g', color: BoardColors.green, name: '그린'),
    _BoardColorSpec(digit: 2, code: 'y', color: BoardColors.yellow, name: '옐로우'),
    _BoardColorSpec(digit: 3, code: 'b', color: BoardColors.blue, name: '블루'),
    _BoardColorSpec(digit: 4, code: 'r', color: BoardColors.red, name: '핑크'),
  ];

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

    _optionOpacity = List.generate(4, (i) => fadeIn(160 + i * 60, 460 + i * 60));
    _optionY = List.generate(4, (i) => slideY(160 + i * 60, 460 + i * 60, 16));

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
          child: const Text('STEP 04 / 06', style: AppTextStyles.label),
        ),
        const SizedBox(height: 18),
        _FadeSlide(
          opacity: _titleOpacity,
          y: _titleY,
          child: const Text('보드판 색상을 선택하세요', style: AppTextStyles.heading),
        ),
        const SizedBox(height: 14),
        _Fade(
          opacity: _subtitleOpacity,
          child: const Text('숫자 1~4를 눌러 선택하세요', style: AppTextStyles.body),
        ),
        const SizedBox(height: 72),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 44,
          runSpacing: 44,
          children: List.generate(_colors.length, (i) {
            final spec = _colors[i];
            final isSoldOut = widget.soldOutColors.contains(spec.code);
            return _FadeSlide(
              opacity: _optionOpacity[i],
              y: _optionY[i],
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: (widget.onSelect == null || isSoldOut) ? null : () => widget.onSelect!(spec.digit),
                child: _BoardColorOption(spec: spec, isSoldOut: isSoldOut),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BoardColorSpec {
  final int digit;
  final String code;
  final Color color;
  final String name;
  const _BoardColorSpec({required this.digit, required this.code, required this.color, required this.name});
}

class _BoardColorOption extends StatelessWidget {
  final _BoardColorSpec spec;
  final bool isSoldOut;

  const _BoardColorOption({required this.spec, required this.isSoldOut});

  @override
  Widget build(BuildContext context) {
    final accent = isSoldOut ? AppColors.disabledBg : spec.color;

    return Column(
      children: [
        _BoardPreview(color: accent, dimmed: isSoldOut),
        const SizedBox(height: 26),
        KeyNumBadge(
          label: '${spec.digit}',
          disabled: isSoldOut,
          size: 54,
          fontSize: 26,
        ),
        const SizedBox(height: 18),
        Text(
          spec.name,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: isSoldOut ? AppColors.disabledText : AppColors.ink,
          ),
        ),
        if (isSoldOut)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: SoldOutPill(text: '재고없음', fontSize: 19),
          ),
      ],
    );
  }
}

/// [디자인] 시안의 판 미리보기 — 색 판 위에 키캡이 꽂힐 4개 자리를 뚫어 놓은 모양.
class _BoardPreview extends StatelessWidget {
  final Color color;
  final bool dimmed;
  const _BoardPreview({required this.color, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: dimmed
            ? Border.all(color: AppColors.disabledLine, width: 2)
            : Border.all(color: AppColors.ink.withValues(alpha: 0.10), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          4,
          (c) => Container(
            width: 62,
            height: 70,
            margin: EdgeInsets.only(right: c == 3 ? 0 : 14),
            decoration: BoxDecoration(
              // 진짜 투명 — 아래 판 색이 그대로 비쳐서
              // "키캡이 들어갈 자리"처럼 보입니다.
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: dimmed
                    ? AppColors.disabledLine
                    : AppColors.ink.withValues(alpha: 0.22),
                width: 3,
              ),
            ),
          ),
        ),
      ),
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
