import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/icons.dart';
import '../../app/layout.dart';
import '../../app/providers.dart';
import '../../app/route_scaffold.dart';
import '../../app/router.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../domain/decisions.dart';
import '../../domain/models/decision.dart';
import '../../domain/models/title.dart';
import '../deck/story_card.dart';
import '../details/details_sheet.dart';

final shortlistProvider = FutureProvider.autoDispose<List<Title>>((ref) async {
  ref.watch(libraryVersionProvider);
  ref.watch(decisionVersionProvider);
  final id = await ref.watch(profileIdProvider.future);
  return ref.read(libraryRepositoryProvider).shortlist(id);
});

/// Will try: the shortlist as cards with an explicit "Next story". Right
/// never silently means next; decisions keep their meanings.
class ShortlistScreen extends ConsumerStatefulWidget {
  const ShortlistScreen({super.key});

  @override
  ConsumerState<ShortlistScreen> createState() => _ShortlistScreenState();
}

class _ShortlistScreenState extends ConsumerState<ShortlistScreen> {
  int _index = 0;
  String? _message;

  Future<void> _decide(Title t, Decision d) async {
    final id = await ref.read(profileIdProvider.future);
    await ref
        .read(decisionServiceProvider)
        .decide(id, t, d, context: DeckContext.shortlist);
    ref.read(decisionVersionProvider.notifier).bump();
    setState(
      () => _message = switch (d) {
        Decision.watched =>
          t.kind.isReading ? 'Marked as read' : 'Marked as watched',
        Decision.notInterested => 'Removed. Restore it in Library.',
        Decision.notNow => 'Hidden for 14 days',
        Decision.willTry => null,
      },
    );
  }

  Future<void> _remove(Title t) async {
    final id = await ref.read(profileIdProvider.future);
    await ref.read(libraryRepositoryProvider).removeFromShortlist(id, t.id);
    ref.read(decisionVersionProvider.notifier).bump();
    setState(() => _message = 'Removed from Will try');
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(shortlistProvider);
    return list.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: CueColors.accent),
      ),
      error: (_, _) => const Center(child: Text('Will try could not be read.')),
      data: (titles) {
        if (titles.isEmpty) {
          return RouteScaffold(
            kicker: 'Your shortlist',
            title: 'Will try',
            children: [
              const Text(
                'Nothing here yet. Swipe right on a story, or tap Will try, and it waits here.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: CueColors.textMuted,
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  style: const TextStyle(color: Color(0xFFC1DEF7)),
                ),
              ],
              const SizedBox(height: CueSpace.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: CuePrimaryButton(
                  label: 'Find a story',
                  onPressed: () => context.go(CueRoutes.forYou),
                ),
              ),
            ],
          );
        }
        final i = _index.clamp(0, titles.length - 1);
        final t = titles[i];
        final desktop = context.cueLayout == CueLayout.desktop;
        return Padding(
          padding: EdgeInsets.only(top: desktop ? 80 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: CueRouteHeader(
                        kicker: 'Your shortlist',
                        title: 'Will try',
                      ),
                    ),
                    Text(
                      '${i + 1} of ${titles.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CueColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: desktop ? 640 : 700),
                    child: StoryCard(
                      key: ValueKey(t.id),
                      title: t,
                      reason: 'On your Will try list.',
                      onDetails: () =>
                          showDetailsSheet(context, t, showActions: false),
                    ),
                  ),
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFC1DEF7),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: CueSpace.sm,
                runSpacing: CueSpace.sm,
                children: [
                  CueSecondaryButton(
                    label: 'Previous',
                    onPressed: i == 0
                        ? null
                        : () => setState(() => _index = i - 1),
                  ),
                  CueSecondaryButton(
                    label: Decision.watched.labelFor(reading: t.kind.isReading),
                    onPressed: () => _decide(t, Decision.watched),
                  ),
                  CueSecondaryButton(
                    label: 'Remove',
                    onPressed: () => _remove(t),
                  ),
                  CuePrimaryButton(
                    label: 'Next story',
                    onPressed: i >= titles.length - 1
                        ? null
                        : () => setState(() => _index = i + 1),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: () => _decide(t, Decision.notInterested),
                  icon: const CueIcon(
                    CueIcons.close,
                    size: 14,
                    color: CueColors.notInterested,
                  ),
                  label: const Text('Not interested after all'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      CueSize.minTarget,
                      CueSize.minTarget,
                    ),
                    foregroundColor: CueColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
