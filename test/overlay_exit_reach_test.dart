import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pour_sort/art/theme_palette.dart';
import 'package:pour_sort/logic/player_progress.dart';
import 'package:pour_sort/ui/how_to_play.dart';
import 'package:pour_sort/ui/overlays.dart';

/// Short phone windows (browser bars, landscape) where a card can be taller
/// than the screen. The way out of every card must stay on screen without
/// scrolling.
const _sizes = [Size(360, 560), Size(320, 480), Size(640, 300)];

Future<void> _pump(WidgetTester tester, Size size, Widget overlay) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SizedBox.expand(child: overlay))),
  );
  await tester.pumpAndSettle();
}

void _expectOnScreen(WidgetTester tester, Finder finder, Size size) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder at $size');
  expect(rect.bottom, lessThanOrEqualTo(size.height), reason: '$finder');
  expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
  expect(rect.right, lessThanOrEqualTo(size.width), reason: '$finder');
}

void main() {
  for (final size in _sizes) {
    testWidgets('the win card keeps its buttons on screen at $size', (
      tester,
    ) async {
      var next = 0;
      await _pump(
        tester,
        size,
        WinCard(
          outcome: WinOutcome(
            progress: const PlayerProgress.initial(),
            level: 4,
            moves: 12,
            par: 14,
            stars: 3,
            previousStars: 1,
            previousBestMoves: 15,
            isNewBest: true,
            firstClear: false,
            xpGained: 60,
            playerLevelBefore: 2,
            playerLevelAfter: 3,
            newlyUnlockedThemes: const [PourTheme.potionShop],
          ),
          progress: const PlayerProgress.initial(),
          palette: ThemePalette.lab,
          onNext: () => next++,
          onReplay: () {},
          onLevels: () {},
          animate: false,
        ),
      );
      expect(tester.takeException(), isNull);
      _expectOnScreen(tester, find.text('Replay'), size);
      _expectOnScreen(tester, find.text('Levels'), size);
      _expectOnScreen(tester, find.text('Next level'), size);
      await tester.tap(find.text('Next level'));
      expect(next, 1);
    });

    testWidgets('the theme picker close stays pinned at $size', (
      tester,
    ) async {
      var closed = 0;
      await _pump(
        tester,
        size,
        ThemeOverlay(
          progress: const PlayerProgress.initial(),
          palette: ThemePalette.lab,
          cursor: 0,
          onPick: (_) {},
          onClose: () => closed++,
        ),
      );
      expect(tester.takeException(), isNull);
      final close = find.byKey(const Key('theme-picker-close'));
      _expectOnScreen(tester, close, size);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      _expectOnScreen(tester, close, size);
      await tester.tap(close);
      expect(closed, 1);
    });

    testWidgets('How to play keeps Skip and Next on screen at $size', (
      tester,
    ) async {
      var skipped = 0;
      await _pump(
        tester,
        size,
        HowToPlayOverlay(
          steps: pourSortSteps,
          step: 2,
          onNext: () {},
          onSkip: () => skipped++,
        ),
      );
      expect(tester.takeException(), isNull);
      final skip = find.byKey(const Key('how-to-play-skip'));
      _expectOnScreen(tester, skip, size);
      _expectOnScreen(tester, find.byKey(const Key('how-to-play-next')), size);
      await tester.tap(skip);
      expect(skipped, 1);
    });
  }
}
