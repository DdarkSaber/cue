import 'package:flutter/widgets.dart';

import '../../app/placeholder_page.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const RoutePage(
    kicker: 'Make yourself at home',
    title: 'Settings',
    body: 'Nothing to set yet. Your library stays on this device.',
  );
}
