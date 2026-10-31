import 'package:flutter/widgets.dart';

import '../../app/placeholder_page.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) => const RoutePage(
    kicker: 'Bring your history',
    title: 'Import',
    body: 'Coming in this build.',
  );
}
