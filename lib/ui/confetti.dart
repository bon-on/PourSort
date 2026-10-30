import 'dart:math';

import 'package:flutter/material.dart';

import 'palette.dart';

/// Lightweight confetti burst, drawn with a single AnimationController.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();
  final _rng = Random(7);
  late final List<_Piece> _pieces = List.generate(70, (i) => _Piece(_rng, i));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _ConfettiPainter(_pieces, _c.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Piece {
  _Piece(Random r, int i)
    : x = r.nextDouble(),
      vx = (r.nextDouble() - 0.5) * 0.4,
      delay = r.nextDouble() * 0.3,
      speed = 0.6 + r.nextDouble() * 0.6,
      spin = r.nextDouble() * 10,
      color = kSegmentColors[i % kSegmentColors.length];
  final double x, vx, delay, speed, spin;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final u = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (u <= 0) continue;
      final dx = (p.x + p.vx * u) * size.width;
      final dy = -20 + u * p.speed * (size.height + 40);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.spin * u);
      canvas.drawRect(
        const Rect.fromLTWH(-5, -3, 10, 6),
        Paint()..color = p.color.withValues(alpha: 1 - u * 0.5),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
