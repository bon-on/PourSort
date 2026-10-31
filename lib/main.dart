import 'package:flutter/material.dart';

import 'logic/progress_store.dart';
import 'ui/game_screen.dart';
import 'ui/how_to_play.dart';

void main() {
  runApp(PourSortApp(store: PrefsProgressStore()));
}

class PourSortApp extends StatelessWidget {
  const PourSortApp({super.key, required this.store, this.tutorialStore});

  final ProgressStore store;
  final TutorialStore? tutorialStore;

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
      home: GameScreen(store: store, tutorialStore: tutorialStore),
    );
  }
}
