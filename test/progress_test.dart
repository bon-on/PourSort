import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pour_sort/logic/level_generator.dart';
import 'package:pour_sort/logic/player_progress.dart';
import 'package:pour_sort/logic/progress_store.dart';
import 'package:pour_sort/logic/stars.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('stars', () {
    test('par uses the solver length, fallback colors * 3', () {
      final level = generateLevel(1);
      expect(parForLevel(level), level.solutionLength);
      expect(parFor(-1, 5), 15);
      expect(parFor(0, 4), 12);
    });

    test('three at par, two within slack, one beyond', () {
      expect(twoStarSlack(6), 3);
      expect(twoStarSlack(20), 6);
      expect(twoStarSlack(21), 7);
      expect(starsForMoves(5, 10), 3);
      expect(starsForMoves(10, 10), 3);
      expect(starsForMoves(13, 10), 2);
      expect(starsForMoves(14, 10), 1);
    });

    test('extra tube caps the rating at two', () {
      expect(starsForMoves(5, 10, usedExtraTube: true), 2);
      expect(starsForMoves(13, 10, usedExtraTube: true), 2);
      expect(starsForMoves(30, 10, usedExtraTube: true), 1);
    });
  });

  group('player level', () {
    test('curve and theme unlocks', () {
      expect(PlayerProgress.xpToAdvance(1), 100);
      expect(PlayerProgress.xpToAdvance(3), 180);
      PlayerProgress at(int xp) => PlayerProgress(
        lastLevel: 1,
        highestLevel: 1,
        records: const {},
        totalXp: xp,
        selectedTheme: PourTheme.lab,
      );
      expect(at(0).playerLevel, 1);
      expect(at(99).playerLevel, 1);
      expect(at(100).playerLevel, 2);
      expect(at(100).xpIntoLevel, 0);
      expect(at(239).playerLevel, 2);
      expect(at(240).playerLevel, 3);
      expect(at(240).isThemeUnlocked(PourTheme.potionShop), isTrue);
      expect(at(240).isThemeUnlocked(PourTheme.candy), isFalse);
      // Lv10 needs sum_{L=1..9} (100 + 40 (L - 1)).
      expect(at(2340).playerLevel, 10);
      expect(at(2339).playerLevel, 9);
    });

    test('locked theme cannot be selected', () {
      const p = PlayerProgress.initial();
      expect(identical(p.withTheme(PourTheme.nightBar), p), isTrue);
      expect(p.withTheme(PourTheme.lab).selectedTheme, PourTheme.lab);
    });
  });

  group('wins', () {
    test('first clear records stars, unlocks the next level, earns XP', () {
      const p = PlayerProgress.initial();
      final o = p.applyWin(level: 1, moves: 8, par: 8);
      expect(o.stars, 3);
      expect(o.firstClear, isTrue);
      expect(o.isNewBest, isFalse);
      expect(o.xpGained, 25 + 45);
      expect(o.progress.highestLevel, 2);
      expect(o.progress.starsFor(1), 3);
      expect(o.progress.bestMovesFor(1), 8);
      expect(o.progress.totalStars, 3);
      expect(o.leveledUp, isFalse);
    });

    test('replays only pay for improvement and keep the best', () {
      var p = const PlayerProgress.initial()
          .applyWin(level: 1, moves: 20, par: 8)
          .progress;
      expect(p.starsFor(1), 1);
      final better = p.applyWin(level: 1, moves: 9, par: 8);
      expect(better.firstClear, isFalse);
      expect(better.stars, 2);
      expect(better.isNewBest, isTrue);
      expect(better.previousBestMoves, 20);
      expect(better.xpGained, 5 + 15);
      p = better.progress;
      final worse = p.applyWin(level: 1, moves: 30, par: 8);
      expect(worse.xpGained, 5);
      expect(worse.isNewBest, isFalse);
      expect(worse.progress.starsFor(1), 2);
      expect(worse.progress.bestMovesFor(1), 9);
      expect(worse.progress.highestLevel, 2);
    });

    test('level up reports newly unlocked themes', () {
      final p = PlayerProgress(
        lastLevel: 5,
        highestLevel: 5,
        records: const {},
        totalXp: 230,
        selectedTheme: PourTheme.lab,
      );
      final o = p.applyWin(level: 5, moves: 3, par: 10);
      expect(o.playerLevelBefore, 2);
      expect(o.playerLevelAfter, 3);
      expect(o.leveledUp, isTrue);
      expect(o.newlyUnlockedThemes, [PourTheme.potionShop]);
    });
  });

  group('serialization', () {
    test('json round trip', () {
      final p = const PlayerProgress.initial()
          .applyWin(level: 1, moves: 8, par: 8)
          .progress
          .withLastLevel(2);
      final back = PlayerProgress.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(back.lastLevel, 2);
      expect(back.highestLevel, 2);
      expect(back.starsFor(1), 3);
      expect(back.bestMovesFor(1), 8);
      expect(back.totalXp, p.totalXp);
    });

    test('corrupt fields fall back one by one', () {
      for (final junk in [null, 3, 'x', <Object>[], <String, Object>{}]) {
        final p = PlayerProgress.fromJson(junk);
        expect(p.lastLevel, 1);
        expect(p.highestLevel, 1);
        expect(p.totalXp, 0);
        expect(p.selectedTheme, PourTheme.lab);
      }
      final p = PlayerProgress.fromJson({
        'lastLevel': -4,
        'highestLevel': 'ten',
        'levels': {
          '3': {'s': 2, 'm': 11},
          'x': {'s': 2},
          '4': {'s': 9},
          '5': 'bad',
        },
        'totalXp': double.nan,
        'theme': 'nightBar',
      });
      expect(p.lastLevel, 1);
      expect(p.highestLevel, 4, reason: 'a record implies the next level');
      expect(p.starsFor(3), 2);
      expect(p.starsFor(4), 0);
      expect(p.totalXp, 0);
      expect(p.selectedTheme, PourTheme.lab, reason: 'locked theme');
    });

    test('legacy level migrates to cleared levels with XP', () {
      final p = PlayerProgress.fromLegacyLevel(6);
      expect(p.lastLevel, 6);
      expect(p.highestLevel, 6);
      expect(p.starsFor(5), 1);
      expect(p.starsFor(6), 0);
      expect(p.isCleared(5), isTrue);
      expect(p.totalStars, 5);
      expect(p.totalXp, 5 * 40);
      expect(PlayerProgress.fromLegacyLevel(-3).lastLevel, 1);
    });
  });

  group('PrefsProgressStore', () {
    test('empty prefs load defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await PrefsProgressStore().load();
      expect(p.lastLevel, 1);
      expect(p.totalXp, 0);
    });

    test('migrates the legacy key without removing it', () async {
      SharedPreferences.setMockInitialValues({'pour_sort.level': 7});
      final store = PrefsProgressStore();
      final p = await store.load();
      expect(p.lastLevel, 7);
      expect(p.highestLevel, 7);
      expect(p.starsFor(6), 1);
      await store.save(p.withLastLevel(8));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('pour_sort.level'), 8);
      expect(prefs.getString('pour_sort.progress_v1'), isNotNull);
      final again = await store.load();
      expect(again.lastLevel, 8);
      expect(again.highestLevel, 8);
    });

    test('corrupt v1 json falls back to the legacy value', () async {
      SharedPreferences.setMockInitialValues({
        'pour_sort.progress_v1': '{not json',
        'pour_sort.level': 3,
      });
      expect((await PrefsProgressStore().load()).lastLevel, 3);
      SharedPreferences.setMockInitialValues({
        'pour_sort.progress_v1': '[]',
        'pour_sort.level': 6,
      });
      expect((await PrefsProgressStore().load()).lastLevel, 6);
      SharedPreferences.setMockInitialValues({
        'pour_sort.progress_v1': 42,
        'pour_sort.level': 'nope',
      });
      expect((await PrefsProgressStore().load()).lastLevel, 1);
    });

    test('v1 wins over legacy', () async {
      final p = const PlayerProgress.initial()
          .applyWin(level: 1, moves: 8, par: 8)
          .progress
          .withLastLevel(2);
      SharedPreferences.setMockInitialValues({
        'pour_sort.progress_v1': jsonEncode(p.toJson()),
        'pour_sort.level': 9,
      });
      final loaded = await PrefsProgressStore().load();
      expect(loaded.lastLevel, 2);
      expect(loaded.starsFor(1), 3);
    });
  });
}
