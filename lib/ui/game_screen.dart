import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/scenery.dart';
import '../art/theme_palette.dart';
import '../audio/sound_fx.dart';
import '../audio/sound_mute_store.dart';
import '../logic/player_progress.dart';
import '../logic/progress_store.dart';
import '../platform/game_platform.dart';
import 'board_fx.dart';
import 'board_view.dart';
import 'game_controller.dart';
import 'how_to_play.dart';
import 'hud.dart';
import 'overlays.dart';

export 'board_view.dart' show tubeKeyLabel;

const _digitKeys = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
  LogicalKeyboardKey.digit0,
  LogicalKeyboardKey.keyQ,
  LogicalKeyboardKey.keyW,
  LogicalKeyboardKey.keyE,
  LogicalKeyboardKey.keyT,
  LogicalKeyboardKey.keyY,
  LogicalKeyboardKey.keyI,
];

/// Keys the browser owns (focus change, reload, Ctrl/Meta/Alt shortcuts) stay
/// unhandled so the overlays do not block them on web.
bool _isBrowserShortcut(KeyEvent e) {
  final k = e.logicalKey;
  if (k == LogicalKeyboardKey.tab || k == LogicalKeyboardKey.f5) return true;
  final kb = HardwareKeyboard.instance;
  return kb.isControlPressed || kb.isMetaPressed || kb.isAltPressed;
}

bool _isEnter(LogicalKeyboardKey k) =>
    k == LogicalKeyboardKey.enter ||
    k == LogicalKeyboardKey.numpadEnter ||
    k == LogicalKeyboardKey.space;

/// Wide layout (side panels) when the screen is clearly landscape.
bool isWideLayout(Size s) => s.width >= 700 && s.width >= s.height * 1.25;

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.store,
    this.tutorialStore,
    this.platform = const NoopGamePlatform(),
    this.soundMuteStore = const SoundMuteStore(),
    this.onSfxPlayed,
  });

  final ProgressStore store;

  /// Receives gameplay start/stop events (CrazyGames SDK on portal builds).
  final GamePlatform platform;

  /// Persisted user mute choice; tests inject a fake.
  final SoundMuteStore soundMuteStore;

  /// Called for every sound that is actually played (not muted); for tests.
  final void Function(Sfx sfx)? onSfxPlayed;

  /// Defaults to [PrefsTutorialStore].
  final TutorialStore? tutorialStore;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _Overlay { none, levels, themes }

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final GameController _ctrl = GameController(widget.store);
  late final BoardFx _fx = BoardFx(this);
  final FocusNode _focus = FocusNode();
  late final AppLifecycleListener _lifecycle;

  int _seenSerial = 0;
  int _seenLevelSerial = 0;
  int? _seenSelected;
  int _combo = 0;
  int _lastCompleteSerial = -10;
  int _seenUndoSerial = 0;

  // Input stays blocked until the tutorial flag has been read.
  bool _tutorialChecked = false;
  bool _tutorialOpen = false;
  int _tutorialStep = 0;
  late final TutorialStore _tutorialStore =
      widget.tutorialStore ?? PrefsTutorialStore();

  _Overlay _overlay = _Overlay.none;
  int _levelCursor = 1;
  int _themeCursor = 0;

  // User sound toggle; effective mute also includes the platform mute.
  bool _soundMuted = false;
  bool _soundTouched = false;
  late final SoundFx _sfx = SoundFx(
    isMuted: () => _soundMuted || widget.platform.isAudioMuted,
    onPlay: widget.onSfxPlayed,
  );

  bool get _inputBlocked =>
      !_tutorialChecked || _tutorialOpen || _overlay != _Overlay.none;

  // Whether the platform currently believes gameplay is running.
  bool _gameplayActive = false;

  /// Reports gameplay start/stop to the platform exactly on transitions.
  void _syncGameplay() {
    final wantActive =
        _ctrl.loaded &&
        _tutorialChecked &&
        !_tutorialOpen &&
        _overlay == _Overlay.none &&
        !_ctrl.won;
    if (wantActive == _gameplayActive) return;
    _gameplayActive = wantActive;
    if (wantActive) {
      widget.platform.gameplayStart();
    } else {
      widget.platform.gameplayStop();
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChange);
    _ctrl.init();
    _checkTutorial();
    _loadSoundMuted();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) => _sfx.setAppVisible(
        state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive,
      ),
    );
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    widget.platform.setAudioMuteListener(_sfx.refreshMute);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fx.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  Future<void> _loadSoundMuted() async {
    var muted = false;
    try {
      muted = await widget.soundMuteStore.loadMuted();
    } catch (_) {}
    if (!mounted) return;
    if (!_soundTouched) setState(() => _soundMuted = muted);
    // Music waits for the stored mute so a muted player never hears a blip
    // (and, on web, for the first user input).
    _sfx.startMusic();
  }

  void _toggleSound() {
    _soundTouched = true;
    final muted = !_soundMuted;
    setState(() => _soundMuted = muted);
    _sfx.refreshMute();
    () async {
      try {
        await widget.soundMuteStore.saveMuted(muted);
      } catch (_) {}
    }();
    _focus.requestFocus();
  }

  /// Any pointer or key input: browsers only allow music after one, and the
  /// platform mute may have changed meanwhile.
  void _onAnyInput() {
    _sfx.onUserInput();
    _sfx.refreshMute();
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent) _onAnyInput();
    return false;
  }

  /// Taps a tube and plays one sound for the outcome.
  void _tap(int i) {
    if (!_ctrl.loaded || _ctrl.won || _inputBlocked) return;
    if (i < 0 || i >= _ctrl.game.tubes.length) return;
    final before = _ctrl.selected;
    final serial = _ctrl.moveSerial;
    _ctrl.tap(i);
    final after = _ctrl.selected;
    if (_ctrl.moveSerial != serial) {
      if (_ctrl.won) {
        _sfx.play(Sfx.levelClear);
        if (_ctrl.outcome?.leveledUp ?? false) _sfx.play(Sfx.levelUp);
      } else {
        _sfx.play(Sfx.pour);
        final to = _ctrl.lastMove?.to;
        if (to != null && isCompleteTube(_ctrl.game.tubes[to])) {
          _sfx.play(Sfx.cork);
        }
      }
    } else if (before == null) {
      // First pick: select a tube, or reject an empty one.
      _sfx.play(after != null ? Sfx.select : Sfx.invalid);
    } else if (before != i) {
      // A target that cannot take the pour (the controller may re-select it).
      _sfx.play(Sfx.invalid);
    }
  }

  Future<void> _checkTutorial() async {
    var seen = false;
    try {
      seen = await _tutorialStore.isSeen();
    } catch (_) {
      seen = false;
    }
    if (!mounted) return;
    setState(() {
      _tutorialChecked = true;
      _tutorialOpen = !seen;
      _tutorialStep = 0;
    });
    _syncGameplay();
  }

  void _openTutorial() {
    setState(() {
      _tutorialOpen = true;
      _tutorialStep = 0;
    });
    _syncGameplay();
    _focus.requestFocus();
  }

  void _closeTutorial() {
    setState(() => _tutorialOpen = false);
    _syncGameplay();
    _focus.requestFocus();
    () async {
      try {
        await _tutorialStore.markSeen();
      } catch (_) {}
    }();
  }

  void _tutorialNext() {
    if (_tutorialStep >= pourSortSteps.length - 1) {
      _closeTutorial();
    } else {
      setState(() => _tutorialStep++);
    }
  }

  void _tutorialPrev() {
    if (_tutorialStep > 0) setState(() => _tutorialStep--);
  }

  void _openLevels() {
    if (!_ctrl.loaded) return;
    setState(() {
      _overlay = _Overlay.levels;
      _levelCursor = _ctrl.level.clamp(1, _ctrl.progress.highestLevel);
    });
    _syncGameplay();
    _focus.requestFocus();
  }

  void _openThemes() {
    if (!_ctrl.loaded) return;
    setState(() {
      _overlay = _Overlay.themes;
      _themeCursor = PourTheme.values.indexOf(_ctrl.progress.selectedTheme);
    });
    _syncGameplay();
    _focus.requestFocus();
  }

  void _closeOverlay() {
    if (_overlay == _Overlay.none) return;
    setState(() => _overlay = _Overlay.none);
    _syncGameplay();
    _focus.requestFocus();
  }

  void _pickLevel(int level) {
    if (!_ctrl.progress.isUnlocked(level)) {
      _sfx.play(Sfx.invalid);
      return;
    }
    _sfx.play(Sfx.unlock);
    setState(() => _overlay = _Overlay.none);
    _ctrl.playLevel(level);
    _syncGameplay();
    _focus.requestFocus();
  }

  void _pickTheme(PourTheme theme) {
    if (!_ctrl.progress.isThemeUnlocked(theme)) {
      _sfx.play(Sfx.invalid);
      return;
    }
    _sfx.play(Sfx.unlock);
    _ctrl.selectTheme(theme);
    setState(() {
      _themeCursor = PourTheme.values.indexOf(theme);
    });
  }

  void _onChange() {
    if (!_ctrl.loaded) {
      if (mounted) setState(() {});
      return;
    }
    final n = _ctrl.game.tubes.length;
    if (_ctrl.levelSerial != _seenLevelSerial) {
      _seenLevelSerial = _ctrl.levelSerial;
      _seenSerial = _ctrl.moveSerial;
      _combo = 0;
      _lastCompleteSerial = -10;
      _seenUndoSerial = _ctrl.undoSerial;
      _fx.clear();
      _fx.resetLift();
      _seenSelected = null;
    }
    if (_ctrl.moveSerial != _seenSerial && _ctrl.lastMove != null) {
      _seenSerial = _ctrl.moveSerial;
      final m = _ctrl.lastMove!;
      final target = _ctrl.game.tubes[m.to];
      final completes = isCompleteTube(target);
      if (completes) {
        _combo = _lastCompleteSerial == _ctrl.moveSerial - 1 ? _combo + 1 : 1;
        _lastCompleteSerial = _ctrl.moveSerial;
      }
      _fx.setSelected(null, n, instant: m.from);
      _seenSelected = null;
      _fx.addPour(
        m,
        fromWasLifted: true,
        completesTarget: completes,
        targetFillAfter: target.length,
        won: _ctrl.won,
        tubeCount: n,
      );
      if (completes && _combo >= 2 && !_ctrl.won) {
        _fx.showBanner('Combo x$_combo', delay: BoardFx.pourDuration * 0.8);
      }
    }
    if (_ctrl.undoSerial != _seenUndoSerial) {
      // Undo: every effect would show stale tubes, and a redo is no combo.
      _seenUndoSerial = _ctrl.undoSerial;
      _fx.clear();
      _combo = 0;
      _lastCompleteSerial = -10;
    }
    if (_ctrl.selected != _seenSelected) {
      _seenSelected = _ctrl.selected;
      _fx.setSelected(_ctrl.selected, n);
    }
    _syncGameplay();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    widget.platform.setAudioMuteListener(null);
    _lifecycle.dispose();
    _ctrl.removeListener(_onChange);
    _ctrl.dispose();
    _fx.dispose();
    _focus.dispose();
    _sfx.stopMusic();
    _sfx.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (_tutorialOpen) {
      if (_isBrowserShortcut(e)) return KeyEventResult.ignored;
      if (e is KeyDownEvent) {
        final k = e.logicalKey;
        if (_isEnter(k)) {
          _tutorialNext();
        } else if (k == LogicalKeyboardKey.arrowRight) {
          if (_tutorialStep < pourSortSteps.length - 1) _tutorialNext();
        } else if (k == LogicalKeyboardKey.escape) {
          _closeTutorial();
        } else if (k == LogicalKeyboardKey.arrowLeft) {
          _tutorialPrev();
        }
      }
      return KeyEventResult.handled;
    }
    if (_overlay != _Overlay.none) {
      if (_isBrowserShortcut(e)) return KeyEventResult.ignored;
      if (e is KeyDownEvent || e is KeyRepeatEvent) _overlayKey(e.logicalKey);
      return KeyEventResult.handled;
    }
    if (e is! KeyDownEvent || !_ctrl.loaded || _inputBlocked) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (_ctrl.won) {
      if (_isEnter(k) ||
          k == LogicalKeyboardKey.keyN ||
          k == LogicalKeyboardKey.escape) {
        _ctrl.nextLevel();
      } else if (k == LogicalKeyboardKey.keyR) {
        _ctrl.restart();
      } else if (k == LogicalKeyboardKey.keyL) {
        _openLevels();
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyU) {
      _ctrl.undo();
    } else if (k == LogicalKeyboardKey.keyR) {
      _ctrl.restart();
    } else if (k == LogicalKeyboardKey.keyA) {
      _ctrl.addTube();
    } else if (k == LogicalKeyboardKey.keyL) {
      _openLevels();
    } else if (k == LogicalKeyboardKey.keyP) {
      _openThemes();
    } else {
      final idx = _digitKeys.indexOf(k);
      if (idx < 0) return KeyEventResult.ignored;
      _tap(idx);
    }
    return KeyEventResult.handled;
  }

  void _overlayKey(LogicalKeyboardKey k) {
    if (k == LogicalKeyboardKey.escape) {
      _closeOverlay();
      return;
    }
    if (_overlay == _Overlay.levels) {
      final count = levelSelectCount(_ctrl.progress);
      var c = _levelCursor;
      if (k == LogicalKeyboardKey.arrowRight) c++;
      if (k == LogicalKeyboardKey.arrowLeft) c--;
      if (k == LogicalKeyboardKey.arrowDown) c += LevelSelectOverlay.columns;
      if (k == LogicalKeyboardKey.arrowUp) c -= LevelSelectOverlay.columns;
      if (k == LogicalKeyboardKey.keyL) {
        _closeOverlay();
        return;
      }
      if (_isEnter(k)) {
        _pickLevel(_levelCursor);
        return;
      }
      c = c.clamp(1, math.min(count, _ctrl.progress.highestLevel));
      if (c != _levelCursor) setState(() => _levelCursor = c);
    } else if (_overlay == _Overlay.themes) {
      var c = _themeCursor;
      if (k == LogicalKeyboardKey.arrowRight ||
          k == LogicalKeyboardKey.arrowDown) {
        c++;
      }
      if (k == LogicalKeyboardKey.arrowLeft ||
          k == LogicalKeyboardKey.arrowUp) {
        c--;
      }
      if (k == LogicalKeyboardKey.keyP) {
        _closeOverlay();
        return;
      }
      if (_isEnter(k)) {
        final t = PourTheme.values[_themeCursor];
        if (_ctrl.progress.selectedTheme == t) {
          _closeOverlay();
        } else {
          _pickTheme(t);
        }
        return;
      }
      c = c.clamp(0, PourTheme.values.length - 1);
      if (c != _themeCursor) setState(() => _themeCursor = c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _ctrl.progress.selectedTheme;
    final palette = ThemePalette.of(theme);
    final actions = HudActions(
      onHelp: _openTutorial,
      onToggleSound: _toggleSound,
      onLevels: _openLevels,
      onThemes: _openThemes,
      soundMuted: _soundMuted,
    );
    final outcome = _ctrl.loaded && _ctrl.won ? _ctrl.outcome : null;
    return Listener(
      onPointerDown: (_) => _onAnyInput(),
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: palette.skyBottom,
          body: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: SceneryPainter(theme)),
                ),
              ),
              // No focus (and so no Tab + Space button presses) reaches the
              // game while the seen flag loads or an overlay is open.
              ExcludeFocus(
                excluding: _inputBlocked || outcome != null,
                child: SafeArea(
                  child: !_ctrl.loaded
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (context, box) => _layout(
                            Size(box.maxWidth, box.maxHeight),
                            palette,
                            actions,
                          ),
                        ),
                ),
              ),
              if (outcome != null)
                Positioned.fill(
                  child: WinCard(
                    key: ValueKey('win-${_ctrl.levelSerial}'),
                    outcome: outcome,
                    progress: _ctrl.progress,
                    palette: palette,
                    animate: !_fx.reduceMotion,
                    onNext: () {
                      _ctrl.nextLevel();
                      _focus.requestFocus();
                    },
                    onReplay: () {
                      _ctrl.restart();
                      _focus.requestFocus();
                    },
                    onLevels: _openLevels,
                  ),
                ),
              if (_overlay == _Overlay.levels)
                Positioned.fill(
                  child: LevelSelectOverlay(
                    progress: _ctrl.progress,
                    palette: palette,
                    cursor: _levelCursor,
                    current: _ctrl.level,
                    onPick: _pickLevel,
                    onClose: _closeOverlay,
                  ),
                ),
              if (_overlay == _Overlay.themes)
                Positioned.fill(
                  child: ThemeOverlay(
                    progress: _ctrl.progress,
                    palette: palette,
                    cursor: _themeCursor,
                    onPick: _pickTheme,
                    onClose: _closeOverlay,
                  ),
                ),
              if (!_tutorialChecked)
                const Positioned.fill(child: AbsorbPointer()),
              if (_tutorialOpen)
                Positioned.fill(
                  child: HowToPlayOverlay(
                    steps: pourSortSteps,
                    step: _tutorialStep,
                    onNext: _tutorialNext,
                    onSkip: _closeTutorial,
                    palette: palette,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _board(ThemePalette palette) {
    return Stack(
      children: [
        Positioned.fill(
          child: BoardView(
            tubes: _ctrl.game.tubes,
            selected: _ctrl.selected,
            palette: palette,
            fx: _fx,
            onTap: _tap,
          ),
        ),
        if (_ctrl.stuck)
          Positioned(
            left: 8,
            right: 8,
            bottom: 6,
            child: IgnorePointer(child: _StuckBanner(palette: palette)),
          ),
      ],
    );
  }

  Widget _layout(Size size, ThemePalette palette, HudActions actions) {
    if (isWideLayout(size)) {
      final side = (size.width * 0.2).clamp(170.0, 270.0);
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: side,
              child: Align(
                alignment: Alignment.topCenter,
                child: WideLeftPanel(ctrl: _ctrl, palette: palette),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _board(palette)),
            const SizedBox(width: 12),
            SizedBox(
              width: side,
              child: Align(
                alignment: Alignment.topCenter,
                child: WideRightPanel(
                  ctrl: _ctrl,
                  palette: palette,
                  actions: actions,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              NarrowTopBar(ctrl: _ctrl, palette: palette, actions: actions),
              const SizedBox(height: 6),
              Expanded(child: _board(palette)),
              const SizedBox(height: 6),
              NarrowBottomBar(ctrl: _ctrl, palette: palette, actions: actions),
            ],
          ),
        ),
      ),
    );
  }
}

class _StuckBanner extends StatelessWidget {
  const _StuckBanner({required this.palette});
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        key: const Key('stuck-banner'),
        decoration: BoxDecoration(
          color: palette.danger,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'No moves left - Undo (U) or add a tube (A)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
