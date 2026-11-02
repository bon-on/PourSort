import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pour_sort/art/scenery.dart';
import 'package:pour_sort/art/theme_palette.dart';
import 'package:pour_sort/art/tube_art.dart';
import 'package:pour_sort/logic/level_generator.dart';
import 'package:pour_sort/logic/player_progress.dart';
import 'package:pour_sort/logic/pour_game.dart';
import 'package:pour_sort/logic/progress_store.dart';
import 'package:pour_sort/logic/solver.dart';
import 'package:pour_sort/main.dart';
import 'package:pour_sort/platform/game_platform.dart';
import 'package:pour_sort/ui/game_controller.dart';
import 'package:pour_sort/ui/how_to_play.dart';

class _FakePlatform extends GamePlatform {
  final List<String> events = <String>[];
  @override
  Future<void> initialize() async {}
  @override
  void gameplayStart() => events.add('start');
  @override
  void gameplayStop() => events.add('stop');
}

PlayerProgress _veteran({int xp = 0, int highest = 8}) => PlayerProgress(
  lastLevel: highest,
  highestLevel: highest,
  records: const {},
  totalXp: xp,
  selectedTheme: PourTheme.lab,
);

Future<MemoryProgressStore> _launch(
  WidgetTester t,
  Size size, {
  PlayerProgress? progress,
  GamePlatform platform = const NoopGamePlatform(),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final store = MemoryProgressStore.withProgress(
    progress ?? const PlayerProgress.initial(),
  );
  await t.pumpWidget(
    PourSortApp(
      key: UniqueKey(),
      store: store,
      tutorialStore: MemoryTutorialStore(seen: true),
      platform: platform,
    ),
  );
  await t.pumpAndSettle();
  return store;
}

Future<void> _solve(WidgetTester t, int level) async {
  for (final m in solve(generateLevel(level).tubes)!) {
    await t.tap(find.byKey(Key('tube-${m.from}')));
    await t.pump();
    await t.tap(find.byKey(Key('tube-${m.to}')));
    await t.pump(const Duration(milliseconds: 60));
  }
  await t.pumpAndSettle();
}

void main() {
  test('every tube band color x theme paints, upright and tilted', () {
    for (final theme in PourTheme.values) {
      final p = ThemePalette.of(theme);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      SceneryPainter(theme).paint(canvas, const Size(800, 600));
      final g = TubeGeometry(60, TubeGeometry.heightFor(60));
      for (var c = 0; c < 10; c++) {
        for (final angle in [0.0, 0.7, 1.6, -1.6]) {
          paintTube(
            canvas,
            g,
            [TubeBand(c, 1.5), TubeBand((c + 1) % 10, 2)],
            p,
            angle: angle,
            slosh: 0.5,
            ripple: 1,
            glow: 1,
            cork: 0.5,
          );
        }
      }
      recorder.endRecording().dispose();
    }
  });

  for (final size in const [
    Size(1280, 720),
    Size(1366, 768),
    Size(390, 844),
    Size(844, 390),
    Size(320, 640),
  ]) {
    testWidgets('screen, overlays and result fit $size', (t) async {
      await _launch(t, size);
      expect(t.takeException(), isNull);
      for (final key in ['levels-button', 'themes-button']) {
        await t.tap(find.byKey(Key(key)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
      }
      await _solve(t, 1);
      expect(find.byKey(const Key('win-card')), findsOneWidget);
      final r = t.getRect(find.byKey(const Key('next-level')));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(size.height));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('result shows stars, XP and saves the record', (t) async {
    final store = await _launch(t, const Size(1280, 720));
    await _solve(t, 1);
    expect(find.text('Level complete!'), findsOneWidget);
    expect(find.textContaining('XP'), findsWidgets);
    expect(store.progress.starsFor(1), 3, reason: 'solver path is par');
    expect(store.progress.highestLevel, 2);
    expect(store.level, 2);
    expect(store.progress.totalXp, 70);
    await t.tap(find.byKey(const Key('replay')));
    await t.pumpAndSettle();
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.byKey(const Key('win-card')), findsNothing);
  });

  testWidgets('pours apply instantly while the animation runs', (t) async {
    await _launch(t, const Size(390, 844));
    final moves = solve(generateLevel(1).tubes)!;
    final a = moves[0], b = moves[1];
    await t.tap(find.byKey(Key('tube-${a.from}')));
    await t.pump();
    await t.tap(find.byKey(Key('tube-${a.to}')));
    await t.pump(const Duration(milliseconds: 16));
    expect(find.text('Moves 1'), findsOneWidget);
    await t.tap(find.byKey(Key('tube-${b.from}')));
    await t.pump();
    await t.tap(find.byKey(Key('tube-${b.to}')));
    await t.pump(const Duration(milliseconds: 16));
    expect(find.text('Moves 2'), findsOneWidget);
    // Effects end and the ticker stops.
    await t.pumpAndSettle();
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('level select plays unlocked levels, ignores locked', (t) async {
    final platform = _FakePlatform();
    final store = await _launch(
      t,
      const Size(1280, 720),
      progress: _veteran(highest: 4),
      platform: platform,
    );
    expect(platform.events, ['start']);
    await t.sendKeyEvent(LogicalKeyboardKey.keyL);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('level-select')), findsOneWidget);
    expect(platform.events, ['start', 'stop']);
    // Board input is blocked while open.
    await t.sendKeyEvent(LogicalKeyboardKey.digit1);
    await t.pump();
    await t.tap(find.byKey(const Key('level-tile-9')));
    await t.pump();
    expect(find.byKey(const Key('level-select')), findsOneWidget);
    await t.tap(find.byKey(const Key('level-tile-2')));
    await t.pumpAndSettle();
    expect(find.text('Level 2'), findsOneWidget);
    expect(platform.events, ['start', 'stop', 'start']);
    expect(store.level, 2);
    expect(store.progress.highestLevel, 4);
    // Keyboard: L, arrow right, Enter.
    await t.sendKeyEvent(LogicalKeyboardKey.keyL);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.text('Level 3'), findsOneWidget);
  });

  testWidgets('level select keeps the keyboard cursor visible', (t) async {
    await _launch(t, const Size(1280, 720), progress: _veteran(highest: 80));
    await t.sendKeyEvent(LogicalKeyboardKey.keyL);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    for (var i = 0; i < 4; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    }
    await t.pumpAndSettle();
    // Cursor moved from 80 up to 55 (5 rows); its tile must be on screen.
    final r = t.getRect(find.byKey(const Key('level-tile-55')));
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(720));
    for (var i = 0; i < 12; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    }
    await t.pumpAndSettle();
    expect(find.byKey(const Key('level-tile-1')), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.text('Level 1'), findsOneWidget, reason: 'cursor clamps at 1');
  });

  testWidgets('win card Levels button opens level select', (t) async {
    await _launch(t, const Size(390, 844));
    await _solve(t, 1);
    await t.tap(find.byKey(const Key('win-levels')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('level-select')), findsOneWidget);
    await t.tap(find.byKey(const Key('level-tile-2')));
    await t.pumpAndSettle();
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.byKey(const Key('win-card')), findsNothing);
  });

  testWidgets('themes: locked cannot be picked, unlocked persists', (t) async {
    final store = await _launch(
      t,
      const Size(390, 844),
      progress: _veteran(xp: 240), // Lv3: Potion Shop unlocked.
    );
    await t.tap(find.byKey(const Key('themes-button')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('theme-picker')), findsOneWidget);
    await t.tap(find.byKey(const Key('theme-candy')));
    await t.pump();
    expect(store.progress.selectedTheme, PourTheme.lab);
    await t.tap(find.byKey(const Key('theme-potionShop')));
    await t.pumpAndSettle();
    expect(store.progress.selectedTheme, PourTheme.potionShop);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('theme-picker')), findsNothing);
  });

  test('controller reports a stuck board', () async {
    final ctrl = GameController(MemoryProgressStore());
    await ctrl.init();
    expect(ctrl.stuck, isFalse);
    ctrl.game = PourGame([
      [0, 1, 0, 1],
      [1, 0, 1, 0],
    ]);
    expect(ctrl.stuck, isTrue);
    ctrl.game = PourGame([
      [0, 0, 0, 0],
      [1, 1, 1, 1],
    ]);
    expect(ctrl.stuck, isFalse, reason: 'won is not stuck');
    ctrl.dispose();
  });
}
