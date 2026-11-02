import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/theme_palette.dart';
import '../art/tube_art.dart';
import '../logic/pour_game.dart';
import 'board_fx.dart';

/// Label shown under tube [i]: 1-9, 0, then Q W E T Y I.
String tubeKeyLabel(int i) {
  const letters = ['Q', 'W', 'E', 'T', 'Y', 'I'];
  if (i < 9) return '${i + 1}';
  if (i == 9) return '0';
  return i - 10 < letters.length ? letters[i - 10] : '';
}

bool isCompleteTube(List<int> tube) =>
    tube.length == kTubeCapacity && tube.every((c) => c == tube.first);

/// Tube slots for [n] tubes in a [size] board. Each slot rect is the tap
/// area: lift space, tube, rack lip and key label.
class BoardLayout {
  BoardLayout._(this.tubeWidth, this.slots, this.rows);

  static const double labelHeight = 18;
  static const double maxTubeWidth = 86;

  final double tubeWidth;
  final List<Rect> slots;

  /// Slot indices per row.
  final List<List<int>> rows;

  double get liftSpace => tubeWidth * 0.5;
  double get tubeHeight => TubeGeometry.heightFor(tubeWidth);
  double get rackHeight => tubeWidth * 0.2;

  static double slotHeightFor(double w) =>
      w * 0.5 + TubeGeometry.heightFor(w) + w * 0.12 + labelHeight;

  /// Rest rect of tube [i] (without lift).
  Rect tubeRect(int i) {
    final s = slots[i];
    return Rect.fromLTWH(s.left, s.top + liftSpace, tubeWidth, tubeHeight);
  }

  factory BoardLayout.compute(Size size, int n) {
    if (n <= 0) return BoardLayout._(20, const [], const []);
    const rowGap = 12.0;
    final availW = math.max(40.0, size.width - 16);
    final availH = math.max(60.0, size.height - 8);
    var bestW = 0.0;
    var bestRows = 1;
    for (var rows = 1; rows <= n; rows++) {
      final cols = (n / rows).ceil();
      // Gap between tubes is 0.45 tube widths.
      final byWidth = availW / (cols + 0.45 * (cols - 1));
      final perRowFixed = BoardLayout.labelHeight;
      final unitH = 0.5 + 3.55 + 0.12;
      final byHeight =
          (availH - (rows - 1) * rowGap - rows * perRowFixed) / (rows * unitH);
      final w = math.min(maxTubeWidth, math.min(byWidth, byHeight));
      if (w > bestW + 0.01) {
        bestW = w;
        bestRows = rows;
      }
    }
    final w = math.max(12.0, bestW);
    final rowsCount = bestRows;
    final perRow = (n / rowsCount).ceil();
    final gap = w * 0.45;
    final slotH = slotHeightFor(w);
    final totalH = rowsCount * slotH + (rowsCount - 1) * rowGap;
    final top0 = (size.height - totalH) / 2;
    final slots = <Rect>[];
    final rows = <List<int>>[];
    var index = 0;
    for (var r = 0; r < rowsCount; r++) {
      final count = math.min(perRow, n - index);
      if (count <= 0) break;
      final rowW = count * w + (count - 1) * gap;
      final left0 = (size.width - rowW) / 2;
      final row = <int>[];
      for (var c = 0; c < count; c++) {
        slots.add(
          Rect.fromLTWH(
            left0 + c * (w + gap),
            top0 + r * (slotH + rowGap),
            w,
            slotH,
          ),
        );
        row.add(index++);
      }
      rows.add(row);
    }
    return BoardLayout._(w, slots, rows);
  }
}

/// The tube board: one painter for every tube and effect, plus transparent
/// tap targets (`Key('tube-$i')`) with key labels.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.tubes,
    required this.selected,
    required this.palette,
    required this.fx,
    required this.onTap,
    this.showLabels = true,
  });

  final List<List<int>> tubes;
  final int? selected;
  final ThemePalette palette;
  final BoardFx fx;
  final void Function(int index) onTap;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final layout = BoardLayout.compute(size, tubes.length);
        final labelStyle = TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: palette.dark
              ? const Color(0xB3FFFFFF)
              : const Color(0xCCFFFFFF),
        );
        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: BoardPainter(
                    tubes: tubes,
                    selected: selected,
                    layout: layout,
                    palette: palette,
                    fx: fx,
                  ),
                ),
              ),
            ),
            for (var i = 0; i < tubes.length; i++)
              Positioned.fromRect(
                rect: layout.slots[i],
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    key: Key('tube-$i'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: BoardLayout.labelHeight,
                        child: showLabels && tubeKeyLabel(i).isNotEmpty
                            ? FittedBox(
                                child: Text(tubeKeyLabel(i), style: labelStyle),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.tubes,
    required this.selected,
    required this.layout,
    required this.palette,
    required this.fx,
  }) : super(repaint: fx);

  final List<List<int>> tubes;
  final int? selected;
  final BoardLayout layout;
  final ThemePalette palette;
  final BoardFx fx;

  static const double _tilt = 1.4;

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.min(tubes.length, layout.slots.length);
    if (n == 0) return;
    final w = layout.tubeWidth;
    final g = TubeGeometry(w, layout.tubeHeight);
    final now = fx.now;

    // Racks behind and under each row.
    for (final row in layout.rows) {
      if (row.isEmpty) continue;
      final first = layout.tubeRect(row.first);
      final last = layout.tubeRect(row.last);
      final y = first.bottom - w * 0.18;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          first.left - w * 0.35,
          y,
          last.right + w * 0.35,
          y + layout.rackHeight,
        ),
        Radius.circular(layout.rackHeight / 2),
      );
      canvas.drawRRect(
        r.shift(Offset(0, w * 0.08)),
        Paint()..color = const Color(0x40000000),
      );
    }

    final flying = <PourFx>[];
    for (var i = 0; i < n; i++) {
      final asSource = fx.pourFrom(i);
      if (asSource != null) {
        final t = (now - asSource.start) / BoardFx.pourDuration;
        if (t >= 0 && t < 1) {
          flying.add(asSource);
          continue;
        }
      }
      final rest = layout.tubeRect(i);
      final lift = fx.liftOf(i) * layout.liftSpace;
      final hop = fx.hopOf(i) * w;
      final bands = _bandsAt(i);
      final (slosh, ripple, phase) = fx.wobbleOf(i);
      final complete = isCompleteTube(tubes[i]);
      canvas.save();
      canvas.translate(rest.left, rest.top - lift + hop);
      paintTube(
        canvas,
        g,
        bands,
        palette,
        slosh: slosh,
        ripple: ripple,
        ripplePhase: phase,
        glow: fx.liftOf(i).clamp(0.0, 1.0),
        cork: complete ? fx.corkOf(i) : -1,
        outline: complete ? palette.star : null,
      );
      canvas.restore();
    }

    // Rack front bars over the tube bottoms.
    for (final row in layout.rows) {
      if (row.isEmpty) continue;
      final first = layout.tubeRect(row.first);
      final last = layout.tubeRect(row.last);
      final y = first.bottom - w * 0.18;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          first.left - w * 0.35,
          y,
          last.right + w * 0.35,
          y + layout.rackHeight,
        ),
        Radius.circular(layout.rackHeight / 2),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.rackTop, palette.rackBottom],
          ).createShader(r.outerRect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            r.left + 4,
            r.top + 1.5,
            r.width - 8,
            math.max(1.5, layout.rackHeight * 0.2),
          ),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.3),
      );
    }

    for (final p in flying) {
      _paintFlying(canvas, g, p);
    }

    _paintParticles(canvas, size, w);
    _paintPopups(canvas, w);
    _paintBanner(canvas, size);
  }

  /// Bands for tube [i] at [fx.now], accounting for a pour into it.
  List<TubeBand> _bandsAt(int i) {
    final tube = tubes[i];
    final into = fx.pourInto(i);
    if (into == null) return bandsOf(tube);
    final m = into.move;
    final f = _flow(into);
    final keep = tube.length - m.count;
    if (keep < 0) return bandsOf(tube);
    final base = bandsOf(tube.sublist(0, keep));
    final amount = m.count * f;
    if (amount <= 0) return base;
    if (base.isNotEmpty && base.last.color == m.color) {
      base[base.length - 1] = TubeBand(m.color, base.last.amount + amount);
    } else {
      base.add(TubeBand(m.color, amount));
    }
    return base;
  }

  /// 0..1 progress of liquid arriving in the target.
  double _flow(PourFx p) {
    final u = (fx.now - p.start) / BoardFx.pourDuration;
    return ((u - 0.34) / 0.4).clamp(0.0, 1.0);
  }

  void _paintFlying(Canvas canvas, TubeGeometry g, PourFx p) {
    final m = p.move;
    final w = g.width;
    final u = ((fx.now - p.start) / BoardFx.pourDuration).clamp(0.0, 1.0);
    final src = layout.tubeRect(m.from);
    final dst = layout.tubeRect(m.to);
    final dir = dst.center.dx >= src.center.dx ? 1.0 : -1.0;
    final startLift = p.fromWasLifted ? layout.liftSpace : 0.0;
    final p0s = Offset(src.center.dx, src.top - startLift);
    final p0e = Offset(src.center.dx, src.top);
    final p1 = Offset(
      dst.center.dx - dir * w * 0.95,
      math.max(w * 0.4, dst.top - w * 1.05),
    );
    Offset pivot;
    double angle;
    double flowOut;
    if (u < 0.3) {
      final k = Curves.easeInOut.transform(u / 0.3);
      pivot = Offset.lerp(p0s, p1, k)!;
      angle = _tilt * Curves.easeIn.transform(k);
      flowOut = 0;
    } else if (u < 0.76) {
      final f = (u - 0.3) / 0.46;
      pivot = p1;
      angle = _tilt + 0.3 * f;
      flowOut = ((u - 0.32) / 0.4).clamp(0.0, 1.0);
    } else {
      final k = Curves.easeInOut.transform((u - 0.76) / 0.24);
      pivot = Offset.lerp(p1, p0e, k)!;
      angle = (_tilt + 0.3) * (1 - k);
      flowOut = 1;
    }
    final a = angle * dir;
    final tube = tubes[m.from];
    final bands = bandsOf(tube);
    final remaining = m.count * (1 - flowOut);
    if (remaining > 0.001) {
      if (bands.isNotEmpty && bands.last.color == m.color) {
        bands[bands.length - 1] = TubeBand(
          m.color,
          bands.last.amount + remaining,
        );
      } else {
        bands.add(TubeBand(m.color, remaining));
      }
    }

    // Stream from the lip into the target.
    if (u >= 0.3 && u < 0.8) {
      final f = ((u - 0.3) / 0.46).clamp(0.0, 1.0);
      final lip =
          pivot +
          Offset(math.cos(a) * dir * w * 0.5, math.sin(a) * dir * w * 0.5);
      final targetFill = tubes[m.to].length - m.count + m.count * _flow(p);
      final surfaceY = dst.top + g.liquidBottom - g.segment * targetFill;
      final entry = Offset(dst.center.dx, dst.top + g.lipH);
      final path = Path()
        ..moveTo(lip.dx, lip.dy)
        ..quadraticBezierTo(
          (lip.dx + entry.dx) / 2,
          math.min(lip.dy, entry.dy) - w * 0.15,
          entry.dx,
          entry.dy,
        )
        ..lineTo(entry.dx, math.max(entry.dy, surfaceY));
      final metric = path.computeMetrics().toList();
      if (metric.isNotEmpty) {
        final len = metric.first.length;
        final head = (f / 0.18).clamp(0.0, 1.0);
        final tail = ((f - 0.82) / 0.18).clamp(0.0, 1.0);
        final seg = metric.first.extractPath(len * tail, len * head);
        final color = liquidColor(m.color);
        canvas.drawPath(
          seg,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = w * 0.16
            ..color = shade(color, -0.15),
        );
        canvas.drawPath(
          seg,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = w * 0.05
            ..color = shade(color, 0.4).withValues(alpha: 0.8),
        );
      }
    }

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(a);
    canvas.translate(-w / 2, 0);
    paintTube(canvas, g, bands, palette, angle: a, symbols: false);
    canvas.restore();
  }

  void _paintParticles(Canvas canvas, Size size, double w) {
    final now = fx.now;
    for (final p in fx.particles) {
      final t = now - p.start;
      if (t < 0) continue;
      final life = (t / p.life).clamp(0.0, 1.0);
      final alpha = life < 0.7 ? 1.0 : (1 - life) / 0.3;
      Offset pos;
      double s;
      if (p.tube >= 0) {
        if (p.tube >= layout.slots.length) continue;
        final r = layout.tubeRect(p.tube);
        pos = Offset(
          r.left + (p.x + p.vx * t) * w,
          r.top + (p.y + p.vy * t + 0.5 * p.gravity * t * t) * w,
        );
        s = p.size * w;
      } else {
        pos = Offset(
          (p.x + p.vx * t) * size.width,
          (p.y + p.vy * t + 0.5 * p.gravity * t * t) * size.height,
        );
        s = p.size * size.shortestSide;
      }
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.color.a * alpha);
      switch (p.kind) {
        case ParticleKind.bubble:
          canvas.drawCircle(
            pos,
            s,
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1, s * 0.35),
          );
        case ParticleKind.sparkle:
          _sparkle(canvas, pos, s * (1 - life * 0.5), p.spin * t, paint);
        case ParticleKind.confetti:
          canvas.save();
          canvas.translate(pos.dx, pos.dy);
          canvas.rotate(p.spin * t);
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: s * 2,
              height: s * 1.1 * (0.4 + 0.6 * math.cos(p.spin * t * 0.7).abs()),
            ),
            paint,
          );
          canvas.restore();
      }
    }
  }

  void _sparkle(Canvas canvas, Offset c, double r, double rot, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = rot + i * math.pi / 4;
      final rr = i.isEven ? r : r * 0.32;
      final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  void _paintPopups(Canvas canvas, double w) {
    for (final p in fx.popups) {
      final t = (fx.now - p.start) / p.life;
      if (t < 0 || t >= 1 || p.tube >= layout.slots.length) continue;
      final r = layout.tubeRect(p.tube);
      final scale = t < 0.2 ? Curves.easeOutBack.transform(t / 0.2) : 1.0;
      final alpha = t < 0.75 ? 1.0 : (1 - t) / 0.25;
      final fontSize = math.max(12.0, w * 0.32);
      final tp = TextPainter(
        text: TextSpan(
          text: p.text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: palette.star.withValues(alpha: alpha),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5 * alpha),
                blurRadius: 3,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(r.center.dx, r.top - w * 0.55 - t * w * 0.6);
      canvas.scale(scale);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      tp.dispose();
    }
  }

  void _paintBanner(Canvas canvas, Size size) {
    final b = fx.banner;
    if (b == null) return;
    final t = (fx.now - b.start) / b.life;
    if (t < 0 || t >= 1) return;
    final scale = t < 0.18 ? Curves.easeOutBack.transform(t / 0.18) : 1.0;
    final alpha = t < 0.8 ? 1.0 : (1 - t) / 0.2;
    final fontSize = (size.shortestSide * 0.08).clamp(18.0, 40.0);
    final tp = TextPainter(
      text: TextSpan(
        text: b.text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final c = Offset(size.width / 2, math.max(fontSize, size.height * 0.08));
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c,
        width: tp.width + fontSize * 1.4,
        height: tp.height + fontSize * 0.5,
      ),
      Radius.circular(fontSize),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(scale);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawRRect(
      pill,
      Paint()..color = palette.accent.withValues(alpha: 0.92 * alpha),
    );
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    canvas.restore();
    tp.dispose();
  }

  @override
  bool shouldRepaint(BoardPainter old) => true;
}
