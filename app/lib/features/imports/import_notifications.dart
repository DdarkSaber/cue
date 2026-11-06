import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Time left at the current pace, once there is a pace to go on.
class ImportPace {
  DateTime? _start;
  int _startDone = 0;

  void reset() => _start = null;

  Duration? remaining(int done, int total, DateTime now) {
    if (total <= 0 || done >= total) return null;
    final start = _start;
    if (start == null || done < _startDone) {
      _start = now;
      _startDone = done;
      return null;
    }
    final progressed = done - _startDone;
    final elapsed = now.difference(start);
    if (progressed < 5 || elapsed < const Duration(seconds: 5)) return null;
    return elapsed * ((total - done) / progressed);
  }
}

/// "About 3 min left" style text.
String timeLeftLabel(Duration d) {
  final minutes = (d.inSeconds / 60).ceil();
  if (minutes <= 1) return 'Less than a minute left';
  if (minutes < 60) return 'About $minutes min left';
  final hours = d.inMinutes ~/ 60;
  final rest = d.inMinutes % 60;
  return 'About $hours h ${rest > 0 ? '$rest min ' : ''}left';
}

/// Android's notification shade shows import progress, so the app can be
/// minimised while a big list matches. Other platforms do nothing.
class ImportNotifications {
  const ImportNotifications();

  static const _channel = MethodChannel('cue/import_progress');

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _call(String method, [Map<String, Object?>? args]) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } on Object catch (e) {
      // Tests, and builds without the native side, have no channel. The
      // notification is a convenience: progress stays in the app.
      debugPrint('Import notification skipped (${e.runtimeType}).');
    }
  }

  Future<void> progress(int done, int total, String? timeLeft) =>
      _call('progress', {
        'done': done,
        'total': total,
        'text': ['Matched $done of $total', ?timeLeft].join(' · '),
      });

  Future<void> finished(String text) => _call('finished', {'text': text});

  Future<void> clear() => _call('clear');
}
