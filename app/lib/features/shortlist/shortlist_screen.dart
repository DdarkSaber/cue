import 'package:flutter/widgets.dart';

import '../../app/placeholder_page.dart';

class ShortlistScreen extends StatelessWidget {
  const ShortlistScreen({super.key});

  @override
  Widget build(BuildContext context) => const RoutePage(
    kicker: 'Your shortlist',
    title: 'Will try',
    body: 'Swipe right on a story and it waits here.',
  );
}
