import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/theme_palette.dart';

/// Rounded panel in the theme's panel color with a soft drop shadow.
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
  });

  final ThemePalette palette;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.panelBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Small upper-case caption above panel values.
class PanelCaption extends StatelessWidget {
  const PanelCaption(this.text, {super.key, required this.palette});

  final String text;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: palette.textSecondary,
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// Rounded progress bar with an accent fill.
class GameProgressBar extends StatelessWidget {
  const GameProgressBar({
    super.key,
    required this.palette,
    required this.value,
    this.height = 10,
  });

  final ThemePalette palette;
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fill = palette.accent;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: palette.textSecondary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(height),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(fill, Colors.white, 0.35)!, fill],
            ),
          ),
        ),
      ),
    );
  }
}

/// A five-point star; [fill] 0 is an empty socket, 1 a gold star.
class StarShape extends StatelessWidget {
  const StarShape({
    super.key,
    required this.size,
    required this.filled,
    required this.palette,
    this.scale = 1,
  });

  final double size;
  final bool filled;
  final ThemePalette palette;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StarPainter(filled, palette, scale)),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.filled, this.palette, this.scale);
  final bool filled;
  final ThemePalette palette;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * scale;
    if (r <= 0) return;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.48;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    if (filled) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(palette.star, Colors.white, 0.45)!,
              palette.star,
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, r * 0.12)
          ..strokeJoin = StrokeJoin.round
          ..color = Color.lerp(palette.star, Colors.black, 0.3)!,
      );
    } else {
      canvas.drawPath(
        path,
        Paint()..color = palette.textSecondary.withValues(alpha: 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.filled != filled || old.scale != scale || old.palette != palette;
}

/// Row of [max] stars with [count] filled.
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.count,
    required this.palette,
    this.size = 18,
    this.max = 3,
    this.spacing = 2,
  });

  final int count;
  final int max;
  final double size;
  final double spacing;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          StarShape(size: size, filled: i < count, palette: palette),
        ],
      ],
    );
  }
}

/// Round icon button in the theme style. Keeps a tooltip for tests and
/// screen readers.
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.palette,
    this.size = 44,
    this.primary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final ThemePalette palette;
  final double size;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? palette.accent : palette.button;
    final fg = primary ? palette.accentInk : palette.buttonInk;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: size * 0.5,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.4),
        disabledForegroundColor: fg.withValues(alpha: 0.35),
        elevation: 2,
        shadowColor: const Color(0x55000000),
        side: BorderSide(color: palette.panelBorder.withValues(alpha: 0.8)),
      ),
      icon: Icon(icon),
    );
  }
}

/// Wide pill button with an optional icon.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.palette,
    this.icon,
    this.primary = false,
    this.height = 46,
  });

  final String label;
  final VoidCallback? onPressed;
  final ThemePalette palette;
  final IconData? icon;
  final bool primary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? palette.accent : palette.button;
    final fg = primary ? palette.accentInk : palette.buttonInk;
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: primary ? 3 : 1,
          shadowColor: const Color(0x55000000),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: primary
              ? null
              : BorderSide(color: palette.panelBorder.withValues(alpha: 0.9)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scrim + centered card used by every modal overlay. Taps on the scrim
/// never reach the board.
class ModalCard extends StatelessWidget {
  const ModalCard({
    super.key,
    required this.palette,
    required this.child,
    this.maxWidth = 420,
    this.scrim = 0xA6000000,
    this.cardKey,
  });

  final ThemePalette palette;
  final Widget child;
  final double maxWidth;
  final int scrim;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: ColoredBox(color: Color(scrim)),
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Material(
                  key: cardKey,
                  type: MaterialType.transparency,
                  child: GamePanel(
                    palette: palette,
                    radius: 26,
                    padding: EdgeInsets.zero,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
