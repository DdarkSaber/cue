import 'package:flutter/widgets.dart';

import '../../app/placeholder_page.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => const RoutePage(
    kicker: 'Your corner of Cue',
    title: 'Library',
    body: 'Your history belongs here. Bring a list, or keep discovering.',
    actionLabel: 'Keep discovering',
  );
}
