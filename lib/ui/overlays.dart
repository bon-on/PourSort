import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/scenery.dart';
import '../art/theme_palette.dart';
import '../art/tube_art.dart';
import '../logic/player_progress.dart';
import 'ui_kit.dart';

/// Result card after a clear. Stars stamp in one by one; nothing here
/// blocks keys (the screen handles Enter/N/Esc/R).
class WinCard extends StatelessWidget {
  const WinCard({
    super.key,
    required this.outcome,
    required this.progress,
    required this.palette,
    required this.onNext,
    required this.onReplay,
    required this.onLevels,
    this.animate = true,
  });

  final WinOutcome outcome;
  final PlayerProgress progress;
  final ThemePalette palette;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onLevels;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    final best = progress.bestMovesFor(o.level);
    // Short landscape screens get a denser card so "Next level" stays visible.
    final compact = MediaQuery.sizeOf(context).height < 560;
    return ModalCard(
      palette: palette,
      scrim: 0x59000000,
      maxWidth: compact ? 520 : 400,
      cardKey: const Key('win-card'),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: animate ? 0 : 1, end: 1),
        duration: const Duration(milliseconds: 1500),
        builder: (context, v, _) {
          final appear = Curves.easeOutBack.transform(
            ((v - 0.25) / 0.2).clamp(0.0, 1.0),
          );
          return Opacity(
            opacity: ((v - 0.2) / 0.15).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.85 + 0.15 * appear,
              child: _body(v, best, compact),
            ),
          );
        },
      ),
    );
  }

  Widget _body(double v, int best, bool compact) {
    final o = outcome;
    final lvlProgress = progress.xpForNextLevel == 0
        ? 0.0
        : progress.xpIntoLevel / progress.xpForNextLevel;
    final textStyle = TextStyle(
      color: palette.text,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    return SingleChildScrollView(
      padding: compact
          ? const EdgeInsets.fromLTRB(18, 12, 18, 12)
          : const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Level complete!',
              style: TextStyle(
                color: palette.text,
                fontSize: compact ? 22 : 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: compact ? 4 : 10),
          Row(
            key: const Key('win-stars'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.only(
                    left: 4,
                    right: 4,
                    bottom: i == 1 ? 10 : 0,
                  ),
                  child: StarShape(
                    size: (i == 1 ? 56 : 46) * (compact ? 0.7 : 1.0),
                    filled: i < o.stars,
                    palette: palette,
                    scale: i < o.stars
                        ? Curves.elasticOut.transform(
                            ((v - 0.45 - i * 0.12) / 0.3).clamp(0.0, 1.0),
                          )
                        : 1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Level ${o.level} - ${o.moves} moves - Par ${o.par}',
            style: textStyle,
          ),
          const SizedBox(height: 4),
          if (o.isNewBest)
            _chip('New best!', palette.accent, palette.accentInk)
          else if (!o.firstClear && best > 0)
            Text(
              'Best $best moves',
              style: textStyle.copyWith(color: palette.textSecondary),
            ),
          if (o.stars < 3 && !compact)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                o.stars == 2 && o.moves <= o.par
                    ? 'Finish without the extra tube for 3 stars'
                    : 'Finish in ${o.par} moves for 3 stars',
                textAlign: TextAlign.center,
                style: textStyle.copyWith(
                  color: palette.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          SizedBox(height: compact ? 8 : 14),
          Row(
            children: [
              Text(
                'Lv ${progress.playerLevel}',
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GameProgressBar(
                  palette: palette,
                  value: lvlProgress,
                  height: 12,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '+${o.xpGained} XP',
                style: TextStyle(
                  color: palette.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (o.leveledUp) ...[
            const SizedBox(height: 10),
            _chip(
              'Level up! Lv ${o.playerLevelAfter}',
              palette.star,
              const Color(0xFF3B2A00),
            ),
          ],
          for (final t in o.newlyUnlockedThemes) ...[
            const SizedBox(height: 6),
            Text(
              'New theme unlocked: ${t.label}',
              style: textStyle.copyWith(
                color: palette.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          SizedBox(height: compact ? 10 : 18),
          if (compact)
            Row(
              children: [
                Expanded(child: _replay()),
                const SizedBox(width: 8),
                Expanded(child: _levels()),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _next()),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(child: _replay()),
                const SizedBox(width: 10),
                Expanded(child: _levels()),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: _next()),
          ],
        ],
      ),
    );
  }

  Widget _replay() => PillButton(
    key: const Key('replay'),
    label: 'Replay',
    icon: Icons.refresh_rounded,
    palette: palette,
    onPressed: onReplay,
  );

  Widget _levels() => PillButton(
    key: const Key('win-levels'),
    label: 'Levels',
    icon: Icons.grid_view_rounded,
    palette: palette,
    onPressed: onLevels,
  );

  Widget _next() => PillButton(
    key: const Key('next-level'),
    label: 'Next level',
    icon: Icons.arrow_forward_rounded,
    palette: palette,
    primary: true,
    height: 52,
    onPressed: onNext,
  );

  Widget _chip(String text, Color bg, Color fg) => DecoratedBox(
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 14),
      ),
    ),
  );
}

/// Number of level tiles shown: every unlocked level plus a few locked ones,
/// rounded up to a full page of 20.
int levelSelectCount(PlayerProgress p) =>
    ((p.highestLevel + 5) / 20).ceil() * 20;

class LevelSelectOverlay extends StatefulWidget {
  const LevelSelectOverlay({
    super.key,
    required this.progress,
    required this.palette,
    required this.cursor,
    required this.current,
    required this.onPick,
    required this.onClose,
  });

  final PlayerProgress progress;
  final ThemePalette palette;

  /// Keyboard-highlighted level.
  final int cursor;

  /// Level being played.
  final int current;
  final void Function(int level) onPick;
  final VoidCallback onClose;

  static const int columns = 5;

  @override
  State<LevelSelectOverlay> createState() => _LevelSelectOverlayState();
}

class _LevelSelectOverlayState extends State<LevelSelectOverlay> {
  static const double _rowExtent = 68 + 8;
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: math.max(
      0,
      ((widget.cursor - 1) ~/ LevelSelectOverlay.columns - 2) * _rowExtent,
    ),
  );

  @override
  void didUpdateWidget(LevelSelectOverlay old) {
    super.didUpdateWidget(old);
    if (old.cursor != widget.cursor) _reveal();
  }

  /// Keeps the keyboard cursor's row inside the viewport.
  void _reveal() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final row = (widget.cursor - 1) ~/ LevelSelectOverlay.columns;
    final top = row * _rowExtent;
    final bottom = top + _rowExtent;
    var target = pos.pixels;
    if (top < pos.pixels) target = top;
    if (bottom > pos.pixels + pos.viewportDimension) {
      target = bottom - pos.viewportDimension;
    }
    target = target.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (target != pos.pixels) _scroll.jumpTo(target);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = levelSelectCount(widget.progress);
    return ModalCard(
      palette: widget.palette,
      maxWidth: 460,
      cardKey: const Key('level-select'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              title: 'Levels',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StarShape(size: 20, filled: true, palette: widget.palette),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.progress.totalStars}',
                    style: TextStyle(
                      color: widget.palette.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              palette: widget.palette,
              onClose: widget.onClose,
              closeKey: const Key('level-select-close'),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                controller: _scroll,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: LevelSelectOverlay.columns,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 68,
                ),
                itemCount: count,
                itemBuilder: (context, i) => _tile(i + 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(int level) {
    final unlocked = widget.progress.isUnlocked(level);
    final stars = widget.progress.starsFor(level);
    final isCursor = level == widget.cursor;
    final isCurrent = level == widget.current;
    final bg = unlocked
        ? (isCurrent ? widget.palette.accent : widget.palette.button)
        : widget.palette.textSecondary.withValues(alpha: 0.15);
    final fg = isCurrent ? widget.palette.accentInk : widget.palette.buttonInk;
    return GestureDetector(
      key: Key('level-tile-$level'),
      onTap: unlocked ? () => widget.onPick(level) : null,
      child: MouseRegion(
        cursor: unlocked ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCursor
                  ? widget.palette.star
                  : widget.palette.panelBorder,
              width: isCursor ? 3 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (unlocked)
                Text(
                  '$level',
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                )
              else
                Icon(
                  Icons.lock_rounded,
                  size: 18,
                  color: widget.palette.textSecondary,
                ),
              const SizedBox(height: 4),
              if (unlocked)
                StarRow(
                  count: stars,
                  palette: widget.palette,
                  size: 12,
                  spacing: 1,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThemeOverlay extends StatelessWidget {
  const ThemeOverlay({
    super.key,
    required this.progress,
    required this.palette,
    required this.cursor,
    required this.onPick,
    required this.onClose,
  });

  final PlayerProgress progress;
  final ThemePalette palette;
  final int cursor;
  final void Function(PourTheme theme) onPick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ModalCard(
      palette: palette,
      maxWidth: 520,
      cardKey: const Key('theme-picker'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              title: 'Themes',
              trailing: Text(
                'Lv ${progress.playerLevel}',
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              palette: palette,
              onClose: onClose,
              closeKey: const Key('theme-picker-close'),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) {
                final cols = box.maxWidth >= 420 ? 4 : 2;
                final w = (box.maxWidth - 10 * (cols - 1)) / cols;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final t in PourTheme.values)
                      SizedBox(width: w, child: _card(t)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(PourTheme t) {
    final unlocked = progress.isThemeUnlocked(t);
    final selected = progress.selectedTheme == t;
    final isCursor = PourTheme.values.indexOf(t) == cursor;
    return GestureDetector(
      key: Key('theme-${t.name}'),
      onTap: unlocked ? () => onPick(t) : null,
      child: MouseRegion(
        cursor: unlocked ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          decoration: BoxDecoration(
            color: palette.button,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCursor
                  ? palette.star
                  : selected
                  ? palette.accent
                  : palette.panelBorder,
              width: isCursor || selected ? 3 : 1,
            ),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: _ThemePreview(t)),
                      if (!unlocked)
                        ColoredBox(
                          color: const Color(0x99000000),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.lock_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                Text(
                                  'Lv ${t.requiredLevel}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  selected ? '${t.label} (on)' : t.label,
                  style: TextStyle(
                    color: palette.buttonInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends CustomPainter {
  _ThemePreview(this.theme);
  final PourTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    // Render the scenery at a room-like size, then scale it down.
    const room = Size(420, 420);
    final s = size.width / room.width;
    canvas.save();
    canvas.scale(s);
    SceneryPainter(theme).paint(canvas, room);
    final p = ThemePalette.of(theme);
    const w = 70.0;
    final g = TubeGeometry(w, TubeGeometry.heightFor(w));
    final tubes = [
      [0, 1, 0, 2],
      [3, 3, 3, 3],
      [2, 1],
    ];
    for (var i = 0; i < tubes.length; i++) {
      canvas.save();
      canvas.translate(75 + i * 100.0, 70);
      paintTube(canvas, g, bandsOf(tubes[i]), p, cork: i == 1 ? 0 : -1);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThemePreview old) => old.theme != theme;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.trailing,
    required this.palette,
    required this.onClose,
    required this.closeKey,
  });

  final String title;
  final Widget trailing;
  final ThemePalette palette;
  final VoidCallback onClose;
  final Key closeKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: TextStyle(
                color: palette.text,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        trailing,
        const SizedBox(width: 10),
        RoundButton(
          key: closeKey,
          icon: Icons.close_rounded,
          tooltip: 'Close (Esc)',
          onPressed: onClose,
          palette: palette,
          size: 38,
        ),
      ],
    );
  }
}
