import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class _Iso {
  const _Iso({this.rotX = 58, this.rotZ = -44, this.scale = 0.86});
  final double rotX, rotZ, scale;

  Offset p(double x, double y, double z) {
    const d = pi / 180;
    final rz = rotZ * d, rx = rotX * d;
    final xr = x * cos(rz) - y * sin(rz);
    final yr = x * sin(rz) + y * cos(rz);
    return Offset(xr * scale, (yr * cos(rx) - z * sin(rx)) * scale);
  }
}

class KeycapBoardPainter extends CustomPainter {
  KeycapBoardPainter({
    required this.letters,
    required this.colors,
    this.mountedCount = 4,
    this.dropProgress,
    this.viewScale = 1.0,
  }) : iso = _Iso(scale: 0.86 * viewScale);

  final List<String> letters;
  final List<Color> colors;
  final int mountedCount;
  final double? dropProgress;
  final double viewScale;
  final _Iso iso;

  static const double capBase = 88, capTop = 68, capH = 52, inset = 10;
  static const double bw = 420, bd = 120, bh = 26, gap = 100;

  void _quad(Canvas c, List<Offset> pts, Color color) {
    c.drawPath(
      Path()..addPolygon(pts, true),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  void _stroke(Canvas c, List<Offset> pts, double width) {
    c.drawPath(
      Path()..addPolygon(pts, true),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.55)
        ..isAntiAlias = true,
    );
  }

  void _paintProjectedLetter(
    Canvas c,
    String letter,
    Offset Function(double, double, double) p, {
    required double centerX,
    required double centerY,
    required double z,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: letter,
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w900,
          color: AppColors.text,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final center = p(centerX, centerY, z);

    final px = p(centerX + 1, centerY, z);
    final py = p(centerX, centerY + 1, z);

    final xAxis = px - center;
    final yAxis = py - center;

    c.save();

    c.translate(center.dx, center.dy);

    c.transform(
      Float64List.fromList([
        xAxis.dx,
        xAxis.dy,
        0,
        0,
        yAxis.dx,
        yAxis.dy,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
      ]),
    );

    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));

    c.restore();
  }

  void _board(Canvas c) {
    Offset q(double a, double b, double k) => iso.p(a - 16, b - 16, k);
    // 보이는 면은 앞면(+y) · 왼쪽 끝면(-x) · 윗면 세 개뿐입니다.
    _quad(c, [
      q(0, bd, 0),
      q(bw, bd, 0),
      q(bw, bd, bh),
      q(0, bd, bh),
    ], AppColors.boardSide);
    _quad(c, [
      q(0, 0, 0),
      q(0, bd, 0),
      q(0, bd, bh),
      q(0, 0, bh),
    ], AppColors.boardEdge);
    _quad(c, [
      q(0, 0, bh),
      q(bw, 0, bh),
      q(bw, bd, bh),
      q(0, bd, bh),
    ], AppColors.boardTop);
  }

  void _socket(Canvas c, int i) {
    Offset p(double a, double b) => iso.p(i * gap + inset + a, inset + b, bh);
    _quad(c, [
      p(0, 0),
      p(capTop, 0),
      p(capTop, capTop),
      p(0, capTop),
    ], AppColors.boardSide);
  }

  void _cap(Canvas c, int i, double z, Color color, String letter) {
    Offset p(double a, double b, double k) => iso.p(i * gap + a, b, z + k);
    const t = inset;
    _quad(c, [
      p(0, capBase, 0),
      p(capBase, capBase, 0),
      p(capBase - t, capBase - t, capH),
      p(t, capBase - t, capH),
    ], color);
    _quad(c, [
      p(0, 0, 0),
      p(0, capBase, 0),
      p(t, capBase - t, capH),
      p(t, t, capH),
    ], color); // ← x=0 (가이드는 x=capBase)
    final top = <Offset>[
      p(t, t, capH),
      p(capBase - t, t, capH),
      p(capBase - t, capBase - t, capH),
      p(t, capBase - t, capH),
    ];
    _quad(c, top, color);
    // 윗면 테두리 — 이게 없으면 옆면과 구분되지 않아 납작해 보입니다.
    _stroke(c, top, 2 * viewScale);

    _paintProjectedLetter(
      c,
      letter,
      p,
      centerX: capBase / 2,
      centerY: capBase / 2,
      z: capH,
    );
  }

  @override
  void paint(Canvas c, Size size) {
    c.save();
    final center = iso.p(bw / 2 - 16, bd / 2 - 16, bh / 2);
    c.translate(size.width / 2 - center.dx, size.height / 2 - center.dy);

    _board(c);
    for (var i = mountedCount; i < 4; i++) {
      _socket(c, i);
    }
    // 뒤(index 3) → 앞(index 0) 순서라야 앞 키캡이 뒤를 가립니다.
    for (var i = 3; i >= 0; i--) {
      final dropping = dropProgress != null && i == mountedCount;
      if (i >= mountedCount && !dropping) continue;
      final z = dropping ? bh + 105 * (1 - dropProgress!) : bh;
      _cap(c, i, z, colors[i], letters[i]);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(KeycapBoardPainter old) =>
      old.dropProgress != dropProgress ||
      old.mountedCount != mountedCount ||
      old.viewScale != viewScale;
}

class KeycapBoard3D extends StatefulWidget {
  const KeycapBoard3D({
    super.key,
    required this.mbti,
    required this.colors,
    this.mountedCount = 4,
    this.animateDrop = false,
    this.viewScale = 1.0,
  });

  final String mbti;
  final List<String> colors; // ['g','y','b','r']
  final int mountedCount;
  final bool animateDrop;
  final double viewScale;

  @override
  State<KeycapBoard3D> createState() => _KeycapBoard3DState();
}

class _KeycapBoard3DState extends State<KeycapBoard3D>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animateDrop) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3400),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Color _color(String name) => switch (name) {
    'g' || 'green' => AppColors.green,
    'y' || 'yellow' => AppColors.yellow,
    'b' || 'blue' => AppColors.blue,
    'r' || 'pink' => AppColors.pink,
    _ => AppColors.border,
  };

  @override
  Widget build(BuildContext context) {
    final letters = widget.mbti.padRight(4, '-').substring(0, 4).split('');
    final colors = List.generate(
      4,
      (i) => _color(i < widget.colors.length ? widget.colors[i] : ''),
    );

    CustomPaint buildPaint(double? progress) => CustomPaint(
      size: Size.infinite,
      painter: KeycapBoardPainter(
        letters: letters,
        colors: colors,
        mountedCount: widget.mountedCount,
        dropProgress: progress,
        viewScale: widget.viewScale,
      ),
    );

    final c = _controller;
    if (c == null) return buildPaint(null);

    return AnimatedBuilder(
      animation: c,
      builder: (_, __) => buildPaint(
        c.value < 0.55 ? Curves.easeInOut.transform(c.value / 0.55) : 1.0,
      ),
    );
  }
}
