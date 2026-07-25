// The Ankur sprout, drawn in Flutter so it can grow. [progress] 0→1 raises the
// stem, then unfurls the two leaves. Matches assets/branding/ankur_logo.svg.
//
// See docs/ANKUR_EXPERIENCE_ROADMAP.md — EX1.

import 'package:flutter/material.dart';

class SproutMark extends StatelessWidget {
  const SproutMark({
    required this.size,
    this.progress = 1,
    this.stroke = const Color(0xFFF4EEE2),
    this.leafLight = const Color(0xFF7CC67B),
    this.leafDark = const Color(0xFF2E7D32),
    super.key,
  });

  final double size;
  final double progress;
  final Color stroke;
  final Color leafLight;
  final Color leafDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SproutPainter(
          progress: progress.clamp(0, 1).toDouble(),
          stroke: stroke,
          leafLight: leafLight,
          leafDark: leafDark,
        ),
      ),
    );
  }
}

class _SproutPainter extends CustomPainter {
  _SproutPainter({
    required this.progress,
    required this.stroke,
    required this.leafLight,
    required this.leafDark,
  });

  final double progress;
  final Color stroke;
  final Color leafLight;
  final Color leafDark;

  @override
  void paint(Canvas canvas, Size size) {
    // Work in a 256x256 space, scaled to the widget.
    final s = size.width / 256.0;
    canvas.save();
    canvas.scale(s, s);

    final line = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;

    // Ground.
    final ground = Path()
      ..moveTo(84, 186)
      ..quadraticBezierTo(128, 172, 172, 186);
    canvas.drawPath(ground, line);

    // Stem grows first (0 → 0.6 of progress), from the ground up.
    final stemP = (progress / 0.6).clamp(0.0, 1.0);
    final topY = 186 - (186 - 92) * stemP;
    canvas.drawLine(const Offset(128, 186), Offset(128, topY), line);

    // Leaves unfurl after the stem (0.45 → 1.0), scaling from the stem.
    final leafP = ((progress - 0.45) / 0.55).clamp(0.0, 1.0);
    if (leafP > 0) {
      _leaf(canvas, _leftLeaf(), leafLight, const Offset(128, 130), leafP);
      _leaf(canvas, _rightLeaf(), leafDark, const Offset(128, 118), leafP);
    }
    canvas.restore();
  }

  void _leaf(Canvas canvas, Path path, Color color, Offset pivot, double t) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.scale(t, t);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  Path _leftLeaf() => Path()
    ..moveTo(128, 132)
    ..cubicTo(102, 136, 80, 120, 72, 92)
    ..cubicTo(102, 86, 124, 102, 128, 132)
    ..close();

  Path _rightLeaf() => Path()
    ..moveTo(128, 118)
    ..cubicTo(152, 104, 170, 72, 164, 42)
    ..cubicTo(132, 50, 116, 84, 128, 118)
    ..close();

  @override
  bool shouldRepaint(_SproutPainter old) => old.progress != progress;
}
