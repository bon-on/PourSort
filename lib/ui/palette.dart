import 'dart:math';

import 'package:flutter/material.dart';

const List<Color> kSegmentColors = [
  Color(0xFFE53935), // red
  Color(0xFF1E88E5), // blue
  Color(0xFF43A047), // green
  Color(0xFFFDD835), // yellow
  Color(0xFFFB8C00), // orange
  Color(0xFF8E24AA), // purple
  Color(0xFF00ACC1), // cyan
  Color(0xFFF48FB1), // pink
  Color(0xFF8D6E63), // brown
  Color(0xFFC0CA33), // lime
];

/// Draws a distinct symbol per color so colors can be told apart without hue.
void paintSymbol(Canvas canvas, int color, Offset c, double r, Color ink) {
  final fill = Paint()..color = ink;
  final stroke = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.28
    ..strokeCap = StrokeCap.round;
  Path poly(int sides, double rot) {
    final p = Path();
    for (var i = 0; i < sides; i++) {
      final a = rot + i * 2 * pi / sides;
      final pt = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  switch (color % 10) {
    case 0: // circle
      canvas.drawCircle(c, r * 0.85, fill);
    case 1: // square
      canvas.drawRect(Rect.fromCircle(center: c, radius: r * 0.75), fill);
    case 2: // triangle
      canvas.drawPath(poly(3, -pi / 2), fill);
    case 3: // diamond
      canvas.drawPath(poly(4, -pi / 2), fill);
    case 4: // star
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final rad = i.isEven ? r * 1.05 : r * 0.45;
        final a = -pi / 2 + i * pi / 5;
        final pt = Offset(c.dx + rad * cos(a), c.dy + rad * sin(a));
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(p..close(), fill);
    case 5: // plus
      canvas.drawLine(
        c.translate(-r * 0.8, 0),
        c.translate(r * 0.8, 0),
        stroke,
      );
      canvas.drawLine(
        c.translate(0, -r * 0.8),
        c.translate(0, r * 0.8),
        stroke,
      );
    case 6: // ring
      canvas.drawCircle(c, r * 0.65, stroke);
    case 7: // cross
      canvas.drawLine(
        c.translate(-r * 0.65, -r * 0.65),
        c.translate(r * 0.65, r * 0.65),
        stroke,
      );
      canvas.drawLine(
        c.translate(-r * 0.65, r * 0.65),
        c.translate(r * 0.65, -r * 0.65),
        stroke,
      );
    case 8: // hexagon
      canvas.drawPath(poly(6, 0), fill);
    default: // bars
      for (final dx in [-0.5, 0.5]) {
        canvas.drawLine(
          c.translate(r * dx, -r * 0.8),
          c.translate(r * dx, r * 0.8),
          stroke,
        );
      }
  }
}

Color inkFor(Color bg) => bg.computeLuminance() > 0.45
    ? const Color(0xB3000000)
    : const Color(0xCCFFFFFF);
