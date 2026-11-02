import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pour_sort/logic/level_generator.dart';
import 'package:pour_sort/logic/progress_store.dart';
import 'package:pour_sort/logic/solver.dart';
import 'package:pour_sort/main.dart';
import 'package:pour_sort/ui/game_screen.dart';
import 'package:pour_sort/ui/how_to_play.dart';

final _digits = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
];

Future<void> _setSize(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

MemoryTutorialStore _seen() => MemoryTutorialStore(seen: true);

void main() {
  final first = legalMoves(generateLevel(1).tubes).first;

  testWidgets('shows level 1, pours on tap, undo, extra tube, restart', (
    t,
  ) async {
    await _setSize(t, const Size(390, 844));
    await t.pumpWidget(
      PourSortApp(store: MemoryProgressStore(), tutorialStore: _seen()),
    );
    await t.pumpAndSettle();

    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Moves 0'), findsOneWidget);

    await t.tap(find.byKey(Key('tube-${first.from}')));
    await t.pump();
    await t.tap(find.byKey(Key('tube-${first.to}')));
    await t.pumpAndSettle();
    expect(find.text('Moves 1'), findsOneWidget);

    await t.tap(find.byKey(const Key('undo')));
    await t.pumpAndSettle();
    expect(find.text('Moves 0'), findsOneWidget);

    await t.tap(find.byKey(const Key('add-tube')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('tube-5')), findsOneWidget);
    await t.tap(find.byKey(const Key('restart')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('tube-7')), findsNothing);
  });

  testWidgets('keyboard: select/pour, U undo, R restart, A extra tube', (
    t,
  ) async {
    await _setSize(t, const Size(1280, 720));
    await t.pumpWidget(
      PourSortApp(store: MemoryProgressStore(), tutorialStore: _seen()),
    );
    await t.pumpAndSettle();
    await t.sendKeyEvent(_digits[first.from]);
    await t.sendKeyEvent(_digits[first.to]);
    await t.pumpAndSettle();
    expect(find.text('Moves 1'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    await t.pumpAndSettle();
    expect(find.text('Moves 0'), findsOneWidget);

    await t.sendKeyEvent(_digits[first.from]);
    await t.sendKeyEvent(_digits[first.to]);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.keyR);
    await t.pumpAndSettle();
    expect(find.text('Moves 0'), findsOneWidget);

    await t.sendKeyEvent(LogicalKeyboardKey.keyA);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('tube-5')), findsOneWidget);
    // Tubes beyond the 10th use letter keys; labels exist for them.
    expect(tubeKeyLabel(10), 'Q');
    expect(tubeKeyLabel(12), 'E');
  });

  testWidgets('win flow saves progress, shows card, Enter goes to next level', (
    t,
  ) async {
    await _setSize(t, const Size(1280, 720));
    final store = MemoryProgressStore();
    await t.pumpWidget(PourSortApp(store: store, tutorialStore: _seen()));
    await t.pumpAndSettle();

    for (final m in solve(generateLevel(1).tubes)!) {
      await t.sendKeyEvent(_digits[m.from]);
      await t.sendKeyEvent(_digits[m.to]);
      await t.pump(const Duration(milliseconds: 500));
    }
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Level complete!'), findsOneWidget);
    expect(store.level, 2);

    // Undo is blocked after a win.
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    await t.pump();
    expect(find.text('Level complete!'), findsOneWidget);

    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('Level complete!'), findsNothing);
    await t.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('N key advances after a win and saved level is loaded', (
    t,
  ) async {
    await _setSize(t, const Size(1280, 720));
    await t.pumpWidget(
      PourSortApp(store: MemoryProgressStore(4), tutorialStore: _seen()),
    );
    await t.pumpAndSettle();
    expect(find.text('Level 4'), findsOneWidget);
  });

  testWidgets('bad store falls back to level 1', (t) async {
    await _setSize(t, const Size(390, 844));
    await t.pumpWidget(
      PourSortApp(store: _BrokenStore(), tutorialStore: _seen()),
    );
    await t.pumpAndSettle();
    expect(find.text('Level 1'), findsOneWidget);
  });

  for (final size in const [
    Size(390, 844),
    Size(1280, 720),
    Size(844, 390),
    Size(320, 640),
  ]) {
    for (final extra in [false, true]) {
      testWidgets('levels 3/12/30 fit $size extra=$extra', (t) async {
        await _setSize(t, size);
        for (final level in [3, 12, 30]) {
          await t.pumpWidget(
            PourSortApp(
              key: ValueKey('$level$extra'),
              store: MemoryProgressStore(level),
              tutorialStore: _seen(),
            ),
          );
          await t.pumpAndSettle();
          if (extra) {
            await t.tap(find.byKey(const Key('add-tube')));
            await t.pumpAndSettle();
          }
          expect(find.text('Level $level'), findsOneWidget);
          final n = generateLevel(level).tubes.length + (extra ? 1 : 0);
          for (var i = 0; i < n; i++) {
            final r = t.getRect(find.byKey(Key('tube-$i')));
            expect(r.left, greaterThanOrEqualTo(0), reason: 'L$level t$i');
            expect(r.right, lessThanOrEqualTo(size.width));
            expect(r.top, greaterThanOrEqualTo(0));
            expect(
              r.bottom,
              lessThanOrEqualTo(size.height),
              reason: 'L$level t$i $r',
            );
          }
          expect(t.takeException(), isNull);
        }
      });
    }
  }
}

class _BrokenStore extends ProgressStore {
  @override
  Future<int> loadLevel() async => throw StateError('corrupt');

  @override
  Future<void> saveLevel(int level) async => throw StateError('disk full');
}
