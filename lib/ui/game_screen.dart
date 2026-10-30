import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/pour_game.dart';
import '../logic/progress_store.dart';
import 'confetti.dart';
import 'game_controller.dart';
import 'tube_painter.dart';

const _digitKeys = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
  LogicalKeyboardKey.digit0,
  LogicalKeyboardKey.keyQ,
  LogicalKeyboardKey.keyW,
  LogicalKeyboardKey.keyE,
  LogicalKeyboardKey.keyT,
  LogicalKeyboardKey.keyY,
  LogicalKeyboardKey.keyI,
];

/// Label shown under tube [i]: 1-9, 0, then Q W E T Y I.
String tubeKeyLabel(int i) {
  const letters = ['Q', 'W', 'E', 'T', 'Y', 'I'];
  if (i < 9) return '${i + 1}';
  if (i == 9) return '0';
  return i - 10 < letters.length ? letters[i - 10] : '';
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.store});

  final ProgressStore store;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final GameController _ctrl = GameController(widget.store);
  late final AnimationController _pour = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  final FocusNode _focus = FocusNode();
  int _seenSerial = 0;
  bool _wasWon = false;
  int _winKey = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChange);
    _ctrl.init();
  }

  void _onChange() {
    if (_ctrl.loaded &&
        _ctrl.lastMove != null &&
        _ctrl.moveSerial != _seenSerial) {
      _seenSerial = _ctrl.moveSerial;
      _pour.forward(from: 0);
    }
    if (_ctrl.loaded && _ctrl.won && !_wasWon) _winKey++;
    _wasWon = _ctrl.loaded && _ctrl.won;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChange);
    _ctrl.dispose();
    _pour.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent || !_ctrl.loaded) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.keyU) {
      _ctrl.undo();
    } else if (k == LogicalKeyboardKey.keyR) {
      _ctrl.restart();
    } else if (k == LogicalKeyboardKey.keyA) {
      _ctrl.addTube();
    } else if ((k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.keyN) &&
        _ctrl.won) {
      _ctrl.nextLevel();
    } else {
      final idx = _digitKeys.indexOf(k);
      if (idx < 0) return KeyEventResult.ignored;
      _ctrl.tap(idx);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: SafeArea(
          child: !_ctrl.loaded
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      children: [
                        _Hud(ctrl: _ctrl),
                        Expanded(
                          child: Stack(
                            children: [
                              _Board(ctrl: _ctrl, pour: _pour),
                              if (_ctrl.won) ...[
                                Positioned.fill(
                                  child: Confetti(key: ValueKey(_winKey)),
                                ),
                                Center(child: _WinCard(ctrl: _ctrl)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.ctrl});
  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    final g = ctrl.game;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Level ${ctrl.level}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Moves ${g.moves}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                key: const Key('undo'),
                tooltip: 'Undo (U)',
                onPressed: g.canUndo && !ctrl.won ? ctrl.undo : null,
                icon: const Icon(Icons.undo),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                key: const Key('restart'),
                tooltip: 'Restart (R)',
                onPressed: ctrl.restart,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                key: const Key('add-tube'),
                tooltip: 'Add an empty tube, once per level (A)',
                onPressed: g.extraTubeUsed || ctrl.won ? null : ctrl.addTube,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.ctrl, required this.pour});
  final GameController ctrl;
  final AnimationController pour;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final n = ctrl.game.tubes.length;
        const gap = 14.0;
        final availW = box.maxWidth - 24;
        final availH = box.maxHeight - 8;
        // Pick the column count that allows the largest tubes without overflow.
        var bestTw = 0.0;
        var bestCols = n;
        for (var cols = 1; cols <= n; cols++) {
          final rows = (n / cols).ceil();
          final byWidth = (availW - gap * (cols - 1)) / cols;
          final byHeight =
              (availH - (rows - 1) * gap - 24 * rows) / (3.8 * rows);
          final tw = min(84.0, min(byWidth, byHeight));
          if (tw >= bestTw) {
            bestTw = tw;
            bestCols = cols;
          }
        }
        bestTw = max(bestTw, 14.0);
        final tw = bestTw;
        final segH = tw * 0.8;
        return Center(
          child: SingleChildScrollView(
            child: SizedBox(
              width: bestCols * tw + (bestCols - 1) * gap + 1,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < n; i++)
                    _TubeCell(
                      index: i,
                      width: tw,
                      segH: segH,
                      ctrl: ctrl,
                      pour: pour,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TubeCell extends StatelessWidget {
  const _TubeCell({
    required this.index,
    required this.width,
    required this.segH,
    required this.ctrl,
    required this.pour,
  });

  final int index;
  final double width;
  final double segH;
  final GameController ctrl;
  final AnimationController pour;

  @override
  Widget build(BuildContext context) {
    final tube = ctrl.game.tubes[index];
    final selected = ctrl.selected == index;
    final lift = width * 0.6;
    final complete =
        tube.length == kTubeCapacity && tube.every((c) => c == tube.first);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: Key('tube-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: () => ctrl.tap(index),
        child: SizedBox(
          width: width,
          height: tubeHeight(segH) + lift + 20,
          child: Column(
            children: [
              SizedBox(
                height: tubeHeight(segH) + lift,
                child: AnimatedBuilder(
                  animation: pour,
                  builder: (_, _) {
                    final m = ctrl.lastMove;
                    final animating = m != null && pour.isAnimating;
                    final t = Curves.easeInOut.transform(pour.value);
                    var segs = [for (final c in tube) SegmentView(c)];
                    var dy = selected ? 0.0 : lift;
                    var angle = 0.0;
                    if (animating && index == m.to) {
                      segs = [
                        for (var k = 0; k < tube.length; k++)
                          SegmentView(
                            tube[k],
                            k >= tube.length - m.count ? t : 1,
                          ),
                      ];
                    } else if (animating && index == m.from) {
                      segs = [
                        ...segs,
                        for (var k = 0; k < m.count; k++)
                          SegmentView(m.color, 1 - t),
                      ];
                      final s = sin(pi * pour.value);
                      dy = lift * (1 - s);
                      angle = s * 0.35 * (m.to > m.from ? 1 : -1);
                    }
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        transform: Matrix4.translationValues(0, dy - lift, 0),
                        child: Transform.rotate(
                          angle: angle,
                          child: CustomPaint(
                            size: Size(width, tubeHeight(segH)),
                            painter: TubePainter(
                              segments: segs,
                              segmentHeight: segH,
                              selected: selected,
                              complete: complete,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                height: 20,
                child: tubeKeyLabel(index).isNotEmpty
                    ? Text(
                        tubeKeyLabel(index),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WinCard extends StatelessWidget {
  const _WinCard({required this.ctrl});
  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      color: const Color(0xEE1E293B),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Level complete!',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text('${ctrl.game.moves} moves'),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('next-level'),
              onPressed: ctrl.nextLevel,
              child: const Text('Next level'),
            ),
          ],
        ),
      ),
    );
  }
}
