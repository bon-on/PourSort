import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pour_sort/logic/level_generator.dart';
import 'package:pour_sort/logic/progress_store.dart';
import 'package:pour_sort/logic/solver.dart';
import 'package:pour_sort/main.dart';
import 'package:pour_sort/platform/game_platform.dart';
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

Future<_FakePlatform> _launch(
  WidgetTester t, {
  required bool tutorialSeen,
}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final platform = _FakePlatform();
  await t.pumpWidget(
    PourSortApp(
      store: MemoryProgressStore(),
      tutorialStore: MemoryTutorialStore()..seen = tutorialSeen,
      platform: platform,
    ),
  );
  await t.pumpAndSettle();
  return platform;
}

Future<void> _solveLevel(WidgetTester t) async {
  final tubes = generateLevel(1).tubes;
  for (final m in solve(tubes)!) {
    await t.tap(find.byKey(Key('tube-${m.from}')));
    await t.pump();
    await t.tap(find.byKey(Key('tube-${m.to}')));
    await t.pumpAndSettle();
  }
}

// Mirror the browser's inactive transition on both sides of hidden.
void _setLifecycle(WidgetTester tester, AppLifecycleState state) {
  if ((state == AppLifecycleState.hidden &&
          tester.binding.lifecycleState == AppLifecycleState.resumed) ||
      (state == AppLifecycleState.resumed &&
          tester.binding.lifecycleState == AppLifecycleState.hidden)) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  tester.binding.handleAppLifecycleStateChanged(state);
}

void main() {
  testWidgets('background pauses once and resume respects overlays', (
    tester,
  ) async {
    final platform = await _launch(tester, tutorialSeen: true);
    expect(platform.events, ['start']);
    addTearDown(() => _setLifecycle(tester, AppLifecycleState.resumed));
    _setLifecycle(tester, AppLifecycleState.inactive);
    await tester.pump();
    _setLifecycle(tester, AppLifecycleState.hidden);
    await tester.pump();
    expect(platform.events, ['start', 'stop']);
    _setLifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.events, ['start', 'stop', 'start']);
    await tester.tap(find.byKey(const Key('how-to-play-button')));
    await tester.pump();
    expect(platform.events, ['start', 'stop', 'start', 'stop']);
    _setLifecycle(tester, AppLifecycleState.hidden);
    await tester.pump();
    _setLifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.events, [
      'start',
      'stop',
      'start',
      'stop',
    ], reason: 'an open tutorial stays stopped after resume');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(platform.events, ['start', 'stop', 'start', 'stop', 'start']);
  });

  testWidgets('seen tutorial: start, overlay stop/start, restart no dupes', (
    t,
  ) async {
    final platform = await _launch(t, tutorialSeen: true);
    expect(platform.events, ['start']);

    await t.tap(find.byKey(const Key('restart')));
    await t.pump();
    expect(platform.events, ['start'], reason: 'restart is not a transition');

    await t.tap(find.byKey(const Key('how-to-play-button')));
    await t.pump();
    expect(platform.events, ['start', 'stop']);

    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(platform.events, ['start', 'stop', 'start']);
  });

  testWidgets('first launch starts only after the tutorial closes', (t) async {
    final platform = await _launch(t, tutorialSeen: false);
    expect(platform.events, isEmpty);

    await t.tap(find.byKey(const Key('how-to-play-skip')));
    await t.pump();
    expect(platform.events, ['start']);
  });

  testWidgets('clearing a level stops, next level starts', (t) async {
    final platform = await _launch(t, tutorialSeen: true);
    await _solveLevel(t);
    expect(find.byKey(const Key('next-level')), findsOneWidget);
    expect(platform.events, ['start', 'stop']);

    await t.tap(find.byKey(const Key('next-level')));
    await t.pumpAndSettle();
    expect(platform.events, ['start', 'stop', 'start']);
  });
}
