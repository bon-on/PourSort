import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/pour_game.dart';
import '../ui/palette.dart';
import 'theme_palette.dart';

/// One run of liquid in a tube, bottom to top. [amount] is in segments and
/// may be fractional while a pour animates.
@immutable
class TubeBand {
  const TubeBand(this.color, [this.amount = 1]);
  final int color;
  final double amount;
}

/// Groups a tube's segments into bands of equal colors.
List<TubeBand> bandsOf(List<int> tube) {
  final out = <TubeBand>[];
  for (final c in tube) {
    if (out.isNotEmpty && out.last.color == c) {
      out[out.length - 1] = TubeBand(c, out.last.amount + 1);
    } else {
      out.add(TubeBand(c));
    }
  }
  return out;
}

/// Tube proportions. The tube rect is [width] x [height]; the mouth is at
/// the top center.
class TubeGeometry {
  TubeGeometry(this.width, this.height)
    : lipH = width * 0.14,
      lipOut = width * 0.08,
      glass = math.max(1.5, width * 0.065),
      neck = width * 0.5;

  /// Height of a tube for [width] (fits [kTubeCapacity] segments + neck).
  static double heightFor(double width) => width * 3.55;

  final double width;
  final double height;
  final double lipH;
  final double lipOut;
  final double glass;
  final double neck;

  double get segment => (height - neck - glass) / kTubeCapacity;
  double get liquidBottom => height - glass;

  Path outer() {
    final r = width / 2;
    return Path()..addRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, lipH * 0.5, width, height - lipH * 0.5),
        bottomLeft: Radius.circular(r),
        bottomRight: Radius.circular(r),
        topLeft: Radius.circular(width * 0.06),
        topRight: Radius.circular(width * 0.06),
      ),
    );
  }

  Path inner() {
    final r = width / 2 - glass;
    return Path()..addRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(glass, lipH, width - glass * 2, height - lipH - glass),
        bottomLeft: Radius.circular(r),
        bottomRight: Radius.circular(r),
      ),
    );
  }

  RRect lip() => RRect.fromRectAndRadius(
    Rect.fromLTWH(-lipOut, 0, width + lipOut * 2, lipH),
    Radius.circular(lipH / 2),
  );
}

Color shade(Color c, double amount) => amount >= 0
    ? Color.lerp(c, Colors.white, amount)!
    : Color.lerp(c, Colors.black, -amount)!;

Color liquidColor(int color) => kSegmentColors[color % kSegmentColors.length];

/// Paints a glossy glass tube with liquid in local coordinates (origin at
/// the tube's top-left). The caller rotates the canvas by [angle]; liquid
/// surfaces stay level in world space.
///
/// [slosh] (-1..1) tilts the top surface, [ripple] adds a small wave at
/// [ripplePhase]. [glow] (0..1) is the selection halo. [cork] < 0 draws no
/// cork, 0 a seated cork, up to 1 a cork still falling in.
void paintTube(
  Canvas canvas,
  TubeGeometry g,
  List<TubeBand> bands,
  ThemePalette palette, {
  double angle = 0,
  double slosh = 0,
  double ripple = 0,
  double ripplePhase = 0,
  double glow = 0,
  double cork = -1,
  bool symbols = true,
  Color? outline,
}) {
  final w = g.width;
  final h = g.height;
  final outer = g.outer();
  final inner = g.inner();

  if (glow > 0) {
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.22
        ..color = palette.accent.withValues(alpha: 0.55 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12),
    );
  }

  // Back glass: faint cylinder shading.
  canvas.drawPath(
    outer,
    Paint()
      ..shader = LinearGradient(
        colors: [
          palette.glass.withValues(alpha: 0.30),
          palette.glass.withValues(alpha: 0.10),
          palette.glass.withValues(alpha: 0.06),
          palette.glass.withValues(alpha: 0.22),
        ],
        stops: const [0, 0.3, 0.7, 1],
      ).createShader(Rect.fromLTWH(0, 0, w, h)),
  );

  // Liquid.
  canvas.save();
  canvas.clipPath(inner);
  final cx = w / 2;
  final ca = math.cos(angle);
  final sa = math.sin(angle);
  final reach = h * 2;
  // Liquid levels are measured along world-down projected into the tube's
  // frame: Y = x * sin(a) + y * cos(a). Upright, Y is just y.
  final x0 = g.glass, x1 = w - g.glass, y0 = g.lipH, y1 = g.liquidBottom;
  (double, double)? chord(double level) {
    var lo = -double.infinity, hi = double.infinity;
    if (ca.abs() > 1e-6) {
      final a1 = (x0 - level * sa) / ca, a2 = (x1 - level * sa) / ca;
      lo = math.max(lo, math.min(a1, a2));
      hi = math.min(hi, math.max(a1, a2));
    } else if (level * sa < x0 || level * sa > x1) {
      return null;
    }
    if (sa.abs() > 1e-6) {
      final b1 = (level * ca - y1) / sa, b2 = (level * ca - y0) / sa;
      lo = math.max(lo, math.min(b1, b2));
      hi = math.min(hi, math.max(b1, b2));
    } else if (level * ca < y0 || level * ca > y1) {
      return null;
    }
    return hi > lo ? (lo, hi) : null;
  }

  final midS = cx * ca - (y0 + y1) / 2 * sa;
  // Point at signed distance [s] from the chord middle on the level line.
  Offset along(double level, double s) {
    final c = chord(level);
    final t = (c == null ? midS : (c.$1 + c.$2) / 2) + s;
    return Offset(level * sa + t * ca, level * ca - t * sa);
  }

  final up = Offset(-sa, -ca);
  final upright = angle.abs() < 0.01;
  // Cumulative liquid area from the lowest point, for tilted tubes.
  final cum = <double>[0];
  var yMin = 0.0, yMax = 0.0, step = 0.0;
  if (!upright) {
    final ys = [
      for (final p in [
        Offset(x0, y0),
        Offset(x1, y0),
        Offset(x0, y1),
        Offset(x1, y1),
      ])
        p.dx * sa + p.dy * ca,
    ];
    yMin = ys.reduce(math.min);
    yMax = ys.reduce(math.max);
    const n = 48;
    step = (yMax - yMin) / n;
    for (var i = 1; i <= n; i++) {
      final c = chord(yMax - (i - 0.5) * step);
      cum.add(cum.last + (c == null ? 0 : (c.$2 - c.$1) * step));
    }
  }
  double levelAt(double segments) {
    if (upright) return g.liquidBottom - segments * g.segment;
    final v = segments * g.segment * (x1 - x0);
    for (var i = 1; i < cum.length; i++) {
      if (cum[i] >= v) {
        final span = cum[i] - cum[i - 1];
        final f = span <= 0 ? 0.0 : (v - cum[i - 1]) / span;
        return yMax - (i - 1 + f) * step;
      }
    }
    return yMin;
  }

  var y = levelAt(0);
  final total = bands.fold<double>(0, (a, b) => a + b.amount);
  var filled = 0.0;
  for (var bi = 0; bi < bands.length; bi++) {
    final b = bands[bi];
    if (b.amount <= 0.001) continue;
    filled += b.amount;
    final top = levelAt(filled);
    final isTop = filled >= total - 0.001;
    final base = liquidColor(b.color);
    final path = Path();
    final bl = along(y, -reach);
    final br = along(y, reach);
    path.moveTo(bl.dx, bl.dy);
    path.lineTo(br.dx, br.dy);
    final surface = <Offset>[];
    if (isTop && (slosh != 0 || ripple != 0)) {
      const n = 14;
      for (var i = 0; i <= n; i++) {
        final s = -w + 2 * w * i / n;
        final xn = (s / (w / 2)).clamp(-1.0, 1.0);
        final off =
            slosh * xn * w * 0.16 +
            ripple *
                math.sin(s / w * 2 * math.pi * 1.4 + ripplePhase) *
                w *
                0.05;
        surface.add(along(top, s) + up * off);
      }
      final far = along(top, reach);
      final near = along(top, -reach);
      path.lineTo(far.dx, far.dy);
      for (final p in surface.reversed) {
        path.lineTo(p.dx, p.dy);
      }
      path.lineTo(near.dx, near.dy);
    } else {
      final tr = along(top, reach);
      final tl = along(top, -reach);
      path.lineTo(tr.dx, tr.dy);
      path.lineTo(tl.dx, tl.dy);
      if (isTop) {
        surface
          ..add(along(top, -w))
          ..add(along(top, w));
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            shade(base, -0.32),
            base,
            shade(base, 0.2),
            base,
            shade(base, -0.38),
          ],
          stops: const [0, 0.24, 0.4, 0.68, 1],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    // Thin darker seam between bands.
    if (bi > 0 && angle.abs() < 0.01) {
      canvas.drawRect(
        Rect.fromLTWH(0, y - 0.5, w, math.max(1, w * 0.02)),
        Paint()..color = const Color(0x22000000),
      );
    }
    if (isTop && surface.length >= 2) {
      final sp = Path()..moveTo(surface.first.dx, surface.first.dy);
      for (final p in surface.skip(1)) {
        sp.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        sp,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, w * 0.07)
          ..color = shade(base, 0.45).withValues(alpha: 0.85),
      );
    }
    if (symbols && angle.abs() < 0.02) {
      final whole = b.amount.floor();
      for (var k = 0; k < whole; k++) {
        final c = Offset(cx, y - (k + 0.5) * g.segment);
        if (c.dy < g.lipH + w * 0.2) continue;
        paintSymbol(
          canvas,
          b.color,
          c,
          w * 0.15,
          inkFor(base).withValues(alpha: 0.55),
        );
      }
    }
    y = top;
  }
  canvas.restore();

  // Front glass: highlights and rim.
  final hi = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: 0.0),
        Colors.white.withValues(alpha: 0.55),
        Colors.white.withValues(alpha: 0.35),
        Colors.white.withValues(alpha: 0.0),
      ],
      stops: const [0, 0.15, 0.7, 1],
    ).createShader(Rect.fromLTWH(0, g.lipH, w, h - g.lipH - w * 0.4));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        w * 0.17,
        g.lipH + w * 0.12,
        w * 0.1,
        h - g.lipH - w * 0.75,
      ),
      Radius.circular(w * 0.05),
    ),
    hi,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.76, g.lipH + w * 0.3, w * 0.045, h * 0.35),
      Radius.circular(w * 0.03),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.22),
  );
  canvas.drawCircle(
    Offset(w * 0.7, h - w * 0.32),
    w * 0.055,
    Paint()..color = Colors.white.withValues(alpha: 0.35),
  );
  canvas.drawPath(
    outer,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.04)
      ..color = (outline ?? palette.glassEdge).withValues(
        alpha: outline == null ? 0.75 : 1,
      ),
  );
  // Lip.
  final lip = g.lip();
  canvas.drawRRect(
    lip,
    Paint()
      ..shader = LinearGradient(
        colors: [
          palette.glassEdge.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0.9),
          palette.glassEdge.withValues(alpha: 0.55),
        ],
      ).createShader(lip.outerRect),
  );
  canvas.drawRRect(
    lip,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, w * 0.025)
      ..color = (outline ?? palette.glassEdge),
  );

  if (cork >= 0) paintCork(canvas, g, cork);
}

/// Cork in tube coordinates. [drop] 0 is seated, 1 is far above (faded).
void paintCork(Canvas canvas, TubeGeometry g, double drop) {
  final w = g.width;
  final d = drop.clamp(0.0, 1.0);
  final dy = -d * w * 2.2;
  final alpha = (1 - d * 0.9).clamp(0.0, 1.0);
  final top = -w * 0.26 + dy;
  final hgt = w * 0.5;
  final body = Path()
    ..moveTo(w * 0.1, top)
    ..lineTo(w * 0.9, top)
    ..lineTo(w * 0.82, top + hgt)
    ..lineTo(w * 0.18, top + hgt)
    ..close();
  canvas.drawPath(
    body,
    Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF8A5A33).withValues(alpha: alpha),
          const Color(0xFFD9A066).withValues(alpha: alpha),
          const Color(0xFFB57A45).withValues(alpha: alpha),
          const Color(0xFF6E4424).withValues(alpha: alpha),
        ],
        stops: const [0, 0.35, 0.65, 1],
      ).createShader(Rect.fromLTWH(0, top, w, hgt)),
  );
  canvas.drawOval(
    Rect.fromLTWH(w * 0.1, top - w * 0.07, w * 0.8, w * 0.14),
    Paint()..color = const Color(0xFFE8BC86).withValues(alpha: alpha),
  );
  final dot = Paint()
    ..color = const Color(0xFF5C3A1E).withValues(alpha: alpha * 0.6);
  for (final p in const [
    Offset(0.32, 0.45),
    Offset(0.6, 0.3),
    Offset(0.52, 0.72),
    Offset(0.7, 0.62),
  ]) {
    canvas.drawCircle(
      Offset(w * p.dx, top + hgt * p.dy),
      math.max(0.6, w * 0.025),
      dot,
    );
  }
}
