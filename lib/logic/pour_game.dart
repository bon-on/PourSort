/// Pure game rules for PourSort. No Flutter imports so it can be unit tested.
library;

const int kTubeCapacity = 4;

/// A single pour from tube [from] to tube [to] moving [count] segments of [color].
class PourMove {
  const PourMove(this.from, this.to, this.count, this.color);

  final int from;
  final int to;
  final int count;
  final int color;

  @override
  bool operator ==(Object other) =>
      other is PourMove &&
      other.from == from &&
      other.to == to &&
      other.count == count &&
      other.color == color;

  @override
  int get hashCode => Object.hash(from, to, count, color);

  @override
  String toString() => 'PourMove($from -> $to, $count x $color)';
}

/// Number of contiguous segments of the same color on top of [tube].
int topRunLength(List<int> tube) {
  if (tube.isEmpty) return 0;
  final top = tube.last;
  var n = 0;
  for (var i = tube.length - 1; i >= 0 && tube[i] == top; i--) {
    n++;
  }
  return n;
}

/// How many segments a pour from [from] to [to] would move (0 if illegal).
int pourCount(
  List<List<int>> tubes,
  int from,
  int to, {
  int capacity = kTubeCapacity,
}) {
  if (from == to) return 0;
  if (from < 0 || to < 0 || from >= tubes.length || to >= tubes.length) {
    return 0;
  }
  final src = tubes[from];
  final dst = tubes[to];
  if (src.isEmpty) return 0;
  final room = capacity - dst.length;
  if (room <= 0) return 0;
  if (dst.isNotEmpty && dst.last != src.last) return 0;
  final run = topRunLength(src);
  return run < room ? run : room;
}

/// True if every tube is empty or full of a single color.
bool isSolved(List<List<int>> tubes, {int capacity = kTubeCapacity}) {
  for (final t in tubes) {
    if (t.isEmpty) continue;
    if (t.length != capacity) return false;
    for (final c in t) {
      if (c != t.first) return false;
    }
  }
  return true;
}

/// Mutable game state with undo history.
class PourGame {
  PourGame(List<List<int>> tubes, {this.capacity = kTubeCapacity})
    : _tubes = [for (final t in tubes) List<int>.of(t)];

  final int capacity;
  final List<List<int>> _tubes;
  final List<PourMove> _history = [];
  bool _extraTubeUsed = false;

  List<List<int>> get tubes => _tubes;
  int get moves => _history.length;
  bool get canUndo => _history.isNotEmpty;
  bool get extraTubeUsed => _extraTubeUsed;
  bool get isWon => isSolved(_tubes, capacity: capacity);

  bool canPour(int from, int to) =>
      pourCount(_tubes, from, to, capacity: capacity) > 0;

  /// Performs the pour and returns it, or null when it is illegal.
  PourMove? pour(int from, int to) {
    final n = pourCount(_tubes, from, to, capacity: capacity);
    if (n == 0) return null;
    final color = _tubes[from].last;
    for (var i = 0; i < n; i++) {
      _tubes[from].removeLast();
      _tubes[to].add(color);
    }
    final move = PourMove(from, to, n, color);
    _history.add(move);
    return move;
  }

  /// Reverts the last pour and returns it, or null when there is none.
  PourMove? undo() {
    if (_history.isEmpty) return null;
    final m = _history.removeLast();
    for (var i = 0; i < m.count; i++) {
      _tubes[m.to].removeLast();
      _tubes[m.from].add(m.color);
    }
    return m;
  }

  /// Adds one empty tube, once per level.
  bool addExtraTube() {
    if (_extraTubeUsed) return false;
    _extraTubeUsed = true;
    _tubes.add(<int>[]);
    return true;
  }
}
