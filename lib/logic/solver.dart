import 'pour_game.dart';

/// Canonical key: tube order does not matter for solvability.
String stateKey(List<List<int>> tubes) {
  final parts = [
    for (final t in tubes) String.fromCharCodes(t.map((c) => c + 65)),
  ];
  parts.sort();
  return parts.join('|');
}

bool _uniform(List<int> t) {
  for (final c in t) {
    if (c != t.first) return false;
  }
  return true;
}

/// Legal moves worth considering (skips pointless uniform-to-empty pours).
List<PourMove> legalMoves(
  List<List<int>> tubes, {
  int capacity = kTubeCapacity,
}) {
  final out = <PourMove>[];
  for (var i = 0; i < tubes.length; i++) {
    for (var j = 0; j < tubes.length; j++) {
      final n = pourCount(tubes, i, j, capacity: capacity);
      if (n == 0) continue;
      if (tubes[j].isEmpty && _uniform(tubes[i])) continue;
      out.add(PourMove(i, j, n, tubes[i].last));
    }
  }
  return out;
}

int _heuristic(List<List<int>> tubes) {
  // Segments sitting above the uniform base of their tube must move at least once.
  var h = 0;
  for (final t in tubes) {
    if (t.isEmpty) continue;
    var base = 1;
    while (base < t.length && t[base] == t.first) {
      base++;
    }
    h += t.length - base;
  }
  return h;
}

class _Node {
  _Node(this.tubes, this.g, this.parent, this.move);
  final List<List<int>> tubes;
  final int g;
  final _Node? parent;
  final PourMove? move;
}

class _Heap {
  final List<(int, int, _Node)> _a = [];

  bool get isNotEmpty => _a.isNotEmpty;

  bool _less((int, int, _Node) x, (int, int, _Node) y) =>
      x.$1 != y.$1 ? x.$1 < y.$1 : x.$2 < y.$2;

  void add((int, int, _Node) v) {
    _a.add(v);
    var i = _a.length - 1;
    while (i > 0) {
      final p = (i - 1) ~/ 2;
      if (!_less(_a[i], _a[p])) break;
      final t = _a[i];
      _a[i] = _a[p];
      _a[p] = t;
      i = p;
    }
  }

  (int, int, _Node) removeFirst() {
    final first = _a.first;
    final last = _a.removeLast();
    if (_a.isNotEmpty) {
      _a[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1;
        final r = l + 1;
        var m = i;
        if (l < _a.length && _less(_a[l], _a[m])) m = l;
        if (r < _a.length && _less(_a[r], _a[m])) m = r;
        if (m == i) break;
        final t = _a[i];
        _a[i] = _a[m];
        _a[m] = t;
        i = m;
      }
    }
    return first;
  }
}

/// Weighted best-first search. Returns a solution (not guaranteed minimal, but
/// deterministic) or null if none is found within [maxNodes] expansions.
List<PourMove>? solve(
  List<List<int>> start, {
  int capacity = kTubeCapacity,
  int maxNodes = 60000,
}) {
  final copy = [for (final t in start) List<int>.of(t)];
  final heap = _Heap();
  final seen = <String>{stateKey(copy)};
  var seq = 0;
  heap.add((0, seq++, _Node(copy, 0, null, null)));
  var expanded = 0;
  while (heap.isNotEmpty && expanded < maxNodes) {
    final node = heap.removeFirst().$3;
    if (isSolved(node.tubes, capacity: capacity)) {
      final path = <PourMove>[];
      _Node cur = node;
      while (cur.parent != null) {
        path.add(cur.move!);
        cur = cur.parent!;
      }
      return path.reversed.toList();
    }
    expanded++;
    for (final m in legalMoves(node.tubes, capacity: capacity)) {
      final next = [for (final t in node.tubes) List<int>.of(t)];
      for (var i = 0; i < m.count; i++) {
        next[m.from].removeLast();
        next[m.to].add(m.color);
      }
      if (!seen.add(stateKey(next))) continue;
      final g = node.g + 1;
      heap.add((g + 2 * _heuristic(next), seq++, _Node(next, g, node, m)));
    }
  }
  return null;
}
