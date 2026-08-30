import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// [신규] 영수증 페이지 — 6단계(STEP 01~06) 밖의 별도 화면
///
/// [수정] 예전에는 축(스위치) 선택 화면이 빠지면서 비게 된 "06" 자리를
/// 영수증이 대신 채웠는데, 이제 보드 색상 선택이 정식 STEP 04로 편입되고
/// 키캡 채우기(05)·디자인 확인(06)이 한 칸씩 밀리면서 06 자리가 다시
/// 디자인 확인 화면 몫이 됐습니다. 그래서 영수증 화면은 STEP 표시를
/// 아예 빼고 6단계 밖의 화면으로 둡니다.
///
/// 순수하게 보여주기만 하는 화면입니다. 키보드 입력을 받지 않습니다.
/// 화면 안의 "N초 후 처음 화면으로 돌아갑니다" 문구는 표시용 카운트다운일
/// 뿐이며, 실제 자동 복귀는 main.dart의 타이머(_scheduleDoneRestart)가
/// 담당합니다. (두 타이머는 화면 진입과 거의 동시에 함께 시작되므로
/// 화면에 보이는 숫자와 실제 복귀 시점은 사실상 일치합니다.)
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
  final bool isActive; // true=검정 배경(배정/제작/완료), false=옅은 갈색(대기/미배정)
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

  static const Color _paperColor = Color(0xFFFAF7F2);
  static const Color _outerColor = Color(0xFFE8E2D9);
  static const Color _dashColor = Color(0xFFB0A898);
  static const Color _labelColor = Color(0xFF8A7E72);
  static const Color _ink = Color(0xFF1A1A1A);

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
    return Container(
      width: double.infinity,
      color: _outerColor,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // [수정] 영수증 화면은 더 이상 STEP 표시에 포함하지 않습니다
          // (전체 6단계는 mbtiChoice~designConfirm까지이고, 영수증은 그 이후
          // 별도 화면입니다). 카드 등장 애니메이션 타이밍은 그대로 유지하기
          // 위해 라벨 대신 동일한 높이의 빈 여백만 둡니다.
          AnimatedBuilder(
            animation: _cardOpacity,
            builder: (context, child) => Opacity(opacity: _cardOpacity.value.clamp(0.0, 1.0), child: child),
            child: const SizedBox(height: 30),
          ),
          AnimatedBuilder(
            animation: Listenable.merge([_cardOpacity, _cardY]),
            builder: (context, child) => Opacity(
              opacity: _cardOpacity.value.clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, _cardY.value), child: child),
            ),
            child: SizedBox(
              width: 360,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: _paperColor,
                    padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                    child: Column(
                      children: [
                        const Text(
                          '주문 영수증',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1.4,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '딸깍 키링 스튜디오',
                          style: TextStyle(fontSize: 12, color: _labelColor, letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 18),
                        const _DashedRule(color: _dashColor),
                        const SizedBox(height: 18),

                        // QR 자리 — 실제 QR 이미지(qrBytes)가 있으면 그걸 보여주고,
                        // 아직 없거나(로딩 중) 받아오지 못했으면 자리표시자를 보여줌
                        Container(
                          width: 140,
                          height: 140,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0EBE3),
                            border: Border.all(color: _dashColor, width: 1.5),
                          ),
                          child: widget.qrBytes != null
                              ? Image.memory(widget.qrBytes!, width: 120, height: 120, fit: BoxFit.contain)
                              : CustomPaint(
                                  size: const Size(80, 80),
                                  painter: _CheckerboardPainter(),
                                ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.qrBytes != null ? '스캔하여 주문 상태 확인' : '주문 접수 처리 중...',
                          style: const TextStyle(fontSize: 10, color: _labelColor),
                        ),
                        const SizedBox(height: 18),
                        const _DashedRule(color: _dashColor),
                        const SizedBox(height: 16),

                        _MetaRow(
                          label: '주문번호',
                          valueWidget: Text(
                            widget.orderNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              letterSpacing: 2,
                              color: _ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _MetaRow(
                          label: '접수 시각',
                          valueWidget: Text(widget.time, style: const TextStyle(fontSize: 14, color: _ink)),
                        ),

                        const SizedBox(height: 16),
                        const _DashedRule(color: _dashColor),
                        const SizedBox(height: 16),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '주문 내역',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: _labelColor,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        _MetaRow(
                          label: 'MBTI',
                          valueWidget: Text(
                            widget.mbti,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 2,
                              color: _ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _MetaRow(
                          label: '키캡',
                          valueWidget: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(widget.keycapColors.length, (i) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Column(
                                  children: [
                                    Container(width: 22, height: 22, color: widget.keycapColors[i]),
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.keycapLabels[i],
                                      style: const TextStyle(fontSize: 9, color: _labelColor),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),

                        const SizedBox(height: 16),
                        const _DashedRule(color: _dashColor),
                        const SizedBox(height: 16),

                        // 배정 조립대 상태 — main.dart가 주기적으로 상태를
                        // 다시 조회해서 넘겨주므로, 문구가 실시간으로 바뀝니다.
                        // (대기열 N번째 → N번 조립대로 이동해주세요 → 제작 중 → 완료)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                          margin: const EdgeInsets.only(bottom: 16),
                          color: widget.isActive ? _ink : const Color(0xFF3A3530),
                          child: Column(
                            children: [
                              const Text(
                                '배정 조립대',
                                style: TextStyle(fontSize: 9, letterSpacing: 1.6, color: Color(0xFFA09488)),
                              ),
                              const SizedBox(height: 6),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  widget.statusHeadline,
                                  key: ValueKey(widget.statusHeadline),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFE8E2D9),
                                  ),
                                ),
                              ),
                              if (widget.statusCaption != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  widget.statusCaption!,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF7A6E68)),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.only(bottom: 28),
                          child: Text(
                            '문제가 발생했다면\n주변의 스태프에게 문의해주세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, height: 1.6, color: _dashColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 찢어진 하단 마감 (톱니 모양)
                  CustomPaint(
                    size: const Size(double.infinity, 14),
                    painter: _TornEdgePainter(paperColor: _paperColor, bgColor: _outerColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('$_secsLeft초 후 처음 화면으로 돌아갑니다', style: const TextStyle(fontSize: 12, color: _labelColor)),
        ],
      ),
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
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8A7E72))),
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
      size: const Size(double.infinity, 1.5),
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
      ..strokeWidth = 1.5;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
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
    final paint = Paint()..color = const Color(0xFF1A1A1A);
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

class _TornEdgePainter extends CustomPainter {
  final Color paperColor;
  final Color bgColor;
  _TornEdgePainter({required this.paperColor, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    const step = 12.0;
    final paperPaint = Paint()..color = paperColor;
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paperPaint);
    double x = 0;
    bool toggle = false;
    while (x < size.width) {
      if (toggle) {
        canvas.drawRect(Rect.fromLTWH(x, 0, step / 2, size.height), bgPaint);
      }
      x += step / 2;
      toggle = !toggle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
