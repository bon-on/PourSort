import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pour_sort/logic/level_generator.dart';
import 'package:pour_sort/logic/progress_store.dart';
import 'package:pour_sort/logic/solver.dart';
import 'package:pour_sort/main.dart';

final _digits = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
];

void main() {
  final first = legalMoves(generateLevel(1).tubes).first;
  testWidgets('shows level 1, pours on tap, undo and restart work', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final store = MemoryProgressStore();
    await t.pumpWidget(PourSortApp(store: store));
    await t.pumpAndSettle();

    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Moves 0'), findsOneWidget);
    expect(find.byKey(Key('tube-${first.to}')), findsOneWidget);

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
    expect(find.byKey(const Key('tube-5')), findsNothing);
  });

  testWidgets('keyboard: number select, U undo, R restart', (t) async {
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(PourSortApp(store: MemoryProgressStore()));
    await t.pumpAndSettle();
    await t.sendKeyEvent(_digits[first.from]);
    await t.sendKeyEvent(_digits[first.to]);
    await t.pumpAndSettle();
    expect(find.text('Moves 1'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    await t.pumpAndSettle();
    expect(find.text('Moves 0'), findsOneWidget);
  });

  for (final size in const [Size(390, 844), Size(1280, 720)]) {
    testWidgets('hardest levels fit the viewport at $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      for (final level in [12, 30]) {
        await t.pumpWidget(
          PourSortApp(key: ValueKey(level), store: MemoryProgressStore(level)),
        );
        await t.pumpAndSettle();
        expect(find.text('Level $level'), findsOneWidget);
        final n = generateLevel(level).tubes.length;
        for (var i = 0; i < n; i++) {
          final r = t.getRect(find.byKey(Key('tube-$i')));
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(size.width));
          expect(r.top, greaterThanOrEqualTo(0));
          expect(r.bottom, lessThanOrEqualTo(size.height));
        }
      }
    });
  }
}
