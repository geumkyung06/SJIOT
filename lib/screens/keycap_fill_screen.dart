import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STEP 05 — 키캡 색을 선택하세요
/// [디자인 교체] 시안 톤 — 판 위에 입체 키캡이 얹힙니다.
/// [세로 전환] 세로형 4K 화면(1080 x 1920 캔버스)에 맞춰, 예전에 판 오른쪽에
/// 세로 목록으로 있던 색상 선택지 4개를 판 "아래"에 가로 한 줄로 옮겼습니다.
/// 커서 이동·색상 적용·완료 처리 등 동작은 이전과 100% 동일합니다.
class KeycapFillScreen extends StatefulWidget {
  final String boardShape; // '1x4' 고정 (2x2 옵션은 팀 확정으로 제거됨. 파라미터는 하위 호환용으로 유지)
  final Color boardColor; // [신규] STEP 04에서 고른 판(케이스) 색상. 판 배경에 사용
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
    required this.boardColor,
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

  // [세로 전환] 보드 아래 가로 한 줄에 4칸이 들어가는 치수.
  // 196 * 4 + 24 * 3 = 856  (카드 본문 폭 872 안에 들어감)
  static const double _cardWidth = 196;
  static const double _cardGap = 24;

  late final AnimationController _controller;

  late final Animation<double> _labelOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleY;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _plateOpacity;
  late final Animation<double> _plateY;
  late final Animation<double> _colorListOpacity;
  late final Animation<double> _colorListY;
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
    _labelOpacity = fadeIn(40, 340);
    _titleOpacity = fadeIn(70, 370);
    _titleY = slideY(70, 370, 10);
    _subtitleOpacity = fadeIn(120, 420);
    _plateOpacity = fadeIn(160, 460);
    _plateY = slideY(160, 460, 12);
    _colorListOpacity = fadeIn(220, 520);
    // [세로 전환] 보드 아래로 내려왔으므로 등장도 가로(-10px) → 세로(12px) 슬라이드
    _colorListY = slideY(220, 520, 12);
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Fade(
          opacity: _labelOpacity,
          child: const Text('STEP 05 / 06', style: AppTextStyles.label),
        ),
        const SizedBox(height: 18),
        _FadeSlideY(
          opacity: _titleOpacity,
          y: _titleY,
          child: const Text('키캡 색을 선택하세요', style: AppTextStyles.heading),
        ),
        const SizedBox(height: 14),
        _Fade(
          opacity: _subtitleOpacity,
          child: const Text(
            '칸을 탭하거나 숫자 1~4로 색상 선택',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 52),
        // ---- 판 + 키캡 ----
        _FadeSlideY(
          opacity: _plateOpacity,
          y: _plateY,
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: widget.boardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.ink.withValues(alpha: 0.12), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(rows, (r) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(cols, (c) {
                      final i = r * cols + c;
                      final isCursor = i == widget.cursor;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
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
        ),
        const SizedBox(height: 44),
        // ---- 색상 선택: 보드 그림 "아래"에 가로 한 줄 4칸 ----
        // [세로 전환] 예전에는 보드 오른쪽에 세로 목록으로 붙어 있었지만,
        // 세로 캔버스(1080 x 1920)에서는 좌우 폭이 모자라서 보드 아래로 내리고
        // 보드의 키캡 4개와 개수·방향이 맞게 가로 한 줄로 폈습니다.
        // 폭 계산: _cardWidth(196) * 4 + _cardGap(24) * 3 = 856 <= 본문 폭 872
        _FadeSlideY(
          opacity: _colorListOpacity,
          y: _colorListY,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('색상 선택', style: AppTextStyles.body),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _colorCard(1, 'g', KeycapColors.green, '초록'),
                  const SizedBox(width: _cardGap),
                  _colorCard(2, 'y', KeycapColors.yellow, '노랑'),
                  const SizedBox(width: _cardGap),
                  _colorCard(3, 'b', KeycapColors.blue, '파랑'),
                  const SizedBox(width: _cardGap),
                  // [수정] 색상 코드('r')는 그대로 유지하되, 실제 색상이 빨강→핑크로
                  // 바뀌었으므로 화면에 보이는 한글 이름만 '핑크'로 표시합니다.
                  _colorCard(4, 'r', KeycapColors.red, '핑크'),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '$filled / ${widget.letters.length}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        if (widget.stockLoading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text(
              '재고 확인 중...',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.muted),
            ),
          )
        else if (widget.message != null)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.danger),
            ),
          ),
        const SizedBox(height: 44),
        _FadeSlideY(
          opacity: _buttonOpacity,
          y: _buttonY,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.stockLoading ? null : widget.onSubmit,
            child: Container(
              width: 760,
              padding: const EdgeInsets.symmetric(vertical: 26),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: complete ? AppColors.ink : AppColors.border,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                complete ? '디자인 확인' : '색을 모두 선택하세요',
                style: TextStyle(
                  fontSize: 27,
                  color: complete ? Colors.white : AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// [세로 전환] 보드 아래 가로 한 줄에 놓이는 색상 선택 카드.
  /// 예전 세로 목록(_legendRow)을 대체하며, 번호 배지 · 색상 칩 · 이름을
  /// 세로로 쌓습니다. 탭 동작(onColorTap)과 품절 처리는 이전과 동일합니다.
  Widget _colorCard(
    int digit,
    String colorCode,
    Color color,
    String name,
  ) {
    final isSoldOut = widget.soldOutColors.contains(colorCode);
    final tappable =
        !(widget.stockLoading || isSoldOut || widget.onColorTap == null);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tappable ? () => widget.onColorTap!(digit) : null,
      child: Container(
        width: _cardWidth,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: AppDeco.outlined(
          radius: 18,
          borderColor: isSoldOut ? AppColors.disabledLine : AppColors.border,
          fill: isSoldOut ? AppColors.disabledBg : AppColors.surface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 번호 배지 (숫자 키 1~4와 대응)
            KeyNumBadge(
              label: '$digit',
              disabled: isSoldOut,
              size: 50,
              fontSize: 24,
            ),
            const SizedBox(height: 16),
            // 색상 칩 — 세로 배치라 가로 목록보다 크게 키웠습니다(46 → 84)
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: isSoldOut ? AppColors.disabledBg : color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSoldOut
                      ? AppColors.disabledLine
                      : AppColors.ink.withValues(alpha: 0.14),
                  width: 2,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                color: isSoldOut ? AppColors.disabledText : AppColors.ink,
              ),
            ),
            if (isSoldOut) ...[
              const SizedBox(height: 10),
              const SoldOutPill(),
            ],
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

/// [디자인] 커서가 놓인 칸은 살짝 커졌다 작아지는 펄스 + 두꺼운 잉크 테두리.
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
          child: Keycap(
            color: widget.color,
            letter: widget.letter,
            selected: widget.isCursor,
            empty: widget.color == AppColors.tileEmpty,
          ),
        );
      },
    );
  }
}
