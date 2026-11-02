import 'package:flutter/material.dart';

import '../art/theme_palette.dart';
import 'game_controller.dart';
import 'ui_kit.dart';

/// Callbacks and state the HUD needs from the screen.
class HudActions {
  const HudActions({
    required this.onHelp,
    required this.onToggleSound,
    required this.onLevels,
    required this.onThemes,
    required this.soundMuted,
  });

  final VoidCallback onHelp;
  final VoidCallback onToggleSound;
  final VoidCallback onLevels;
  final VoidCallback onThemes;
  final bool soundMuted;
}

List<Widget> _playButtons(GameController ctrl, ThemePalette p, double size) {
  final g = ctrl.game;
  return [
    RoundButton(
      key: const Key('undo'),
      tooltip: 'Undo (U)',
      onPressed: g.canUndo && !ctrl.won ? ctrl.undo : null,
      icon: Icons.undo_rounded,
      palette: p,
      size: size,
    ),
    RoundButton(
      key: const Key('restart'),
      tooltip: 'Restart (R)',
      onPressed: ctrl.restart,
      icon: Icons.refresh_rounded,
      palette: p,
      size: size,
    ),
    RoundButton(
      key: const Key('add-tube'),
      tooltip: 'Add an empty tube, once per level (A)',
      onPressed: g.extraTubeUsed || ctrl.won ? null : ctrl.addTube,
      icon: Icons.add_rounded,
      palette: p,
      size: size,
    ),
  ];
}

List<Widget> _menuButtons(HudActions a, ThemePalette p, double size) => [
  RoundButton(
    key: const Key('levels-button'),
    tooltip: 'Levels (L)',
    onPressed: a.onLevels,
    icon: Icons.grid_view_rounded,
    palette: p,
    size: size,
  ),
  RoundButton(
    key: const Key('themes-button'),
    tooltip: 'Themes (P)',
    onPressed: a.onThemes,
    icon: Icons.palette_rounded,
    palette: p,
    size: size,
  ),
  RoundButton(
    key: const Key('sound-toggle'),
    tooltip: a.soundMuted ? 'Sound off' : 'Sound on',
    onPressed: a.onToggleSound,
    icon: a.soundMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
    palette: p,
    size: size,
  ),
  RoundButton(
    key: const Key('how-to-play-button'),
    tooltip: 'How to play',
    onPressed: a.onHelp,
    icon: Icons.help_outline_rounded,
    palette: p,
    size: size,
  ),
];

TextStyle _title(ThemePalette p, double size) =>
    TextStyle(color: p.text, fontSize: size, fontWeight: FontWeight.w900);

TextStyle _body(ThemePalette p, double size) =>
    TextStyle(color: p.text, fontSize: size, fontWeight: FontWeight.w700);

String _bestText(GameController ctrl) {
  final best = ctrl.progress.bestMovesFor(ctrl.level);
  if (best > 0) return 'Best $best';
  if (ctrl.progress.isCleared(ctrl.level)) return 'Cleared';
  return 'New level';
}

class _PlayerLevel extends StatelessWidget {
  const _PlayerLevel({required this.ctrl, required this.palette});
  final GameController ctrl;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final pr = ctrl.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('Lv ${pr.playerLevel}', style: _title(palette, 22)),
            const Spacer(),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${pr.xpIntoLevel} / ${pr.xpForNextLevel} XP',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GameProgressBar(
          palette: palette,
          value: pr.xpForNextLevel == 0
              ? 0
              : pr.xpIntoLevel / pr.xpForNextLevel,
        ),
      ],
    );
  }
}

/// Left panel on wide screens: level, moves, par, star meter, best, tools.
class WideLeftPanel extends StatelessWidget {
  const WideLeftPanel({super.key, required this.ctrl, required this.palette});
  final GameController ctrl;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GamePanel(
            palette: p,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanelCaption('Puzzle', palette: p),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Level ${ctrl.level}', style: _title(p, 30)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Moves ${ctrl.game.moves}',
                          style: _body(p, 18),
                        ),
                      ),
                    ),
                    Text(
                      'Par ${ctrl.par}',
                      style: _body(p, 15).copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    StarRow(
                      count: ctrl.starsNow,
                      palette: p,
                      size: 26,
                      spacing: 4,
                    ),
                    const Spacer(),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _bestText(ctrl),
                          style: _body(p, 13).copyWith(color: p.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GamePanel(
            palette: p,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanelCaption('Tools', palette: p),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _playButtons(ctrl, p, 46),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Right panel on wide screens: player level, stars, menus.
class WideRightPanel extends StatelessWidget {
  const WideRightPanel({
    super.key,
    required this.ctrl,
    required this.palette,
    required this.actions,
  });
  final GameController ctrl;
  final ThemePalette palette;
  final HudActions actions;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GamePanel(
            palette: p,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PanelCaption('Player', palette: p),
                const SizedBox(height: 4),
                _PlayerLevel(ctrl: ctrl, palette: p),
                const SizedBox(height: 12),
                Row(
                  children: [
                    StarShape(size: 22, filled: true, palette: p),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${ctrl.progress.totalStars} stars',
                          style: _body(p, 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Theme: ${ctrl.progress.selectedTheme.label}',
                    style: _body(p, 13).copyWith(color: p.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GamePanel(
            palette: p,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanelCaption('Menu', palette: p),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _menuButtons(actions, p, 46),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top bar on narrow screens.
class NarrowTopBar extends StatelessWidget {
  const NarrowTopBar({
    super.key,
    required this.ctrl,
    required this.palette,
    required this.actions,
  });
  final GameController ctrl;
  final ThemePalette palette;
  final HudActions actions;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final pr = ctrl.progress;
    return GamePanel(
      palette: p,
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Level ${ctrl.level}', style: _title(p, 22)),
                      const SizedBox(width: 12),
                      Text('Moves ${ctrl.game.moves}', style: _body(p, 15)),
                      const SizedBox(width: 8),
                      Text(
                        'Par ${ctrl.par}',
                        style: _body(p, 13).copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              StarRow(count: ctrl.starsNow, palette: p, size: 18),
              const SizedBox(width: 6),
              RoundButton(
                key: const Key('sound-toggle'),
                tooltip: actions.soundMuted ? 'Sound off' : 'Sound on',
                onPressed: actions.onToggleSound,
                icon: actions.soundMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                palette: p,
                size: 38,
              ),
              const SizedBox(width: 6),
              RoundButton(
                key: const Key('how-to-play-button'),
                tooltip: 'How to play',
                onPressed: actions.onHelp,
                icon: Icons.help_outline_rounded,
                palette: p,
                size: 38,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Lv ${pr.playerLevel}', style: _body(p, 13)),
              const SizedBox(width: 8),
              Expanded(
                child: GameProgressBar(
                  palette: p,
                  height: 8,
                  value: pr.xpForNextLevel == 0
                      ? 0
                      : pr.xpIntoLevel / pr.xpForNextLevel,
                ),
              ),
              const SizedBox(width: 8),
              StarShape(size: 14, filled: true, palette: p),
              const SizedBox(width: 3),
              Text('${pr.totalStars}', style: _body(p, 13)),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: Text(
                  _bestText(ctrl),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(p, 12).copyWith(color: p.textSecondary),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom tool bar on narrow screens.
class NarrowBottomBar extends StatelessWidget {
  const NarrowBottomBar({
    super.key,
    required this.ctrl,
    required this.palette,
    required this.actions,
  });
  final GameController ctrl;
  final ThemePalette palette;
  final HudActions actions;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final buttons = [
      ..._playButtons(ctrl, p, 46),
      RoundButton(
        key: const Key('levels-button'),
        tooltip: 'Levels (L)',
        onPressed: actions.onLevels,
        icon: Icons.grid_view_rounded,
        palette: p,
        size: 46,
      ),
      RoundButton(
        key: const Key('themes-button'),
        tooltip: 'Themes (P)',
        onPressed: actions.onThemes,
        icon: Icons.palette_rounded,
        palette: p,
        size: 46,
      ),
    ];
    return GamePanel(
      palette: p,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) SizedBox(width: i == 3 ? 22 : 10),
              buttons[i],
            ],
          ],
        ),
      ),
    );
  }
}
