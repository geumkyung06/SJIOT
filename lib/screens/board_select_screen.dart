import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STEP 04 — 보드(케이스) 색상 선택
/// [수정] 원래는 1×4 / 2×2 "판 크기"를 고르는 화면이었으나, 팀 확정으로
/// 판 크기는 1×4로 고정되고 대신 "판 색상"을 고르는 화면으로 바뀌었습니다.
/// 애니메이션 구조(등장 타이밍 등)는 기존 화면과 동일하게 유지했습니다.
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
        const SizedBox(height: 8),
        _FadeSlide(
          opacity: _titleOpacity,
          y: _titleY,
          child: const Text('보드판 색상을 선택하세요', style: AppTextStyles.heading),
        ),
        const SizedBox(height: 8),
        _Fade(
          opacity: _subtitleOpacity,
          child: const Text('숫자 1~4를 눌러 선택하세요', style: AppTextStyles.body),
        ),
        const SizedBox(height: 48),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 32,
          runSpacing: 32,
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
    final accent = isSoldOut ? Colors.grey.shade400 : spec.color;

    return Column(
      children: [
        Stack(
          children: [
            // [수정] 이전에는 이 자리에 색이 있는 사각형(그림자 역할)을 뒀는데,
            // 이제 판 자체가 색을 갖게 되면서 그림자는 잉크색으로 바꿔
            // "종이가 겹쳐진" 입체감만 남기고 색 표현은 판(_BoardPreview)이
            // 전담하도록 했습니다.
            Positioned(
              left: -8,
              top: -8,
              child: Container(width: 200, height: 130, color: AppColors.ink),
            ),
            _BoardPreview(color: accent),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: isSoldOut ? Colors.grey.shade500 : AppColors.ink, width: 2),
          ),
          child: Text(
            '${spec.digit}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isSoldOut ? Colors.grey.shade600 : AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          spec.name,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: isSoldOut ? Colors.grey.shade600 : AppColors.ink,
          ),
        ),
        if (isSoldOut)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('재고없음', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}

// [수정] 실제 키보드 기판처럼: 판(케이스)은 선택한 색으로 칠하고,
// 키캡이 꽂히는 4개 자리는 투명하게 뚫어서 그 아래(화면 배경)가 비쳐
// 보이게 합니다. [수정] 키캡 모양과 통일감을 주기 위해 세로로 길쭉한
// 직사각형이 아니라 키캡과 같은 정사각형 구멍으로 바꿨습니다.
class _BoardPreview extends StatelessWidget {
  final Color color;
  const _BoardPreview({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 130,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, border: Border.all(color: AppColors.ink, width: 2)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          4,
          (c) => Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              // 진짜 투명 — 화면 배경(AppColors.background)이 그대로 비쳐서
              // "키캡이 들어갈 구멍"처럼 보입니다.
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
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
