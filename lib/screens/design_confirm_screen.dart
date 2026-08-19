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

  final List<String?> colorCodes;
  final Map<String, Color> keycapColorOptions;
  final Set<String> soldOutKeycaps;

  final String axis;
  final Map<String, String> axisLabels; // 예: 청축 / 갈축 / 적축 / 흑축
  final Map<String, Color> axisColors;
  final Set<String> soldOutAxes;

  final bool isSubmitting; // true면 주문 전송 중 — Enter/ESC 힌트를 비활성 표시로 바꿈
  final VoidCallback? onConfirm; // 터치 지원: ENTER(접수하기) 탭
  final VoidCallback? onCancel; // 터치 지원: ESC(다시 만들기) 탭

  final Future<bool> Function(int index, String colorCode) onKeycapColorChanged;

  final Future<bool> Function(String axis) onAxisChanged;

  final bool stockLoading;
  final String? message;

  const DesignConfirmScreen({
    super.key,
    required this.boardShape,
    required this.letters,
    required this.colorAt,
    required this.colorCodes,
    required this.keycapColorOptions,
    required this.soldOutKeycaps,
    required this.axis,
    required this.axisLabels,
    required this.axisColors,
    required this.soldOutAxes,
    required this.onKeycapColorChanged,
    required this.onAxisChanged,
    required this.stockLoading,
    required this.message,
    required this.isSubmitting,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<DesignConfirmScreen> createState() => _DesignConfirmScreenState();
}

class _DesignConfirmScreenState extends State<DesignConfirmScreen>
    with TickerProviderStateMixin {
  static const int _durationMs = 750;

  // 어떤 MBTI 키캡의 색상을 수정 중인지
  int? _editingKeycapIndex;

  // 색상 선택창 Overlay
  OverlayEntry? _colorOverlay;

// 키캡마다 위치를 잡기 위한 LayerLink
  late List<LayerLink> _keycapLinks;

  // 축 선택창이 열렸는지
  bool _axisSelectorOpen = false;

  bool _changing = false;

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
    _keycapLinks = List.generate(
      widget.letters.length,
      (_) => LayerLink(),
    );
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _durationMs),
    );

    Animation<double> fadeIn(double s, double e) => CurvedAnimation(
          parent: _controller,
          curve:
              Interval(s / _durationMs, e / _durationMs, curve: Curves.easeOut),
        );
    Animation<double> slideY(double s, double e, double from) =>
        Tween<double>(begin: from, end: 0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(s / _durationMs, e / _durationMs,
                curve: Curves.easeOut),
          ),
        );
    Animation<double> springScale(double s, double e, double from) =>
        Tween<double>(begin: from, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(s / _durationMs, e / _durationMs,
                curve: Curves.easeOutBack),
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
    _colorOverlay?.remove();
    _colorOverlay = null;
    _controller.dispose();
    super.dispose();
  }

  void _closeColorSelector() {
    _colorOverlay?.remove();
    _colorOverlay = null;

    if (mounted) {
      setState(() {
        _editingKeycapIndex = null;
      });
    }
  }

  void _openColorSelector(int index) {
    // 이미 같은 키캡 선택창이 열려 있으면 닫기
    if (_editingKeycapIndex == index) {
      _closeColorSelector();
      return;
    }

    // 기존 Overlay 제거
    _colorOverlay?.remove();
    _colorOverlay = null;

    setState(() {
      _editingKeycapIndex = index;
      _axisSelectorOpen = false;
    });

    _colorOverlay = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Stack(
            children: [
              // 바깥쪽 터치 영역
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeColorSelector,
                child: const SizedBox.expand(),
              ),

              CompositedTransformFollower(
                link: _keycapLinks[index],
                showWhenUnlinked: false,

                // 키캡 아래에 표시
                targetAnchor: Alignment.bottomCenter,
                followerAnchor: Alignment.topCenter,

                offset: const Offset(0, 12),

                child: Material(
                  color: Colors.transparent,
                  child: _buildColorSelector(),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_colorOverlay!);
  }

  Widget _buildColorSelector() {
    final index = _editingKeycapIndex!;

    final letter = widget.letters[index];
    final currentColor = widget.colorCodes[index];

    const order = ['g', 'y', 'b', 'r'];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppColors.ink,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: order.map((code) {
          final color = widget.keycapColorOptions[code]!;

          final soldOut = widget.soldOutKeycaps.contains('${letter}_$code');

          final selected = currentColor == code;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: soldOut || _changing || widget.stockLoading
                  ? null
                  : () async {
                      setState(() {
                        _changing = true;
                      });

                      final changed = await widget.onKeycapColorChanged(
                        index,
                        code,
                      );

                      if (!mounted) return;

                      setState(() {
                        _changing = false;
                      });

                      if (changed) {
                        _closeColorSelector();
                      }
                    },
              child: Opacity(
                opacity: soldOut ? 0.25 : 1,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(9),
                    border: selected
                        ? Border.all(
                            color: AppColors.ink,
                            width: 3,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.65),
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAxisSelector() {
    const axisOrder = [
      'blue',
      'red',
      'brown',
      'black',
    ];

    // 현재 선택된 축은 목록에서 제외
    final availableAxes =
        axisOrder.where((axis) => axis != widget.axis).toList();

    return Container(
      width: 330,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppColors.ink,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: List.generate(
          availableAxes.length,
          (index) {
            final axis = availableAxes[index];

            final soldOut = widget.soldOutAxes.contains(axis);

            return Column(
              children: [
                GestureDetector(
                  onTap: soldOut || _changing || widget.stockLoading
                      ? null
                      : () async {
                          setState(() {
                            _changing = true;
                          });

                          final changed = await widget.onAxisChanged(axis);

                          if (!mounted) return;

                          setState(() {
                            _changing = false;

                            // 변경 성공하면 선택창 닫기
                            if (changed) {
                              _axisSelectorOpen = false;
                            }
                          });
                        },
                  child: Opacity(
                    opacity: soldOut ? 0.25 : 1,
                    child: Container(
                      height: 92,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: widget.axisColors[axis] ?? AppColors.ink,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Text(
                            widget.axisLabels[axis] ?? axis,
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const Spacer(),
                          if (soldOut)
                            const Text(
                              '품절',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (index != availableAxes.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                  ),
              ],
            );
          },
        ),
      ),
    );
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
          child: const Text('STEP 05 / 06', style: AppTextStyles.label),
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
            '마음에 들면 ENTER(탭), 다시 고르려면 ESC(탭)',
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
            clipBehavior: Clip.none,
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
                            child: CompositedTransformTarget(
                              link: _keycapLinks[i],
                              child: GestureDetector(
                                onTap: widget.isSubmitting || _changing
                                    ? null
                                    : () {
                                        _openColorSelector(i);
                                      },
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: widget.colorAt(i),

                                    // 현재 수정 중인 키캡 표시
                                    border: _editingKeycapIndex == i
                                        ? Border.all(
                                            color: AppColors.ink,
                                            width: 4,
                                          )
                                        : null,
                                  ),
                                  child: Text(
                                    widget.letters[i],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
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
        const SizedBox(height: 72),
        _FadeSlideY(
          opacity: _axisOpacity,
          y: _axisY,
          child: GestureDetector(
            // onTap: widget.isSubmitting || _changing
            //     ? null
            //     : () {
            //         setState(() {
            //           // 열려 있으면 닫고, 닫혀 있으면 열기
            //           _axisSelectorOpen = !_axisSelectorOpen;

            //           // 키캡 색상 선택창은 닫기
            //           _editingKeycapIndex = null;
            //         });
            //       },
            onTap: null, // 축 종류 변경 버튼 block 처리
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.ink,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '축',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 28,
                    height: 28,
                    color: widget.axisColors[widget.axis] ?? AppColors.ink,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    widget.axisLabels[widget.axis] ?? '-',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(
                    _axisSelectorOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.ink,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_axisSelectorOpen) ...[
          const SizedBox(height: 8),
          _buildAxisSelector(),
        ],
        const SizedBox(height: 32),
        _FadeSlideY(
          opacity: _hintOpacity,
          y: _hintY,
          child: widget.isSubmitting
              ? const _SubmittingIndicator()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onConfirm,
                      child: _KeyHint(
                          keyLabel: 'ENTER',
                          text: '접수하기',
                          accent: AppColors.green),
                    ),
                    const SizedBox(width: 32),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onCancel,
                      child: _KeyHint(
                          keyLabel: 'ESC',
                          text: '다시 만들기',
                          accent: AppColors.coral),
                    ),
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
  const _FadeSlideY(
      {required this.opacity, required this.y, required this.child});

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

// 주문 전송 중일 때 ENTER/ESC 힌트 대신 보여주는 비활성 표시.
// 이 상태에서는 main.dart가 Enter/Esc 입력을 아예 무시하도록 되어 있어서,
// 같은 주문이 중복으로 전송되는 것을 막습니다.
class _SubmittingIndicator extends StatelessWidget {
  const _SubmittingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration:
          BoxDecoration(border: Border.all(color: AppColors.muted, width: 2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: AppColors.muted),
          ),
          const SizedBox(width: 14),
          Text(
            '주문을 접수하고 있어요...',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  final String keyLabel;
  final String text;
  final Color accent;
  const _KeyHint(
      {required this.keyLabel, required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration:
          BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: AppColors.muted,
            child: Text(
              keyLabel,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Text(text,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: accent)),
        ],
      ),
    );
  }
}
