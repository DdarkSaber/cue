/// The four fixed decisions.
enum Decision {
  willTry('will_try', 'Will try'),
  notNow('not_now', 'Not now'),
  watched('watched', 'Watched'),
  notInterested('not_interested', 'Not interested');

  const Decision(this.code, this.label);

  /// Stored in decision_events.action.
  final String code;
  final String label;

  /// Reading titles say "Read it" instead of "Watched".
  String labelFor({required bool reading}) =>
      this == watched && reading ? 'Read it' : label;

  static Decision? parse(String code) {
    for (final d in values) {
      if (d.code == code || (d == watched && code == 'read')) return d;
    }
    return null;
  }
}

enum SwipeDirection {
  left('Left'),
  right('Right'),
  up('Up'),
  down('Down');

  const SwipeDirection(this.label);
  final String label;
}

/// Which decision each swipe direction (and arrow key) makes.
/// Default: right Will try, down Not now, up Watched, left Not interested.
class SwipeMap {
  const SwipeMap(this.byDirection);

  final Map<SwipeDirection, Decision> byDirection;

  static const standard = SwipeMap({
    SwipeDirection.right: Decision.willTry,
    SwipeDirection.down: Decision.notNow,
    SwipeDirection.up: Decision.watched,
    SwipeDirection.left: Decision.notInterested,
  });

  Decision decisionFor(SwipeDirection d) => byDirection[d]!;

  SwipeDirection directionFor(Decision decision) =>
      byDirection.entries.firstWhere((e) => e.value == decision).key;

  bool get isStandard => SwipeDirection.values.every(
    (d) => byDirection[d] == standard.byDirection[d],
  );

  /// Assigns [decision] to [direction] and gives the displaced decision to
  /// the direction that held [decision], so every direction stays unique.
  SwipeMap assign(SwipeDirection direction, Decision decision) {
    final next = Map<SwipeDirection, Decision>.of(byDirection);
    final previousHolder = directionFor(decision);
    final displaced = next[direction]!;
    next[direction] = decision;
    next[previousHolder] = displaced;
    return SwipeMap(next);
  }

  /// Left and right swapped; up and down unchanged.
  SwipeMap get mirrored => SwipeMap({
    ...byDirection,
    SwipeDirection.left: byDirection[SwipeDirection.right]!,
    SwipeDirection.right: byDirection[SwipeDirection.left]!,
  });

  String encode() => SwipeDirection.values
      .map((d) => '${d.name}=${byDirection[d]!.code}')
      .join(',');

  /// Falls back to the standard map on anything malformed.
  static SwipeMap decode(String? raw) {
    if (raw == null || raw.isEmpty) return standard;
    final map = <SwipeDirection, Decision>{};
    for (final part in raw.split(',')) {
      final kv = part.split('=');
      if (kv.length != 2) return standard;
      final dir = SwipeDirection.values.where((d) => d.name == kv[0]);
      final dec = Decision.parse(kv[1]);
      if (dir.isEmpty || dec == null) return standard;
      map[dir.first] = dec;
    }
    if (map.length != 4 || map.values.toSet().length != 4) return standard;
    return SwipeMap(map);
  }

  @override
  bool operator ==(Object other) =>
      other is SwipeMap && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}
