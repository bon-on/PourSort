import 'package:flutter/material.dart';

import 'logic/progress_store.dart';
import 'audio/sound_fx.dart';
import 'audio/sound_mute_store.dart';
import 'platform/game_platform.dart';
import 'ui/game_screen.dart';
import 'ui/how_to_play.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = createGamePlatform();
  await platform.initialize();
  runApp(PourSortApp(store: PrefsProgressStore(), platform: platform));
}

class PourSortApp extends StatelessWidget {
  const PourSortApp({
    super.key,
    required this.store,
    this.tutorialStore,
    this.platform = const NoopGamePlatform(),
    this.soundMuteStore = const SoundMuteStore(),
    this.onSfxPlayed,
  });

  final ProgressStore store;
  final TutorialStore? tutorialStore;
  final GamePlatform platform;
  final SoundMuteStore soundMuteStore;
  final void Function(Sfx sfx)? onSfxPlayed;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PourSort',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        useMaterial3: true,
      ),
      home: GameScreen(
        store: store,
        tutorialStore: tutorialStore,
        platform: platform,
        soundMuteStore: soundMuteStore,
        onSfxPlayed: onSfxPlayed,
      ),
    );
  }
}
