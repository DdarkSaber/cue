import 'package:flutter/widgets.dart';

import '../../app/route_scaffold.dart';

/// Sync settings. Filled in by the sync milestone.
class SyncPage extends StatelessWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const RouteScaffold(kicker: 'Settings', title: 'Sync', children: []);
}
