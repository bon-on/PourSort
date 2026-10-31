import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pour_sort/audio/sound_fx.dart';
import 'package:pour_sort/audio/sound_mute_store.dart';
import 'package:pour_sort/logic/level_generator.dart';
import 'package:pour_sort/logic/progress_store.dart';
import 'package:pour_sort/logic/solver.dart';
import 'package:pour_sort/main.dart';
import 'package:pour_sort/platform/game_platform.dart';
import 'package:pour_sort/ui/how_to_play.dart';

class _MemoryMuteStore extends SoundMuteStore {
  _MemoryMuteStore({this.muted = false});
  bool muted;
  @override
  Future<bool> loadMuted() async => muted;
  @override
  Future<void> saveMuted(bool value) async => muted = value;
}

class _ThrowingMuteStore extends SoundMuteStore {
  @override
  Future<bool> loadMuted() async => throw StateError('no prefs');
  @override
  Future<void> saveMuted(bool value) async => throw StateError('disk full');
}

class _MutedPlatform extends GamePlatform {
  bool mute = true;
  @override
  bool get isAudioMuted => mute;
  @override
  Future<void> initialize() async {}
  @override
  void gameplayStart() {}
  @override
  void gameplayStop() {}
}

Future<List<Sfx>> _launch(
  WidgetTester t, {
  SoundMuteStore? store,
  GamePlatform platform = const NoopGamePlatform(),
}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final played = <Sfx>[];
  await t.pumpWidget(
    PourSortApp(
      store: MemoryProgressStore(),
      tutorialStore: MemoryTutorialStore()..seen = true,
      platform: platform,
      soundMuteStore: store ?? _MemoryMuteStore(),
      onSfxPlayed: played.add,
    ),
  );
  await t.pumpAndSettle();
  return played;
}

void main() {
  test('every Sfx asset exists on disk and is covered by pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/audio/'));
    for (final sfx in Sfx.values) {
      expect(File(sfx.assetKey).existsSync(), isTrue, reason: sfx.assetKey);
    }
  });

  test('SoundFx is silent while muted and never throws', () {
    var muted = true;
    final played = <Sfx>[];
    final fx = SoundFx(isMuted: () => muted, onPlay: played.add);
    fx.play(Sfx.pour);
    expect(played, isEmpty);
    muted = false;
    fx.play(Sfx.pour);
    expect(played, [Sfx.pour]);
    fx.dispose();
  });

  testWidgets('toggle flips icon, tooltip and persists', (t) async {
    final store = _MemoryMuteStore();
    await _launch(t, store: store);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.byTooltip('Sound on'), findsOneWidget);
    await t.tap(find.byKey(const Key('sound-toggle')));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(find.byTooltip('Sound off'), findsOneWidget);
    expect(store.muted, isTrue);
    await t.tap(find.byKey(const Key('sound-toggle')));
    await t.pumpAndSettle();
    expect(store.muted, isFalse);
  });

  testWidgets('persisted mute is loaded on launch', (t) async {
    await _launch(t, store: _MemoryMuteStore(muted: true));
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
  });

  testWidgets('user mute silences taps', (t) async {
    final played = await _launch(t, store: _MemoryMuteStore(muted: true));
    await t.tap(find.byKey(const Key('tube-0')));
    await t.pump();
    expect(played, isEmpty);
    await t.tap(find.byKey(const Key('sound-toggle')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('tube-1')));
    await t.pump();
    expect(played, isNotEmpty);
  });

  testWidgets('platform mute silences taps', (t) async {
    final platform = _MutedPlatform();
    final played = await _launch(t, platform: platform);
    await t.tap(find.byKey(const Key('tube-0')));
    await t.pump();
    expect(played, isEmpty);
    platform.mute = false;
    await t.tap(find.byKey(const Key('tube-1')));
    await t.pump();
    expect(played, isNotEmpty);
  });

  testWidgets('hook points: select, invalid, pour, level_clear', (t) async {
    final played = await _launch(t);
    final tubes = generateLevel(1).tubes;
    final empty = tubes.indexWhere((x) => x.isEmpty);
    // Tap empty tube with nothing selected: invalid.
    await t.tap(find.byKey(Key('tube-$empty')));
    await t.pump();
    expect(played, [Sfx.invalid]);
    // Solve: first move selects then pours.
    final moves = solve(tubes)!;
    played.clear();
    for (var i = 0; i < moves.length; i++) {
      final m = moves[i];
      await t.tap(find.byKey(Key('tube-${m.from}')));
      await t.pump();
      await t.tap(find.byKey(Key('tube-${m.to}')));
      await t.pumpAndSettle();
    }
    expect(played.where((s) => s == Sfx.select).length, moves.length);
    expect(played.where((s) => s == Sfx.pour).length, moves.length - 1);
    expect(played.last, Sfx.levelClear);
    expect(played.where((s) => s == Sfx.levelClear).length, 1);
  });

  testWidgets('storage failure keeps sound on', (t) async {
    final played = await _launch(t, store: _ThrowingMuteStore());
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    await t.tap(find.byKey(const Key('sound-toggle')));
    await t.pump();
    await t.tap(find.byKey(const Key('sound-toggle')));
    await t.pump();
    await t.tap(find.byKey(const Key('tube-0')));
    await t.pump();
    expect(played, [Sfx.select]);
  });

  testWidgets('deselect, undo, restart, add tube and bad keys are silent', (
    t,
  ) async {
    final played = await _launch(t);
    await t.tap(find.byKey(const Key('tube-0')));
    await t.pump();
    expect(played, [Sfx.select]);
    await t.sendKeyEvent(LogicalKeyboardKey.keyI); // no such tube
    await t.tap(find.byKey(const Key('tube-0'))); // deselect
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.keyA);
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    await t.sendKeyEvent(LogicalKeyboardKey.keyR);
    await t.tap(find.byKey(const Key('restart')));
    await t.pump();
    expect(played, [Sfx.select]);
  });

  testWidgets('a target that cannot take the pour plays invalid', (t) async {
    final played = await _launch(t);
    final tubes = generateLevel(1).tubes;
    int? from, to;
    for (var i = 0; i < tubes.length && to == null; i++) {
      for (var j = 0; j < tubes.length; j++) {
        if (i != j &&
            tubes[i].isNotEmpty &&
            tubes[j].isNotEmpty &&
            tubes[i].last != tubes[j].last) {
          from = i;
          to = j;
          break;
        }
      }
    }
    expect(to, isNotNull);
    await t.tap(find.byKey(Key('tube-$from')));
    await t.pump();
    await t.tap(find.byKey(Key('tube-$to')));
    await t.pump();
    expect(played, [Sfx.select, Sfx.invalid]);
  });
}
