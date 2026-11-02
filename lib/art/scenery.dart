import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/player_progress.dart';
import 'theme_palette.dart';
import 'tube_art.dart';

/// Static themed room behind the board. Decorations sit along the edges so
/// the tubes in the middle stay readable.
class SceneryPainter extends CustomPainter {
  SceneryPainter(this.theme);

  final PourTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final p = ThemePalette.of(theme);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.skyTop, p.skyBottom],
        ).createShader(rect),
    );
    switch (theme) {
      case PourTheme.lab:
        _lab(canvas, size, p);
      case PourTheme.potionShop:
        _potion(canvas, size, p);
      case PourTheme.candy:
        _candy(canvas, size, p);
      case PourTheme.nightBar:
        _night(canvas, size, p);
    }
    // Soft vignette.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: p.dark ? 0.45 : 0.18),
          ],
          stops: const [0.6, 1],
        ).createShader(rect),
    );
  }

  double _unit(Size s) => math.min(s.width, s.height) / 10;

  void _counter(Canvas canvas, Size size, Color top, Color bottom) {
    final h = math.max(28.0, size.height * 0.09);
    final r = Rect.fromLTWH(0, size.height - h, size.width, h);
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(r),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - h, size.width, 3),
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
  }

  void _shelf(Canvas canvas, Offset at, double width, Color c) {
    final r = Rect.fromLTWH(at.dx, at.dy, width, math.max(5, width * 0.05));
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      Paint()..color = c,
    );
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.bottom, r.width, r.height * 0.8),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
  }

  void _flask(
    Canvas canvas,
    Offset base,
    double s,
    Color liquid, {
    int kind = 0,
  }) {
    final glass = Paint()..color = Colors.white.withValues(alpha: 0.18);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, s * 0.06)
      ..color = Colors.white.withValues(alpha: 0.5);
    final fill = Paint()..color = liquid.withValues(alpha: 0.85);
    if (kind == 0) {
      // Erlenmeyer.
      final path = Path()
        ..moveTo(base.dx - s * 0.18, base.dy - s * 1.3)
        ..lineTo(base.dx + s * 0.18, base.dy - s * 1.3)
        ..lineTo(base.dx + s * 0.18, base.dy - s * 0.9)
        ..lineTo(base.dx + s * 0.6, base.dy)
        ..lineTo(base.dx - s * 0.6, base.dy)
        ..lineTo(base.dx - s * 0.18, base.dy - s * 0.9)
        ..close();
      canvas.drawPath(path, glass);
      canvas.save();
      canvas.clipPath(path);
      canvas.drawRect(
        Rect.fromLTWH(base.dx - s, base.dy - s * 0.5, s * 2, s * 0.5),
        fill,
      );
      canvas.restore();
      canvas.drawPath(path, edge);
    } else if (kind == 1) {
      // Round bottom flask.
      final c = Offset(base.dx, base.dy - s * 0.45);
      final path = Path()
        ..addOval(Rect.fromCircle(center: c, radius: s * 0.45))
        ..addRect(
          Rect.fromLTWH(c.dx - s * 0.13, c.dy - s * 0.95, s * 0.26, s * 0.6),
        );
      canvas.drawPath(path, glass);
      canvas.save();
      canvas.clipPath(path);
      canvas.drawRect(Rect.fromLTWH(c.dx - s, c.dy - s * 0.05, s * 2, s), fill);
      canvas.restore();
      canvas.drawCircle(c, s * 0.45, edge);
    } else {
      // Bottle.
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(base.dx - s * 0.32, base.dy - s * 1.0, s * 0.64, s),
        Radius.circular(s * 0.16),
      );
      canvas.drawRRect(r, fill);
      canvas.drawRect(
        Rect.fromLTWH(
          base.dx - s * 0.11,
          base.dy - s * 1.35,
          s * 0.22,
          s * 0.38,
        ),
        fill,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          base.dx - s * 0.13,
          base.dy - s * 1.45,
          s * 0.26,
          s * 0.12,
        ),
        Paint()..color = const Color(0xFFB57A45),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            base.dx - s * 0.22,
            base.dy - s * 0.9,
            s * 0.08,
            s * 0.6,
          ),
          Radius.circular(s * 0.04),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.4),
      );
    }
  }

  void _glowDot(Canvas canvas, Offset c, double r, Color color, double a) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: a),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _lab(Canvas canvas, Size size, ThemePalette p) {
    final u = _unit(size);
    // Wall tiles.
    final tile = math.max(26.0, u * 1.1);
    final grout = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += tile) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grout);
    }
    for (var y = 0.0; y < size.height; y += tile) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grout);
    }
    // Ceiling lamp glows.
    for (final fx in [0.2, 0.8]) {
      _glowDot(
        canvas,
        Offset(size.width * fx, 0),
        u * 5,
        const Color(0xFFBDF4FF),
        0.22,
      );
    }
    // Shelves with glassware in the top corners.
    final shelfW = math.min(size.width * 0.24, u * 7);
    final sy = size.height * 0.2;
    _shelf(canvas, Offset(size.width * 0.03, sy), shelfW, p.rackTop);
    _shelf(canvas, Offset(size.width * 0.97 - shelfW, sy), shelfW, p.rackTop);
    final s = math.min(u * 0.9, shelfW / 5);
    final colors = [0, 6, 2, 3, 1, 7].map(liquidColor).toList();
    for (var i = 0; i < 3; i++) {
      _flask(
        canvas,
        Offset(size.width * 0.03 + shelfW * (0.18 + i * 0.32), sy),
        s,
        colors[i],
        kind: i % 2,
      );
      _flask(
        canvas,
        Offset(size.width * 0.97 - shelfW * (0.18 + i * 0.32), sy),
        s,
        colors[i + 3],
        kind: (i + 1) % 2,
      );
    }
    _counter(canvas, size, const Color(0xFF8FA6B5), const Color(0xFF4C6475));
  }

  void _potion(Canvas canvas, Size size, ThemePalette p) {
    final u = _unit(size);
    // Plank wall.
    final plank = math.max(34.0, u * 1.6);
    var i = 0;
    for (var x = 0.0; x < size.width; x += plank, i++) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, plank, size.height),
        Paint()
          ..color = (i.isEven ? Colors.white : Colors.black).withValues(
            alpha: 0.035,
          ),
      );
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..strokeWidth = 2,
      );
    }
    // Hanging herbs.
    final herb = Paint()
      ..color = const Color(0xFF7FA35B).withValues(alpha: 0.8)
      ..strokeWidth = math.max(2, u * 0.12)
      ..strokeCap = StrokeCap.round;
    for (final fx in [0.08, 0.15, 0.85, 0.92]) {
      final x = size.width * fx;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, u * 1.2),
        Paint()
          ..color = const Color(0xFFC9A27A)
          ..strokeWidth = 1.5,
      );
      for (var k = 0; k < 4; k++) {
        final y = u * 1.2 + k * u * 0.35;
        canvas.drawLine(Offset(x, y), Offset(x - u * 0.35, y + u * 0.5), herb);
        canvas.drawLine(Offset(x, y), Offset(x + u * 0.35, y + u * 0.5), herb);
      }
    }
    // Shelves of glowing bottles.
    final shelfW = math.min(size.width * 0.24, u * 7);
    for (final row in [0.3, 0.55]) {
      final sy = size.height * row;
      _shelf(canvas, Offset(size.width * 0.02, sy), shelfW, p.rackTop);
      _shelf(canvas, Offset(size.width * 0.98 - shelfW, sy), shelfW, p.rackTop);
      final s = math.min(u * 0.85, shelfW / 5);
      for (var k = 0; k < 3; k++) {
        final c1 = liquidColor((k * 3 + (row * 10).round()) % 10);
        final c2 = liquidColor((k * 3 + 5 + (row * 10).round()) % 10);
        final b1 = Offset(size.width * 0.02 + shelfW * (0.18 + k * 0.32), sy);
        final b2 = Offset(size.width * 0.98 - shelfW * (0.18 + k * 0.32), sy);
        _glowDot(canvas, b1.translate(0, -s * 0.5), s * 1.3, c1, 0.35);
        _glowDot(canvas, b2.translate(0, -s * 0.5), s * 1.3, c2, 0.35);
        _flask(canvas, b1, s, c1, kind: 2);
        _flask(canvas, b2, s, c2, kind: 2);
      }
    }
    _counter(canvas, size, const Color(0xFF8C5A3C), const Color(0xFF4A2A17));
    // Candles on the counter.
    final ch = math.max(28.0, size.height * 0.09);
    for (final fx in [0.06, 0.94]) {
      final base = Offset(size.width * fx, size.height - ch + 4);
      final cw = u * 0.45;
      _glowDot(
        canvas,
        base.translate(0, -u * 1.5),
        u * 2.2,
        const Color(0xFFFFC46B),
        0.45,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(base.dx - cw / 2, base.dy - u * 1.2, cw, u * 1.2),
          Radius.circular(cw * 0.2),
        ),
        Paint()..color = const Color(0xFFF7E6C4),
      );
      final flame = Path()
        ..moveTo(base.dx, base.dy - u * 1.8)
        ..quadraticBezierTo(
          base.dx + cw * 0.45,
          base.dy - u * 1.35,
          base.dx,
          base.dy - u * 1.22,
        )
        ..quadraticBezierTo(
          base.dx - cw * 0.45,
          base.dy - u * 1.35,
          base.dx,
          base.dy - u * 1.8,
        );
      canvas.drawPath(flame, Paint()..color = const Color(0xFFFFB238));
    }
  }

  void _candy(Canvas canvas, Size size, ThemePalette p) {
    final u = _unit(size);
    // Diagonal stripes.
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.18);
    final sw = math.max(30.0, u * 1.4);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var x = -size.height; x < size.width; x += sw * 2) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + sw, 0)
        ..lineTo(x + sw + size.height, size.height)
        ..lineTo(x + size.height, size.height)
        ..close();
      canvas.drawPath(path, stripe);
    }
    canvas.restore();
    // Clouds.
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (final c in [Offset(0.12, 0.1), Offset(0.86, 0.16)]) {
      final o = Offset(size.width * c.dx, size.height * c.dy);
      for (final b in const [
        Offset(-1, 0.2),
        Offset(0, -0.2),
        Offset(1, 0.15),
        Offset(0.4, 0.4),
        Offset(-0.5, 0.45),
      ]) {
        canvas.drawCircle(o + b * u * 0.8, u * 0.75, cloud);
      }
    }
    // Lollipops.
    for (final c in [(0.07, 0.62, 0), (0.93, 0.55, 7)]) {
      final o = Offset(size.width * c.$1, size.height * c.$2);
      final r = u * 0.9;
      canvas.drawLine(
        o,
        o.translate(0, r * 3),
        Paint()
          ..color = Colors.white
          ..strokeWidth = math.max(3, u * 0.18)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(o, r, Paint()..color = liquidColor(c.$3));
      final swirl = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, r * 0.18)
        ..color = Colors.white.withValues(alpha: 0.85);
      final path = Path();
      for (var i = 0; i <= 40; i++) {
        final t = i / 40;
        final a = t * math.pi * 4;
        final rr = r * 0.85 * t;
        final pt = o + Offset(math.cos(a) * rr, math.sin(a) * rr);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, swirl);
    }
    // Sprinkles.
    final rng = math.Random(11);
    for (var i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      // Keep the middle calm.
      final nx = (x / size.width - 0.5).abs();
      if (nx < 0.28) continue;
      final a = rng.nextDouble() * math.pi;
      final len = u * 0.3;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(a) * len, y + math.sin(a) * len),
        Paint()
          ..color = liquidColor(rng.nextInt(10)).withValues(alpha: 0.75)
          ..strokeWidth = math.max(2, u * 0.12)
          ..strokeCap = StrokeCap.round,
      );
    }
    _counter(canvas, size, const Color(0xFFFFA9CC), const Color(0xFFE56FA3));
  }

  void _night(Canvas canvas, Size size, ThemePalette p) {
    final u = _unit(size);
    // Bokeh lights.
    final rng = math.Random(5);
    const hues = [
      Color(0xFFFF4FD8),
      Color(0xFF2EE6D6),
      Color(0xFFFFC84D),
      Color(0xFF7A6BFF),
    ];
    for (var i = 0; i < 26; i++) {
      final c = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height * 0.75,
      );
      _glowDot(
        canvas,
        c,
        u * (0.5 + rng.nextDouble() * 1.4),
        hues[i % hues.length],
        0.18 + rng.nextDouble() * 0.15,
      );
    }
    // Neon cocktail sign, top left.
    final o = Offset(size.width * 0.1, size.height * 0.16);
    final s = u * 1.3;
    final glass = Path()
      ..moveTo(o.dx - s, o.dy - s * 0.6)
      ..lineTo(o.dx + s, o.dy - s * 0.6)
      ..lineTo(o.dx, o.dy + s * 0.5)
      ..close()
      ..moveTo(o.dx, o.dy + s * 0.5)
      ..lineTo(o.dx, o.dy + s * 1.3)
      ..moveTo(o.dx - s * 0.5, o.dy + s * 1.3)
      ..lineTo(o.dx + s * 0.5, o.dy + s * 1.3);
    for (final (width, alpha) in [(u * 0.5, 0.25), (u * 0.12, 1.0)]) {
      canvas.drawPath(
        glass,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFFF4FD8).withValues(alpha: alpha)
          ..maskFilter = alpha < 1
              ? MaskFilter.blur(BlurStyle.normal, u * 0.3)
              : null,
      );
    }
    canvas.drawCircle(
      o.translate(s * 0.55, -s * 0.85),
      s * 0.22,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.1
        ..color = const Color(0xFF2EE6D6),
    );
    // Moon-like neon ring, top right.
    final m = Offset(size.width * 0.9, size.height * 0.14);
    canvas.drawCircle(
      m,
      s * 0.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.4
        ..color = const Color(0xFF2EE6D6).withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.3),
    );
    canvas.drawCircle(
      m,
      s * 0.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.1
        ..color = const Color(0xFF2EE6D6),
    );
    // Back-bar bottles.
    final ch = math.max(28.0, size.height * 0.09);
    final shelfY = size.height - ch - u * 0.2;
    final bs = u * 0.8;
    for (var i = 0; i < 4; i++) {
      for (final side in [0, 1]) {
        final x = side == 0
            ? size.width * (0.03 + i * 0.045)
            : size.width * (0.97 - i * 0.045);
        final c = liquidColor((i * 3 + side * 5) % 10);
        _glowDot(canvas, Offset(x, shelfY - bs * 0.6), bs * 1.3, c, 0.3);
        _flask(
          canvas,
          Offset(x, shelfY),
          bs,
          c.withValues(alpha: 0.9),
          kind: 2,
        );
      }
    }
    _counter(canvas, size, const Color(0xFF2A2163), const Color(0xFF0C0A24));
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - ch, size.width, 2),
      Paint()..color = const Color(0xFF2EE6D6).withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(SceneryPainter old) => old.theme != theme;
}
