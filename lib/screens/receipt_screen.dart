import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// [신규] 영수증 페이지 — 6단계(STEP 01~06) 밖의 별도 화면
///
/// [수정] 예전에는 축(스위치) 선택 화면이 빠지면서 비게 된 "06" 자리를
/// 영수증이 대신 채웠는데, 이제 보드 색상 선택이 정식 STEP 04로 편입되고
/// 키캡 채우기(05)·디자인 확인(06)이 한 칸씩 밀리면서 06 자리가 다시
/// 디자인 확인 화면 몫이 됐습니다. 그래서 영수증 화면은 STEP 표시를
/// 아예 빼고 6단계 밖의 화면으로 둡니다.
///
/// [디자인 교체] 시안 톤(흰 종이 · 연한 테두리 · 점선 구분)으로 다시 칠하고,
/// 가로형 4K 화면에 맞춰 QR과 주문 내역을 좌우로 배치했습니다.
/// 표시 내용·카운트다운·상태 갱신 동작은 이전과 동일합니다.
///
/// 순수하게 보여주기만 하는 화면입니다. 키보드 입력을 받지 않습니다.
/// 화면 안의 "N초 후 처음 화면으로 돌아갑니다" 문구는 표시용 카운트다운일
/// 뿐이며, 실제 자동 복귀는 main.dart의 타이머(_scheduleDoneRestart)가
/// 담당합니다.
///
/// 조립대 배정 상태는 main.dart가 주기적으로 서버에 재조회해서 넘겨주며,
/// complete_screen.dart와 같은 문구 방식으로 실시간 변화합니다.
///   - 대기 중         : "대기열 N번째"
///   - 배정됨          : "N번 조립대로 이동해주세요"
///   - 제작 중         : "N번 조립대에서 제작 중"
///   - 완료            : "제작 완료!"
///   - 주문 자체가 거부됨(대기열/조립대 가득 참) : "대기 중" + "스태프가 안내해 드립니다"
class ReceiptScreen extends StatefulWidget {
  final String orderNumber; // 표시용 주문번호. 없으면 '-'
  final String time; // 접수 시각 (예: '14:32')
  final String mbti;
  final List<Color> keycapColors;
  final List<String> keycapLabels; // 예: 파랑 / 초록 / 노랑 / 빨강
  final String statusHeadline; // "배정 조립대" 박스에 보여줄 큰 문구 (실시간으로 바뀜)
  final String? statusCaption; // 그 아래 작은 보조 문구 (필요할 때만)
  final bool isActive; // true=잉크 배경(배정/제작/완료), false=흐린 배경(대기/미배정)
  final Uint8List? qrBytes; // GET /order/{order_id}/qr 로 받아온 실제 QR 이미지
  final int autoRestartSeconds;

  const ReceiptScreen({
    super.key,
    required this.orderNumber,
    required this.time,
    required this.mbti,
    required this.keycapColors,
    required this.keycapLabels,
    required this.statusHeadline,
    this.statusCaption,
    required this.isActive,
    this.qrBytes,
    this.autoRestartSeconds = 8,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> with TickerProviderStateMixin {
  static const int _durationMs = 500;

  late final AnimationController _controller;
  late final Animation<double> _cardOpacity;
  late final Animation<double> _cardY;

  late int _secsLeft;
  Timer? _countdownTimer;

  // [디자인] 시안 팔레트 기준 영수증 색
  static const Color _paperColor = Color(0xFFFFFFFF);
  static const Color _dashColor = Color(0xFFD5D9DF);
  static const Color _labelColor = AppColors.muted;
  static const Color _ink = AppColors.ink;

  @override
  void initState() {
    super.initState();
    _secsLeft = widget.autoRestartSeconds;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _durationMs),
    );
    _cardOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _cardY = Tween<double>(begin: 44, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secsLeft > 0) _secsLeft -= 1;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_cardOpacity, _cardY]),
          builder: (context, child) => Opacity(
            opacity: _cardOpacity.value.clamp(0.0, 1.0),
            child: Transform.translate(offset: Offset(0, _cardY.value), child: child),
          ),
          child: Container(
            width: 1220,
            padding: const EdgeInsets.fromLTRB(52, 36, 52, 36),
            decoration: BoxDecoration(
              color: _paperColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.08),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '주문 영수증',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 34,
                    letterSpacing: 3,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '딸깍 키링 스튜디오',
                  style: TextStyle(fontSize: 22, color: _labelColor, letterSpacing: 1.2),
                ),
                const SizedBox(height: 22),
                const _DashedRule(color: _dashColor),
                const SizedBox(height: 26),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---- QR 자리 ----
                    // 실제 QR 이미지(qrBytes)가 있으면 그걸 보여주고,
                    // 아직 없거나(로딩 중) 받아오지 못했으면 자리표시자를 보여줌
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 224,
                          height: 224,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border, width: 2),
                          ),
                          child: widget.qrBytes != null
                              ? Image.memory(widget.qrBytes!,
                                  width: 188, height: 188, fit: BoxFit.contain)
                              : CustomPaint(
                                  size: const Size(128, 128),
                                  painter: _CheckerboardPainter(),
                                ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: 224,
                          child: Text(
                            widget.qrBytes != null ? '스캔하여 주문 상태 확인' : '주문 접수 처리 중...',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 19, color: _labelColor),
                          ),
                        ),
                        const SizedBox(height: 26),
                        const SizedBox(
                          width: 224,
                          child: Text(
                            '문제가 발생했다면\n주변의 스태프에게\n문의해주세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, height: 1.7, color: _labelColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 52),

                    // ---- 주문 정보 + 배정 상태 ----
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MetaRow(
                            label: '주문번호',
                            valueWidget: Text(
                              widget.orderNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 42,
                                letterSpacing: 4,
                                color: _ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _MetaRow(
                            label: '접수 시각',
                            valueWidget: Text(
                              widget.time,
                              style: const TextStyle(fontSize: 26, color: _ink),
                            ),
                          ),

                          const SizedBox(height: 20),
                          const _DashedRule(color: _dashColor),
                          const SizedBox(height: 20),

                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '주문 내역',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: _labelColor,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _MetaRow(
                            label: 'MBTI',
                            valueWidget: Text(
                              widget.mbti,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 30,
                                letterSpacing: 4,
                                color: _ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _MetaRow(
                            label: '키캡',
                            valueWidget: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(widget.keycapColors.length, (i) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 14),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: widget.keycapColors[i],
                                          borderRadius: BorderRadius.circular(9),
                                          border: Border.all(
                                            color: AppColors.ink.withValues(alpha: 0.14),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        widget.keycapLabels[i],
                                        style: const TextStyle(fontSize: 17, color: _labelColor),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 배정 조립대 상태 — main.dart가 주기적으로 상태를
                          // 다시 조회해서 넘겨주므로, 문구가 실시간으로 바뀝니다.
                          // (대기열 N번째 → N번 조립대로 이동해주세요 → 제작 중 → 완료)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 22,
                            ),
                            decoration: BoxDecoration(
                              color: widget.isActive
                                  ? AppColors.ink
                                  : const Color(0xFF6C727C),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  '배정 조립대',
                                  style: TextStyle(
                                    fontSize: 18,
                                    letterSpacing: 3,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFC3C8D0),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    widget.statusHeadline,
                                    key: ValueKey(widget.statusHeadline),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (widget.statusCaption != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.statusCaption!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Color(0xFFAEB4BE),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          '$_secsLeft초 후 처음 화면으로 돌아갑니다',
          style: const TextStyle(fontSize: 21, color: _labelColor),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final Widget valueWidget;
  const _MetaRow({required this.label, required this.valueWidget});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 23, color: AppColors.muted),
        ),
        valueWidget,
      ],
    );
  }
}

class _DashedRule extends StatelessWidget {
  final Color color;
  const _DashedRule({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 2),
      painter: _DashedLinePainter(color: color),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dashWidth = 9.0;
    const dashSpace = 8.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.border;
    const cells = 8;
    final cellSize = size.width / cells;
    for (int r = 0; r < cells; r++) {
      for (int c = 0; c < cells; c++) {
        if ((r + c).isEven) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
