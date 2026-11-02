import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../art/tube_art.dart';
import '../logic/pour_game.dart';

/// One animated pour. Rules already applied; this only trails behind.
class PourFx {
  PourFx(this.move, this.start, {required this.fromWasLifted});
  final PourMove move;
  final double start;
  final bool fromWasLifted;
}

enum ParticleKind { sparkle, bubble, confetti }

/// A particle with an analytic path: p = p0 + v t + g t^2 / 2.
///
/// With [tube] >= 0 positions are in tube-width units from the tube's rest
/// top-left; with [tube] -1 they are fractions of the board size.
class Particle {
  Particle({
    required this.kind,
    required this.tube,
    required this.start,
    required this.life,
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.gravity = 0,
    this.size = 0.1,
    this.spin = 0,
    required this.color,
  });

  final ParticleKind kind;
  final int tube;
  final double start;
  final double life;
  final double x, y, vx, vy, gravity, size, spin;
  final Color color;
}

class Popup {
  Popup(this.text, this.tube, this.start, {this.life = 1.0});
  final String text;
  final int tube;
  final double start;
  final double life;
}

class BannerFx {
  BannerFx(this.text, this.start, {this.life = 1.4});
  final String text;
  final double start;
  final double life;
}

class _Lift {
  _Lift(this.from, this.to, this.start);
  final double from, to, start;
}

/// Effect clock and effect state for the board.
///
/// One [Ticker] drives every effect; it runs only while something animates
/// and stops when idle, so tests settle. Time ([now], seconds) keeps
/// counting across stops, and the object lives in the screen state so it
/// survives board remounts.
class BoardFx extends ChangeNotifier {
  BoardFx(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  late final Ticker _ticker;
  double _base = 0;
  double now = 0;
  bool _disposed = false;

  /// When true no effect is added (reduced motion); state changes show at once.
  bool reduceMotion = false;

  static const double pourDuration = 0.72;
  static const double liftDuration = 0.2;
  static const double wobbleDuration = 1.1;
  static const double corkDuration = 0.5;
  static const double winDuration = 2.8;

  final List<PourFx> pours = <PourFx>[];
  final Map<int, (double, double)> _wobble = <int, (double, double)>{};
  final Map<int, double> _cork = <int, double>{};
  final Map<int, _Lift> _lift = <int, _Lift>{};
  final List<Particle> particles = <Particle>[];
  final List<Popup> popups = <Popup>[];
  BannerFx? banner;
  double? winStart;
  final math.Random _rng = math.Random(3);

  static final TubeGeometry unitTube = TubeGeometry(
    1,
    TubeGeometry.heightFor(1),
  );

  bool get isActive => _ticker.isActive;

  void _onTick(Duration elapsed) {
    now = _base + elapsed.inMicroseconds / 1e6;
    _prune();
    notifyListeners();
    if (!_busy) {
      _ticker.stop();
    }
  }

  void _kick() {
    if (_disposed || _ticker.isActive) return;
    _base = now;
    _ticker.start();
  }

  bool get _busy {
    if (pours.isNotEmpty || particles.isNotEmpty || popups.isNotEmpty) {
      return true;
    }
    if (_wobble.isNotEmpty || _cork.isNotEmpty || _lift.isNotEmpty) {
      return true;
    }
    return banner != null || winStart != null;
  }

  void _prune() {
    pours.removeWhere((p) => now >= p.start + pourDuration);
    particles.removeWhere((p) => now >= p.start + p.life);
    popups.removeWhere((p) => now >= p.start + p.life);
    _wobble.removeWhere((_, w) => now >= w.$1 + wobbleDuration);
    _cork.removeWhere((_, s) => now >= s + corkDuration);
    _lift.removeWhere((_, l) => now >= l.start + liftDuration);
    if (banner != null && now >= banner!.start + banner!.life) banner = null;
    if (winStart != null && now >= winStart! + winDuration) winStart = null;
  }

  /// Drops every effect (undo, restart, new level).
  void clear() {
    pours.clear();
    particles.clear();
    popups.clear();
    _wobble.clear();
    _cork.clear();
    _lift.clear();
    banner = null;
    winStart = null;
    notifyListeners();
  }

  // ---- Lift -------------------------------------------------------------

  final Map<int, double> _liftRest = <int, double>{};

  /// Eased selection lift (0 rest, 1 lifted) for tube [i].
  double liftOf(int i) {
    final l = _lift[i];
    if (l == null) return _liftRest[i] ?? 0;
    final t = ((now - l.start) / liftDuration).clamp(0.0, 1.0);
    final k = Curves.easeOutBack.transform(t);
    return l.from + (l.to - l.from) * k;
  }

  /// Sets which tube is lifted. [instant] skips the easing (pour source).
  void setSelected(int? selected, int tubeCount, {int? instant}) {
    for (var i = 0; i < tubeCount; i++) {
      final want = i == selected ? 1.0 : 0.0;
      final rest = _liftRest[i] ?? 0;
      if (rest == want) continue;
      final from = liftOf(i);
      _liftRest[i] = want;
      if (reduceMotion || i == instant) {
        _lift.remove(i);
        continue;
      }
      _lift[i] = _Lift(from, want, now);
      if (want == 1) wobble(i, 0.45);
      _kick();
    }
    notifyListeners();
  }

  void resetLift() {
    _liftRest.clear();
    _lift.clear();
  }

  // ---- Wobble -----------------------------------------------------------

  void wobble(int tube, double amp, {double delay = 0}) {
    if (reduceMotion) return;
    _wobble[tube] = (now + delay, amp);
    _kick();
  }

  /// Surface slosh (-1..1) and ripple for [tube] at [now].
  (double, double, double) wobbleOf(int tube) {
    final w = _wobble[tube];
    if (w == null) return (0, 0, 0);
    final t = now - w.$1;
    if (t < 0) return (0, 0, 0);
    final decay = math.exp(-t * 4.2) * w.$2;
    return (math.sin(t * 17) * decay, decay * 0.9, t * 11);
  }

  // ---- Cork -------------------------------------------------------------

  /// Cork drop for a complete tube: 0 seated, up to 1 falling, -1 hidden
  /// until the drop starts.
  double corkOf(int tube) {
    final s = _cork[tube];
    if (s == null) return 0;
    final t = (now - s) / corkDuration;
    if (t < 0) return -1;
    if (t >= 1) return 0;
    // Fall then a small bounce.
    if (t < 0.6) return 1 - Curves.easeIn.transform(t / 0.6);
    return math.sin((t - 0.6) / 0.4 * math.pi) * 0.12;
  }

  // ---- Pours ------------------------------------------------------------

  PourFx? pourFrom(int tube) {
    for (final p in pours) {
      if (p.move.from == tube) return p;
    }
    return null;
  }

  PourFx? pourInto(int tube) {
    for (final p in pours) {
      if (p.move.to == tube) return p;
    }
    return null;
  }

  /// Starts the pour animation. Older pours touching the same tubes end.
  void addPour(
    PourMove move, {
    required bool fromWasLifted,
    required bool completesTarget,
    required int targetFillAfter,
    required bool won,
    required int tubeCount,
  }) {
    if (reduceMotion) return;
    pours.removeWhere(
      (p) =>
          p.move.from == move.from ||
          p.move.to == move.from ||
          p.move.from == move.to ||
          p.move.to == move.to,
    );
    final start = now;
    pours.add(PourFx(move, start, fromWasLifted: fromWasLifted));
    const d = pourDuration;
    wobble(move.to, 1, delay: d * 0.32);
    wobble(move.from, 0.7, delay: d * 0.95);
    // Bubbles rising in the target while it fills.
    final g = unitTube;
    for (var i = 0; i < 7; i++) {
      final level = targetFillAfter - move.count * _rng.nextDouble();
      particles.add(
        Particle(
          kind: ParticleKind.bubble,
          tube: move.to,
          start: start + d * (0.35 + 0.4 * _rng.nextDouble()),
          life: 0.6 + 0.3 * _rng.nextDouble(),
          x: 0.3 + 0.4 * _rng.nextDouble(),
          y: g.liquidBottom - g.segment * level.clamp(0.2, 4.0),
          vx: (_rng.nextDouble() - 0.5) * 0.2,
          vy: -0.9 - _rng.nextDouble() * 0.6,
          size: 0.05 + 0.05 * _rng.nextDouble(),
          color: const Color(0xCCFFFFFF),
        ),
      );
    }
    if (completesTarget) completeTube(move.to, delay: d * 0.82);
    if (won) celebrate(tubeCount, delay: d * 0.9);
    _kick();
  }

  /// Cork, sparkles and a "Sorted!" popup over [tube].
  void completeTube(int tube, {double delay = 0}) {
    if (reduceMotion) return;
    final start = now + delay;
    _cork[tube] = start;
    for (var i = 0; i < 14; i++) {
      final a = i / 14 * math.pi * 2 + _rng.nextDouble() * 0.3;
      final sp = 1.4 + _rng.nextDouble() * 1.6;
      particles.add(
        Particle(
          kind: ParticleKind.sparkle,
          tube: tube,
          start: start + 0.18,
          life: 0.55 + _rng.nextDouble() * 0.3,
          x: 0.5,
          y: 0.0,
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp - 1.0,
          gravity: 3,
          size: 0.1 + _rng.nextDouble() * 0.1,
          spin: _rng.nextDouble() * 6,
          color: i.isEven ? const Color(0xFFFFE27A) : const Color(0xFFFFFFFF),
        ),
      );
    }
    popups.add(Popup('Sorted!', tube, start + 0.15));
    _kick();
  }

  void showBanner(String text, {double delay = 0}) {
    if (reduceMotion) return;
    banner = BannerFx(text, now + delay);
    _kick();
  }

  /// Confetti and a wave of tube hops.
  void celebrate(int tubeCount, {double delay = 0}) {
    if (reduceMotion) return;
    final start = now + delay;
    winStart = start;
    const colors = [
      Color(0xFFE53935),
      Color(0xFF1E88E5),
      Color(0xFF43A047),
      Color(0xFFFDD835),
      Color(0xFFFB8C00),
      Color(0xFF8E24AA),
      Color(0xFF00ACC1),
      Color(0xFFF48FB1),
    ];
    for (var i = 0; i < 90; i++) {
      final left = i.isEven;
      particles.add(
        Particle(
          kind: ParticleKind.confetti,
          tube: -1,
          start: start + _rng.nextDouble() * 0.25,
          life: 1.8 + _rng.nextDouble() * 0.8,
          x: left ? 0.0 : 1.0,
          y: 0.75,
          vx: (left ? 1 : -1) * (0.25 + _rng.nextDouble() * 0.45),
          vy: -1.1 - _rng.nextDouble() * 0.6,
          gravity: 1.4,
          size: 0.006 + _rng.nextDouble() * 0.006,
          spin: 4 + _rng.nextDouble() * 10,
          color: colors[i % colors.length],
        ),
      );
    }
    _kick();
  }

  /// Vertical hop (in tube widths, negative is up) during the win wave.
  double hopOf(int tube) {
    final s = winStart;
    if (s == null) return 0;
    final t = (now - s - 0.25 - tube * 0.07) / 0.42;
    if (t <= 0 || t >= 1) return 0;
    return -math.sin(t * math.pi) * 0.32;
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    super.dispose();
  }
}
