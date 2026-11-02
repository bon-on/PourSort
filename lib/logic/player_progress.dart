/// Saved meta progress: levels, stars, best moves, XP and the chosen theme.
/// Pure Dart, no Flutter imports.
library;

import 'stars.dart';

/// Cosmetic themes unlocked by player level. Themes never change rules.
enum PourTheme {
  lab(requiredLevel: 1, label: 'Lab'),
  potionShop(requiredLevel: 3, label: 'Potion Shop'),
  candy(requiredLevel: 6, label: 'Candy'),
  nightBar(requiredLevel: 10, label: 'Night Bar');

  const PourTheme({required this.requiredLevel, required this.label});

  /// Player level at which the theme becomes selectable.
  final int requiredLevel;

  /// Short English name shown in the UI.
  final String label;

  /// Parses a stored theme name; unknown values fall back to [lab].
  static PourTheme fromName(Object? name) {
    for (final theme in values) {
      if (theme.name == name) return theme;
    }
    return lab;
  }
}

/// Best result recorded for one level.
class LevelRecord {
  const LevelRecord({required this.stars, required this.bestMoves});

  /// 1..3; levels cleared before stars existed are migrated with 1.
  final int stars;

  /// Fewest moves of any clear, or 0 when unknown (migrated levels).
  final int bestMoves;
}

/// What a win changed, for the result card.
class WinOutcome {
  const WinOutcome({
    required this.progress,
    required this.level,
    required this.moves,
    required this.par,
    required this.stars,
    required this.previousStars,
    required this.previousBestMoves,
    required this.isNewBest,
    required this.firstClear,
    required this.xpGained,
    required this.playerLevelBefore,
    required this.playerLevelAfter,
    required this.newlyUnlockedThemes,
  });

  final PlayerProgress progress;
  final int level;
  final int moves;
  final int par;
  final int stars;
  final int previousStars;

  /// 0 when the level had no recorded move count.
  final int previousBestMoves;

  /// True when [moves] beat a recorded best (never on a first clear).
  final bool isNewBest;
  final bool firstClear;
  final int xpGained;
  final int playerLevelBefore;
  final int playerLevelAfter;
  final List<PourTheme> newlyUnlockedThemes;

  bool get leveledUp => playerLevelAfter > playerLevelBefore;
}

/// Tuning: a level takes one to three minutes. A first clear earns
/// [firstClearXp] + [xpPerStar] per star (40..70 XP); replays earn
/// [replayXp] plus [xpPerStar] for each star above the previous record, so
/// a replay pays only a small flat amount. Reaching player level L+1 costs
/// 100 + 40 * (L - 1) XP, so with about 55 XP per level the themes open
/// after roughly 5 (Lv3), 17 (Lv6) and 43 (Lv10) cleared levels.
class PlayerProgress {
  const PlayerProgress({
    required this.lastLevel,
    required this.highestLevel,
    required this.records,
    required this.totalXp,
    required this.selectedTheme,
  });

  const PlayerProgress.initial()
    : lastLevel = 1,
      highestLevel = 1,
      records = const <int, LevelRecord>{},
      totalXp = 0,
      selectedTheme = PourTheme.lab;

  /// Migrates the pre-v1 save (`pour_sort.level`, the level to resume).
  /// Levels below it were cleared without star data: they show one star and
  /// earn the XP of a one-star first clear each.
  factory PlayerProgress.fromLegacyLevel(int level) {
    final l = level < 1 ? 1 : level;
    return PlayerProgress(
      lastLevel: l,
      highestLevel: l,
      records: const <int, LevelRecord>{},
      totalXp: (l - 1) * (firstClearXp + xpPerStar),
      selectedTheme: PourTheme.lab,
    );
  }

  static const int firstClearXp = 25;
  static const int replayXp = 5;
  static const int xpPerStar = 15;

  /// Level the player resumes on.
  final int lastLevel;

  /// Highest level reached (unlocked); every level below it is cleared.
  final int highestLevel;

  /// Records of levels cleared since stars exist.
  final Map<int, LevelRecord> records;
  final int totalXp;
  final PourTheme selectedTheme;

  /// XP needed to go from [level] to the next one.
  static int xpToAdvance(int level) => 100 + 40 * (level < 1 ? 0 : level - 1);

  int get playerLevel => _split().$1;
  int get xpIntoLevel => _split().$2;
  int get xpForNextLevel => xpToAdvance(playerLevel);

  (int, int) _split() {
    var level = 1;
    var left = totalXp < 0 ? 0 : totalXp;
    while (left >= xpToAdvance(level)) {
      left -= xpToAdvance(level);
      level += 1;
    }
    return (level, left);
  }

  bool isUnlocked(int level) => level >= 1 && level <= highestLevel;

  bool isCleared(int level) =>
      records.containsKey(level) || (level >= 1 && level < highestLevel);

  /// Stars shown for [level]: the record, 1 for a cleared level without a
  /// record (migrated), else 0.
  int starsFor(int level) =>
      records[level]?.stars ?? (isCleared(level) ? 1 : 0);

  /// Fewest moves recorded for [level], or 0.
  int bestMovesFor(int level) => records[level]?.bestMoves ?? 0;

  int get totalStars {
    var sum = 0;
    for (var l = 1; l < highestLevel; l++) {
      sum += starsFor(l);
    }
    for (final entry in records.entries) {
      if (entry.key >= highestLevel) sum += entry.value.stars;
    }
    return sum;
  }

  bool isThemeUnlocked(PourTheme theme) => playerLevel >= theme.requiredLevel;

  /// Returns this progress unchanged when [theme] is still locked.
  PlayerProgress withTheme(PourTheme theme) {
    if (!isThemeUnlocked(theme) || theme == selectedTheme) return this;
    return _copy(selectedTheme: theme);
  }

  /// Records the level being played (to resume on next launch).
  PlayerProgress withLastLevel(int level) {
    final l = level < 1 ? 1 : level;
    if (l == lastLevel) return this;
    return _copy(
      lastLevel: l,
      highestLevel: l > highestLevel ? l : highestLevel,
    );
  }

  static int xpForWin({
    required int stars,
    required int previousStars,
    required bool firstClear,
  }) {
    final gained = stars - previousStars;
    return (firstClear ? firstClearXp : replayXp) +
        xpPerStar * (gained > 0 ? gained : 0);
  }

  /// Applies a clear of [level] in [moves] moves with par [par].
  WinOutcome applyWin({
    required int level,
    required int moves,
    required int par,
    bool usedExtraTube = false,
  }) {
    final stars = starsForMoves(moves, par, usedExtraTube: usedExtraTube);
    final firstClear = !isCleared(level);
    final previousStars = starsFor(level);
    final previousBest = bestMovesFor(level);
    final isNewBest = previousBest > 0 && moves < previousBest;
    final xp = xpForWin(
      stars: stars,
      previousStars: previousStars,
      firstClear: firstClear,
    );
    final record = LevelRecord(
      stars: stars > previousStars ? stars : previousStars,
      bestMoves: previousBest == 0 || moves < previousBest
          ? moves
          : previousBest,
    );
    final next = level + 1;
    final updated = _copy(
      records: {...records, level: record},
      highestLevel: next > highestLevel ? next : highestLevel,
      totalXp: totalXp + xp,
    );
    final before = playerLevel;
    final after = updated.playerLevel;
    return WinOutcome(
      progress: updated,
      level: level,
      moves: moves,
      par: par,
      stars: stars,
      previousStars: previousStars,
      previousBestMoves: previousBest,
      isNewBest: isNewBest,
      firstClear: firstClear,
      xpGained: xp,
      playerLevelBefore: before,
      playerLevelAfter: after,
      newlyUnlockedThemes: [
        for (final theme in PourTheme.values)
          if (before < theme.requiredLevel && after >= theme.requiredLevel)
            theme,
      ],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'v': 1,
    'lastLevel': lastLevel,
    'highestLevel': highestLevel,
    'levels': <String, dynamic>{
      for (final e in records.entries)
        '${e.key}': <String, int>{'s': e.value.stars, 'm': e.value.bestMoves},
    },
    'totalXp': totalXp,
    'theme': selectedTheme.name,
  };

  /// Tolerant parser: any missing or invalid field falls back on its own.
  factory PlayerProgress.fromJson(Object? json) {
    if (json is! Map) return const PlayerProgress.initial();
    int readInt(Object? v, int fallback, {int min = 0}) {
      if (v is num && v.isFinite && v >= min && v <= 1e9) return v.toInt();
      return fallback;
    }

    final highest = readInt(json['highestLevel'], 1, min: 1);
    final last = readInt(json['lastLevel'], 1, min: 1);
    final records = <int, LevelRecord>{};
    final raw = json['levels'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final level = int.tryParse('${e.key}');
        final v = e.value;
        if (level == null || level < 1 || level > 1e9 || v is! Map) continue;
        final stars = readInt(v['s'], 0);
        if (stars < 1 || stars > kMaxStars) continue;
        records[level] = LevelRecord(
          stars: stars,
          bestMoves: readInt(v['m'], 0),
        );
      }
    }
    var maxRecord = 0;
    for (final l in records.keys) {
      if (l > maxRecord) maxRecord = l;
    }
    var h = highest;
    if (last > h) h = last;
    if (maxRecord + 1 > h) h = maxRecord + 1;
    final progress = PlayerProgress(
      lastLevel: last,
      highestLevel: h,
      records: Map.unmodifiable(records),
      totalXp: readInt(json['totalXp'], 0),
      selectedTheme: PourTheme.lab,
    );
    return progress.withTheme(PourTheme.fromName(json['theme']));
  }

  PlayerProgress _copy({
    int? lastLevel,
    int? highestLevel,
    Map<int, LevelRecord>? records,
    int? totalXp,
    PourTheme? selectedTheme,
  }) {
    return PlayerProgress(
      lastLevel: lastLevel ?? this.lastLevel,
      highestLevel: highestLevel ?? this.highestLevel,
      records: Map.unmodifiable(records ?? this.records),
      totalXp: totalXp ?? this.totalXp,
      selectedTheme: selectedTheme ?? this.selectedTheme,
    );
  }
}
