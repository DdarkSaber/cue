import 'package:flutter/widgets.dart';

import '../../app/placeholder_page.dart';

class ShortlistScreen extends StatelessWidget {
  const ShortlistScreen({super.key});

  @override
  Widget build(BuildContext context) => const RoutePage(
    kicker: 'Your shortlist',
    title: 'Will try',
    body: 'Nothing here yet. Swipe right on a story, or tap Will try, and it waits here.',
    actionLabel: 'Find a story',
  );
}
