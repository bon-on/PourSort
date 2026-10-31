import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pour_sort/logic/level_generator.dart';
import 'package:pour_sort/logic/progress_store.dart';
import 'package:pour_sort/logic/solver.dart';
import 'package:pour_sort/main.dart';
import 'package:pour_sort/ui/how_to_play.dart';

class _BrokenTutorialStore implements TutorialStore {
  @override
  Future<bool> isSeen() async => throw StateError('no prefs');
  @override
  Future<void> markSeen() async => throw StateError('disk full');
}

class _PendingTutorialStore implements TutorialStore {
  final Completer<bool> answer = Completer<bool>();
  @override
  Future<bool> isSeen() => answer.future;
  @override
  Future<void> markSeen() async {}
}

Future<void> _launch(
  WidgetTester t,
  TutorialStore tutorial, {
  Size size = const Size(390, 844),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    PourSortApp(
      key: UniqueKey(),
      store: MemoryProgressStore(),
      tutorialStore: tutorial,
    ),
  );
  await t.pumpAndSettle();
}

final _overlay = find.byKey(const Key('how-to-play'));
final _text = find.byKey(const Key('how-to-play-text'));

void main() {
  final first = legalMoves(generateLevel(1).tubes).first;
  final digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
  ];

  testWidgets('first launch shows overlay and blocks taps and game keys', (
    t,
  ) async {
    await _launch(t, MemoryTutorialStore());
    expect(_overlay, findsOneWidget);
    expect(find.text('How to play'), findsOneWidget);

    await t.tap(find.byKey(Key('tube-${first.from}')), warnIfMissed: false);
    await t.tap(find.byKey(Key('tube-${first.to}')), warnIfMissed: false);
    await t.tap(find.byKey(const Key('add-tube')), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('tube-5')), findsNothing);
    expect(find.text('Moves 0'), findsOneWidget);

    await t.sendKeyEvent(digits[first.from]);
    await t.sendKeyEvent(digits[first.to]);
    await t.sendKeyEvent(LogicalKeyboardKey.keyA);
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    await t.sendKeyEvent(LogicalKeyboardKey.keyR);
    await t.pumpAndSettle();
    expect(find.text('Moves 0'), findsOneWidget);
    expect(find.byKey(const Key('tube-5')), findsNothing);
    expect(_overlay, findsOneWidget);
  });

  testWidgets('Next walks steps, Play closes and stores the flag', (t) async {
    final store = MemoryTutorialStore();
    await _launch(t, store);
    expect(find.text('Next'), findsOneWidget);
    expect(_text, findsOneWidget);
    final firstText = (t.widget(_text) as Text).data;
    await t.tap(find.byKey(const Key('how-to-play-next')));
    await t.pump();
    expect((t.widget(_text) as Text).data, isNot(firstText));
    await t.tap(find.byKey(const Key('how-to-play-next')));
    await t.pump();
    expect(find.text('Play'), findsOneWidget);
    expect(store.seen, isFalse);
    await t.tap(find.byKey(const Key('how-to-play-next')));
    await t.pumpAndSettle();
    expect(_overlay, findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('Skip closes and stores the flag; Escape also skips', (t) async {
    final store = MemoryTutorialStore();
    await _launch(t, store);
    await t.tap(find.byKey(const Key('how-to-play-skip')));
    await t.pumpAndSettle();
    expect(_overlay, findsNothing);
    expect(store.seen, isTrue);

    final store2 = MemoryTutorialStore();
    await _launch(t, store2);
    expect(_overlay, findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(_overlay, findsNothing);
    expect(store2.seen, isTrue);
  });

  testWidgets('Enter, Space and arrows navigate without reaching the game', (
    t,
  ) async {
    final store = MemoryTutorialStore();
    await _launch(t, store, size: const Size(1280, 720));
    final t0 = (t.widget(_text) as Text).data;
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    final t1 = (t.widget(_text) as Text).data;
    expect(t1, isNot(t0));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pump();
    expect((t.widget(_text) as Text).data, t0);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(find.text('Play'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(_overlay, findsNothing);
    expect(store.seen, isTrue);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Moves 0'), findsOneWidget);
  });

  testWidgets('overlay does not appear when the flag is set', (t) async {
    await _launch(t, MemoryTutorialStore(seen: true));
    expect(_overlay, findsNothing);
  });

  testWidgets('storage failures never break play', (t) async {
    await _launch(t, _BrokenTutorialStore());
    expect(_overlay, findsOneWidget);
    await t.tap(find.byKey(const Key('how-to-play-skip')));
    await t.pumpAndSettle();
    expect(_overlay, findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('? reopens at step 1 without resetting the game', (t) async {
    await _launch(t, MemoryTutorialStore(seen: true));
    await t.tap(find.byKey(Key('tube-${first.from}')));
    await t.pump();
    await t.tap(find.byKey(Key('tube-${first.to}')));
    await t.pumpAndSettle();
    expect(find.text('Moves 1'), findsOneWidget);

    await t.tap(find.byKey(const Key('how-to-play-button')));
    await t.pump();
    expect(_overlay, findsOneWidget);
    final t0 = (t.widget(_text) as Text).data;
    await t.tap(find.byKey(const Key('how-to-play-next')));
    await t.pump();
    await t.tap(
      find.byKey(const Key('how-to-play-button')),
      warnIfMissed: false,
    );
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(_overlay, findsNothing);
    expect(find.text('Moves 1'), findsOneWidget);

    await t.tap(find.byKey(const Key('how-to-play-button')));
    await t.pump();
    expect((t.widget(_text) as Text).data, t0);
    await t.tap(find.byKey(const Key('how-to-play-skip')));
    await t.pumpAndSettle();
    expect(find.text('Moves 1'), findsOneWidget);
    // Game keys work again after closing.
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    await t.pumpAndSettle();
    expect(find.text('Moves 0'), findsOneWidget);
  });

  for (final size in const [
    Size(390, 844),
    Size(844, 390),
    Size(1280, 720),
    Size(320, 640),
  ]) {
    testWidgets('overlay fits $size', (t) async {
      await _launch(t, MemoryTutorialStore(), size: size);
      expect(_overlay, findsOneWidget);
      final r = t.getRect(_overlay);
      expect(r.width, lessThanOrEqualTo(360));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(size.height));
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('browser keys and shortcuts stay unhandled while open', (
    t,
  ) async {
    final seen = <LogicalKeyboardKey>[];
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      Focus(
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent) seen.add(e.logicalKey);
          return KeyEventResult.ignored;
        },
        child: PourSortApp(
          key: UniqueKey(),
          store: MemoryProgressStore(),
          tutorialStore: MemoryTutorialStore(),
        ),
      ),
    );
    await t.pumpAndSettle();

    await t.sendKeyEvent(LogicalKeyboardKey.f5);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    expect(seen, contains(LogicalKeyboardKey.f5));
    expect(seen, contains(LogicalKeyboardKey.enter));
    expect(_overlay, findsOneWidget, reason: 'Ctrl+Enter must not advance');
    expect(
      (t.widget(_text) as Text).data,
      pourSortSteps.first.text,
      reason: 'still on step 1',
    );
  });

  testWidgets('Tab and Space cannot press HUD buttons while loading', (
    t,
  ) async {
    final store = _PendingTutorialStore();
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      PourSortApp(store: MemoryProgressStore(), tutorialStore: store),
    );
    await t.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 6; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
    }
    store.answer.complete(true);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('tube-5')), findsNothing);
    expect(find.text('Moves 0'), findsOneWidget);
  });

  testWidgets('key repeat does not act on the game after the card closes', (
    t,
  ) async {
    await _launch(t, MemoryTutorialStore());
    // Both keys are held while the card is open, then the card closes.
    await t.sendKeyDownEvent(digits[first.from]);
    await t.sendKeyDownEvent(digits[first.to]);
    await t.tap(find.byKey(const Key('how-to-play-skip')));
    await t.pump();
    await t.sendKeyRepeatEvent(digits[first.from]);
    await t.sendKeyRepeatEvent(digits[first.to]);
    await t.pump();
    expect(find.text('Moves 0'), findsOneWidget);
    await t.sendKeyUpEvent(digits[first.to]);
    await t.sendKeyUpEvent(digits[first.from]);
  });
}
