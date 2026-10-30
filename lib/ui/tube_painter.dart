import 'package:flutter/material.dart';

import '../logic/pour_game.dart';
import 'palette.dart';

/// One drawn segment: a color index and a vertical scale (0..1) for animation.
class SegmentView {
  const SegmentView(this.color, [this.scale = 1]);
  final int color;
  final double scale;
}

class TubePainter extends CustomPainter {
  TubePainter({
    required this.segments,
    required this.segmentHeight,
    required this.selected,
    required this.complete,
  });

  final List<SegmentView> segments;
  final double segmentHeight;
  final bool selected;
  final bool complete;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final radius = Radius.circular(w / 2);
    final body = RRect.fromRectAndCorners(
      Offset.zero & size,
      bottomLeft: radius,
      bottomRight: radius,
      topLeft: const Radius.circular(6),
      topRight: const Radius.circular(6),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0x14FFFFFF));

    canvas.save();
    canvas.clipRRect(body.deflate(2));
    var y = size.height - 2;
    for (final s in segments) {
      final h = segmentHeight * s.scale;
      if (h <= 0) continue;
      final rect = Rect.fromLTWH(0, y - h, w, h);
      final color = kSegmentColors[s.color % kSegmentColors.length];
      canvas.drawRect(rect, Paint()..color = color);
      canvas.drawRect(
        Rect.fromLTWH(0, y - h, w, 1.5),
        Paint()..color = const Color(0x33000000),
      );
      if (s.scale > 0.6) {
        paintSymbol(
          canvas,
          s.color,
          rect.center,
          (w * 0.17) * s.scale,
          inkFor(color),
        );
      }
      y -= h;
    }
    canvas.restore();

    // glass highlight
    canvas.drawRect(
      Rect.fromLTWH(w * 0.14, 8, w * 0.07, size.height - w * 0.7),
      Paint()..color = const Color(0x22FFFFFF),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected || complete ? 3.5 : 2.5
        ..color = selected
            ? const Color(0xFFFFFFFF)
            : complete
            ? const Color(0xFF4ADE80)
            : const Color(0x88FFFFFF),
    );
  }

  @override
  bool shouldRepaint(TubePainter old) => true;
}

/// Capacity-based tube height for a given segment height.
double tubeHeight(double segmentHeight) => segmentHeight * kTubeCapacity + 4;
