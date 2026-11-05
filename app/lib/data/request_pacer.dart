import 'catalog_gateway.dart';

/// Keeps one group of Worker routes under its per-minute limit, so a big
/// import queues instead of being refused: at most [maxPerMinute] requests
/// start in any 60 seconds. A 429 that still slips through (another device
/// on the same network, a cold limiter) waits as long as Retry-After says
/// and is tried again, twice at most.
class RequestPacer {
  RequestPacer({
    required this.maxPerMinute,
    Future<void> Function(Duration)? sleep,
    DateTime Function()? clock,
  }) : _sleep = sleep ?? Future<void>.delayed,
       _now = clock ?? DateTime.now;

  final int maxPerMinute;
  final Future<void> Function(Duration) _sleep;
  final DateTime Function() _now;
  final List<DateTime> _stamps = [];

  static const _window = Duration(seconds: 60);
  static const maxRetries = 2;

  /// Waits used when a 429 carries no readable Retry-After.
  static const defaultWait = Duration(seconds: 60);
  static const maxWait = Duration(seconds: 65);

  Future<void> _acquire() async {
    while (true) {
      final now = _now();
      _stamps.removeWhere((s) => now.difference(s) >= _window);
      if (_stamps.length < maxPerMinute) {
        _stamps.add(now);
        return;
      }
      final wait = _stamps.first.add(_window).difference(now);
      await _sleep(
        wait > Duration.zero ? wait : const Duration(milliseconds: 50),
      );
      // A clock that did not move (tests) must not wedge the queue.
      if (!_now().isAfter(now)) _stamps.removeAt(0);
    }
  }

  static bool _limited(CatalogUnavailable e) =>
      e.code == 'rate_limited' || e.code == 'http_429';

  Future<T> run<T>(Future<T> Function() send) async {
    for (var attempt = 0; ; attempt++) {
      await _acquire();
      try {
        return await send();
      } on CatalogUnavailable catch (e) {
        if (!_limited(e) || attempt >= maxRetries) rethrow;
        final wait = e.retryAfter ?? defaultWait;
        const minWait = Duration(seconds: 1);
        await _sleep(
          wait > maxWait
              ? maxWait
              : wait < minWait
              ? minWait
              : wait,
        );
      }
    }
  }
}
