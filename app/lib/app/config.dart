import 'package:flutter/foundation.dart';

/// Deployed Worker. Overridden with --dart-define=CUE_API=... when needed.
const _releaseApi = 'https://cue-worker.cue-app.workers.dev';

/// Base URL of the Cue Worker. Debug builds talk to `wrangler dev`.
String get cueApiBase {
  const fromEnv = String.fromEnvironment('CUE_API');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (kReleaseMode) return _releaseApi;
  // The Android emulator reaches the host machine on 10.0.2.2.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8787';
  }
  return 'http://127.0.0.1:8787';
}
