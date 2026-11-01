import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'tokens.dart';

/// A screen whose code is loaded on first visit. On the web each deferred
/// library is a separate file, so the first page loads faster; elsewhere the
/// load completes at once.
class DeferredPage extends StatefulWidget {
  const DeferredPage(this.load, this.build, {super.key});

  final Future<void> Function() load;
  final Widget Function() build;

  @override
  State<DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<DeferredPage> {
  late final Future<void> _ready = kIsWeb ? widget.load() : Future.value();

  @override
  Widget build(BuildContext context) {
    // Off the web the code is already in the app (see preloadDeferred).
    if (!kIsWeb) return widget.build();
    return _web(context);
  }

  Widget _web(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.done && !snap.hasError) {
        return widget.build();
      }
      if (snap.hasError) {
        return const Center(
          child: Text('This page could not load. Check the connection.'),
        );
      }
      return const Center(
        child: SizedBox(
          width: 120,
          child: LinearProgressIndicator(color: CueColors.accent),
        ),
      );
    },
  );
}
