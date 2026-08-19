import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STEP 05 — 키캡 색을 선택하세요 (보드 선택 단계 제외로 06→05)
/// 피그마 `App.tsx > ColorSelectScreen` 모션 1:1 이식.
class KeycapFillScreen extends StatefulWidget {
  final String boardShape; // '1x4' | '2x2'
  final List<String> letters;
  final int cursor;
  final Color Function(int index) colorAt;

  final Set<String> soldOutColors;
  final String? message;
  final bool stockLoading;

  // 터치 지원
  final void Function(int index)? onCellTap; // 칸을 탭하면 그 칸으로 커서 이동
  final void Function(int digit)? onColorTap; // 색상 팔레트를 탭하면 현재 칸에 그 색 적용
  final VoidCallback? onSubmit; // 완료 버튼(=ENTER) 탭

  const KeycapFillScreen({
    super.key,
    required this.boardShape,
    required this.letters,
    required this.cursor,
    required this.colorAt,
    required this.soldOutColors,
    this.message,
    required this.stockLoading,
    this.onCellTap,
    this.onColorTap,
    this.onSubmit,
  });

  @override
  State<KeycapFillScreen> createState() => _KeycapFillScreenState();
}

class _KeycapFillScreenState extends State<KeycapFillScreen> with TickerProviderStateMixin {
  static const int _durationMs = 700;

  late final AnimationController _controller;

  late final Animation<double> _labelOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleY;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _plateOpacity;
  late final Animation<double> _plateY;
  late final Animation<double> _colorListOpacity;
  late final Animation<double> _colorListX;
  late final Animation<double> _arrowsOpacity;
  late final Animation<double> _arrowsX;
  late final Animation<double> _buttonOpacity;
  late final Animation<double> _buttonY;

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
    Animation<double> slideX(double s, double e, double from) => Tween<double>(begin: from, end: 0).animate(
          CurvedAnimation(parent: _controller, curve: Interval(s / _durationMs, e / _durationMs, curve: Curves.easeOut)),
        );

    _labelOpacity = fadeIn(40, 340);
    _titleOpacity = fadeIn(70, 370);
    _titleY = slideY(70, 370, 10);
    _subtitleOpacity = fadeIn(120, 420);
    _plateOpacity = fadeIn(160, 460);
    _plateY = slideY(160, 460, 12);
    _colorListOpacity = fadeIn(220, 520);
    _colorListX = slideX(220, 520, -10);
    _arrowsOpacity = fadeIn(240, 540);
    _arrowsX = slideX(240, 540, 10);
    _buttonOpacity = fadeIn(280, 580);
    _buttonY = slideY(280, 580, 10);

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
    final filled = widget.letters.asMap().entries.where((e) => widget.colorAt(e.key) != AppColors.tileEmpty).length;
    final complete = filled == widget.letters.length;
    final cols = widget.boardShape == '2x2' ? 2 : 4;
    final rows = widget.boardShape == '2x2' ? 2 : 1;
    final boardWidth = cols == 4 ? 460.0 : 260.0;

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
          child: const Text('키캡 색을 선택하세요', style: AppTextStyles.heading),
        ),
        const SizedBox(height: 8),
        _Fade(
          opacity: _subtitleOpacity,
          child: const Text(
            '칸을 탭하거나 숫자 1~4로 색상 선택  ·  화살표 → 이동  ·  ENTER로 디자인 확인',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 40),
        _FadeSlideY(
          opacity: _plateOpacity,
          y: _plateY,
          child: Stack(
            children: [
              Positioned(
                left: -8,
                top: -8,
                child: Container(width: boardWidth, height: rows == 2 ? boardWidth : 150, color: AppColors.yellow),
              ),
              Container(
                width: boardWidth,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.ink, width: 2)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(rows, (r) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(cols, (c) {
                          final i = r * cols + c;
                          final isCursor = i == widget.cursor;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.stockLoading || widget.onCellTap == null
                                  ? null
                                  : () => widget.onCellTap!(i),
                              child: _KeycapCell(
                                isCursor: isCursor,
                                color: widget.colorAt(i),
                                letter: widget.letters[i],
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
        const SizedBox(height: 32),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FadeSlideX(
              opacity: _colorListOpacity,
              x: _colorListX,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('색상 선택', style: AppTextStyles.body),
                  const SizedBox(height: 8),
                  _legendRow(1, 'g', KeycapColors.green, '초록'),
                  _legendRow(2, 'y', KeycapColors.yellow, '노랑'),
                  _legendRow(3, 'b', KeycapColors.blue, '파랑'),
                  _legendRow(4, 'r', KeycapColors.red, '빨강'),
                  const SizedBox(height: 8),
                  Text('$filled / ${widget.letters.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: 48),
            _FadeSlideX(
              opacity: _arrowsOpacity,
              x: _arrowsX,
              child: const _ArrowKeys(),
            ),
          ],
        ),
        if (widget.stockLoading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              '재고 확인 중...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          )
        else if (widget.message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ),
        const SizedBox(height: 32),
        _FadeSlideY(
          opacity: _buttonOpacity,
          y: _buttonY,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.stockLoading ? null : widget.onSubmit,
            child: Container(
              width: boardWidth,
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              color: complete ? AppColors.ink : AppColors.muted,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: Colors.white,
                    child: const Text('ENTER', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    complete ? '엔터로 디자인 확인' : '색을 모두 선택하세요',
                    style: TextStyle(color: complete ? AppColors.green : Colors.white70, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendRow(
    int digit,
    String colorCode,
    Color color,
    String name,
  ) {
    final isSoldOut = widget.soldOutColors.contains(colorCode);
    final num = '$digit';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (widget.stockLoading || isSoldOut || widget.onColorTap == null)
          ? null
          : () => widget.onColorTap!(digit),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // 번호 칸은 항상 같은 크기 유지
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSoldOut ? Colors.grey.shade300 : Colors.transparent,
                border: Border.all(
                  color: isSoldOut ? Colors.grey.shade500 : AppColors.ink,
                  width: 2,
                ),
              ),
              child: Text(
                num,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isSoldOut ? Colors.grey.shade600 : AppColors.ink,
                ),
              ),
            ),

            const SizedBox(width: 14),

            // 색상 표시
            Container(
              width: 36,
              height: 36,
              color: isSoldOut ? Colors.grey.shade400 : color,
            ),

            const SizedBox(width: 14),

            // 색상 이름
            SizedBox(
              width: 70,
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: isSoldOut ? Colors.grey.shade600 : AppColors.ink,
                ),
              ),
            ),

            // 품절 표시
            if (isSoldOut)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '재고 없음',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
          ],
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

class _KeycapCell extends StatefulWidget {
  final bool isCursor;
  final Color color;
  final String letter;

  const _KeycapCell({required this.isCursor, required this.color, required this.letter});

  @override
  State<_KeycapCell> createState() => _KeycapCellState();
}

class _KeycapCellState extends State<_KeycapCell> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.07), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.07, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    if (widget.isCursor) _pulseController.repeat();
  }

  @override
  void didUpdateWidget(covariant _KeycapCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCursor && !oldWidget.isCursor) {
      _pulseController.repeat();
    } else if (!widget.isCursor && oldWidget.isCursor) {
      _pulseController.stop();
      _pulseController.value = 0;
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
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isCursor ? _pulseScale.value : 1.0,
          child: Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.color,
              border: Border.all(color: widget.isCursor ? AppColors.ink : Colors.transparent, width: 3),
            ),
            child: Text(
              widget.letter,
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
            ),
          ),
        );
      },
    );
  }
}

class _ArrowKeys extends StatelessWidget {
  const _ArrowKeys();

  @override
  Widget build(BuildContext context) {
    Widget key(IconData icon) => Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          margin: const EdgeInsets.all(2),
          decoration:
              BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
          child: Icon(icon, size: 18),
        );
    return Column(
      children: [
        key(Icons.arrow_upward),
        Row(children: [
          key(Icons.arrow_back),
          key(Icons.arrow_downward),
          key(Icons.arrow_forward)
        ]),
      ],
    );
  }
}
