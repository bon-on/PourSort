import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../art/theme_palette.dart';
import 'ui_kit.dart';

/// Remembers whether the first-run tutorial has been seen.
abstract class TutorialStore {
  Future<bool> isSeen();
  Future<void> markSeen();
}

class PrefsTutorialStore implements TutorialStore {
  static const _key = 'tutorial_seen_v1';

  @override
  Future<bool> isSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  @override
  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

class MemoryTutorialStore implements TutorialStore {
  MemoryTutorialStore({this.seen = false});
  bool seen;

  @override
  Future<bool> isSeen() async => seen;

  @override
  Future<void> markSeen() async => seen = true;
}

class HowToPlayStep {
  const HowToPlayStep(this.icon, this.text);
  final IconData icon;
  final String text;
}

const pourSortSteps = [
  HowToPlayStep(
    Icons.flag_outlined,
    'Sort the colors until every tube is empty or holds a single color. '
    'Finish within par for 3 stars.',
  ),
  HowToPlayStep(
    Icons.touch_app_outlined,
    'Tap a tube, then another, to pour its top color onto an empty or '
    'matching tube.',
  ),
  HowToPlayStep(
    Icons.keyboard_outlined,
    'Keys: 1-0 and Q W E T Y I pick tubes, U undo, R restart, A adds one '
    'extra tube per level, L levels, P themes.',
  ),
];

/// Scrim + card. Stateless: the owner keeps [step] and handles keys.
class HowToPlayOverlay extends StatelessWidget {
  const HowToPlayOverlay({
    super.key,
    required this.steps,
    required this.step,
    required this.onNext,
    required this.onSkip,
    this.palette = ThemePalette.lab,
  });

  final List<HowToPlayStep> steps;
  final int step;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final last = step == steps.length - 1;
    final s = steps[step];
    final p = palette;
    return ModalCard(
      palette: p,
      maxWidth: 360,
      cardKey: const Key('how-to-play'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How to play',
              style: TextStyle(
                color: p.text,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(p.accent, Colors.white, 0.3)!, p.accent],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(s.icon, size: 38, color: p.accentInk),
            ),
            const SizedBox(height: 14),
            Text(
              s.text,
              key: const Key('how-to-play-text'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.text,
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < steps.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: i == step ? 22 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == step
                          ? p.accent
                          : p.textSecondary.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    key: const Key('how-to-play-skip'),
                    label: 'Skip',
                    palette: p,
                    onPressed: onSkip,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PillButton(
                    key: const Key('how-to-play-next'),
                    label: last ? 'Play' : 'Next',
                    palette: p,
                    primary: true,
                    onPressed: onNext,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
