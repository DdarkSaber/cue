import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/icons.dart';
import '../../app/layout.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../domain/models/library.dart';
import '../../domain/models/title.dart';
import '../deck/poster.dart';

/// Positive titles below which Cue offers the quickstart.
const tasteQuickstartThreshold = 5;

/// Off in widget tests, which would otherwise all open on the quickstart.
final tasteQuickstartEnabledProvider = Provider<bool>((ref) => true);

const _seenKey = 'tasteQuickstartSeen';

const _positiveRatings = [
  Rating.favourite,
  Rating.rewatched,
  Rating.wouldRewatch,
  Rating.enjoyed,
];

/// Titles the library already counts as liked: well-rated entries plus
/// saved (Will try) picks.
final positiveTasteCountProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(libraryVersionProvider);
  ref.watch(decisionVersionProvider);
  final id = await ref.watch(profileIdProvider.future);
  final db = ref.watch(databaseProvider);
  final codes = _positiveRatings.map((r) => r.code).toList();
  final rated = await (db.select(
    db.userTitles,
  )..where((u) => u.profileId.equals(id) & u.rating.isIn(codes))).get();
  final saved = await (db.select(
    db.shortlist,
  )..where((s) => s.profileId.equals(id))).get();
  return {
    ...rated.map((r) => r.titleId),
    ...saved.map((s) => s.titleId),
  }.length;
});

/// True when the deck should show the "tell Cue what you love" hint.
final tasteHintProvider = Provider.autoDispose<bool>((ref) {
  if (!ref.watch(tasteQuickstartEnabledProvider)) return false;
  final n = ref.watch(positiveTasteCountProvider).value;
  return n != null && n < tasteQuickstartThreshold;
});

/// Opens the quickstart once, on a genuinely empty first run. Skipping it
/// counts as seen; the deck keeps a quiet hint for later.
Future<void> maybeOfferTasteQuickstart(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!ref.read(tasteQuickstartEnabledProvider)) return;
  final profileId = await ref.read(profileIdProvider.future);
  final profiles = ref.read(profileRepositoryProvider);
  if (await profiles.rawSetting(profileId, _seenKey) == 'true') return;
  final n = await ref.read(positiveTasteCountProvider.future);
  if (n >= tasteQuickstartThreshold || !context.mounted) return;
  await profiles.setRawSetting(profileId, _seenKey, 'true');
  if (context.mounted) unawaited(context.push(CueRoutes.taste));
}

/// Popular titles across the enabled formats, one round-robin list. Falls
/// back to the cached catalog when a format cannot be reached.
final quickstartCandidatesProvider = FutureProvider.autoDispose<List<Title>>((
  ref,
) async {
  final settings = ref.read(currentSettingsProvider);
  final catalog = ref.read(catalogRepositoryProvider);
  final gateway = ref.read(catalogGatewayProvider);
  final profileId = await ref.read(profileIdProvider.future);
  final db = ref.read(databaseProvider);
  final owned = {
    for (final u in await (db.select(
      db.userTitles,
    )..where((u) => u.profileId.equals(profileId))).get())
      u.titleId,
  };
  final kinds = [
    for (final k in MediaKind.discoverable)
      if (settings.defaultKinds.contains(k)) k,
  ].take(6).toList();

  Future<List<Title>> forKind(MediaKind kind) async {
    try {
      final sorts = gateway.discoverSorts(kind);
      final page = await gateway
          .discover(kind, sort: sorts.first)
          .timeout(const Duration(seconds: 6));
      final ids = await catalog.upsert(page.items);
      return await catalog.titlesByIds(ids);
    } on Object {
      final cached = await catalog.pool([kind]);
      cached.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
      return cached;
    }
  }

  final lists = await Future.wait(kinds.map(forKind));
  bool ok(Title t) =>
      !owned.contains(t.id) &&
      (settings.showAdult || !t.adult) &&
      t.format != 'NOVEL' &&
      t.format != 'MUSIC';
  final filtered = [
    for (final l in lists) [...l.where(ok).take(8)],
  ];
  final out = <Title>[];
  final seen = <String>{};
  for (var i = 0; i < 8; i++) {
    for (final l in filtered) {
      if (i < l.length && seen.add(l[i].id)) out.add(l[i]);
    }
  }
  return out;
});

/// Skippable "Pick a few you loved": explicit Favourite ratings so picks
/// and "Because you liked X" work before any import.
class TasteQuickstartScreen extends ConsumerStatefulWidget {
  const TasteQuickstartScreen({super.key});

  @override
  ConsumerState<TasteQuickstartScreen> createState() =>
      _TasteQuickstartScreenState();
}

class _TasteQuickstartScreenState extends ConsumerState<TasteQuickstartScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  final _picked = <String, Title>{};
  List<Title>? _results;
  bool _searching = false;
  String? _searchNote;
  bool _saving = false;
  int _epoch = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      _epoch++;
      setState(() {
        _results = null;
        _searching = false;
        _searchNote = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(text));
  }

  Future<void> _run(String text) async {
    final epoch = ++_epoch;
    setState(() {
      _searching = true;
      _searchNote = null;
    });
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final r = await catalog.search(text);
      final ids = await catalog.upsert(r.items);
      final titles = await catalog.titlesByIds(ids);
      final showAdult = ref.read(currentSettingsProvider).showAdult;
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _results = [
          for (final t in titles)
            if (showAdult || !t.adult) t,
        ];
        _searchNote = r.warning;
      });
    } on Object {
      if (mounted && epoch == _epoch) {
        setState(() {
          _results = const [];
          _searchNote = 'Search could not finish. Try again.';
        });
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _searching = false);
    }
  }

  void _toggle(Title t) => setState(() {
    if (_picked.remove(t.id) == null) _picked[t.id] = t;
  });

  Future<void> _skip() async {
    await _markSeen();
    if (mounted) _leave();
  }

  Future<void> _markSeen() async {
    final id = await ref.read(profileIdProvider.future);
    await ref
        .read(profileRepositoryProvider)
        .setRawSetting(id, _seenKey, 'true');
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(CueRoutes.forYou);
    }
  }

  Future<void> _save() async {
    if (_picked.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final id = await ref.read(profileIdProvider.future);
      final library = ref.read(libraryRepositoryProvider);
      for (final t in _picked.values) {
        await library.saveEntry(
          id,
          t.id,
          state: LibraryState.seen,
          rating: Rating.favourite,
        );
      }
      await library.recomputeWeights(id);
      await _markSeen();
      ref.read(libraryVersionProvider.notifier).bump();
      ref.read(decisionVersionProvider.notifier).bump();
      if (!mounted) return;
      final n = _picked.length;
      final messenger = ScaffoldMessenger.maybeOf(context);
      _leave();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            n == 1
                ? 'Saved 1 favourite. Your picks are updating.'
                : 'Saved $n favourites. Your picks are updating.',
          ),
        ),
      );
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Could not save. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = context.cueLayout == CueLayout.desktop;
    final candidates = ref.watch(quickstartCandidatesProvider);
    final searching = _search.text.trim().length >= 2;
    final shown = searching ? _results : candidates.value;
    final loading = searching
        ? _searching && _results == null
        : candidates.isLoading;
    final n = _picked.length;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: desktop ? 920 : 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    // Header and search scroll with the grid so large text
                    // on a small screen never pushes the picks off-screen.
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _saving ? null : _skip,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(
                                      CueSize.minTarget,
                                      CueSize.minTarget,
                                    ),
                                  ),
                                  child: const Text('Skip for now'),
                                ),
                              ),
                              const CueRouteHeader(
                                kicker: 'Quick start',
                                title: 'Pick a few you loved',
                              ),
                              const SizedBox(height: CueSpace.sm),
                              const Text(
                                'Tap titles you loved so Cue can suggest more like them '
                                'right away. Five or more works best. Stays on this device.',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: CueColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: CueSpace.md),
                              TextField(
                                controller: _search,
                                onChanged: (v) {
                                  setState(() {});
                                  _onQuery(v);
                                },
                                textInputAction: TextInputAction.search,
                                onSubmitted: (v) {
                                  _debounce?.cancel();
                                  if (v.trim().length >= 2) _run(v);
                                },
                                decoration: InputDecoration(
                                  labelText: 'Search any title',
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0x0AFFFFFF),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      CueRadius.chip,
                                    ),
                                    borderSide: const BorderSide(
                                      color: CueColors.line,
                                    ),
                                  ),
                                ),
                              ),
                              if (_searchNote != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    _searchNote!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: CueColors.textMuted,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: CueSpace.md),
                            ],
                          ),
                        ),
                        ..._body(shown, loading, searching),
                      ],
                    ),
                  ),
                  const SizedBox(height: CueSpace.sm),
                  CuePrimaryButton(
                    label: n == 0
                        ? 'Pick at least one'
                        : n < tasteQuickstartThreshold
                        ? 'Save $n (${tasteQuickstartThreshold - n} more is ideal)'
                        : 'Save $n favourites',
                    expand: true,
                    onPressed: n == 0 || _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(List<Title>? shown, bool loading, bool searching) {
    if (loading) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Semantics(
              label: 'Loading titles',
              liveRegion: true,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
        ),
      ];
    }
    if (shown == null || shown.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  searching
                      ? 'No matches. Try another spelling.'
                      : 'Could not load titles. Check your connection, or '
                            'skip and rate from the deck.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CueColors.textMuted),
                ),
                if (!searching)
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(quickstartCandidatesProvider),
                    child: const Text('Try again'),
                  ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130,
          childAspectRatio: 0.62,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: shown.length,
        itemBuilder: (_, i) => _PickTile(
          title: shown[i],
          selected: _picked.containsKey(shown[i].id),
          onTap: () => _toggle(shown[i]),
        ),
      ),
    ];
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });
  final Title title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${title.displayTitle}, ${title.kind.label}',
      hint: selected ? 'Selected. Tap to remove.' : 'Tap to mark as loved.',
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CueRadius.chip),
              border: Border.all(
                color: selected ? CueColors.accent : CueColors.line,
                width: selected ? 3 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CueRadius.chip - 1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Poster(title: title),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00080D12), Color(0xEE080D12)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: Text(
                      title.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: CueColors.text,
                      ),
                    ),
                  ),
                  if (selected)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: CueColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: CueIcon(
                            CueIcons.check,
                            size: 16,
                            color: CueColors.onActionPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline deck hint that reopens the quickstart.
class TasteHint extends ConsumerWidget {
  const TasteHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(tasteHintProvider)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        button: true,
        label: 'Pick a few titles you loved for better suggestions',
        child: InkWell(
          borderRadius: BorderRadius.circular(CueRadius.chip),
          onTap: () => context.push(CueRoutes.taste),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CueSize.minTarget),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x0AA9D7FF),
                borderRadius: BorderRadius.circular(CueRadius.chip),
                border: Border.all(color: const Color(0x26A9D7FF)),
              ),
              child: const ExcludeSemantics(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Teach Cue your taste: pick a few you loved',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFCFE6FB),
                        ),
                      ),
                    ),
                    CueIcon(CueIcons.arrow, size: 18, color: CueColors.accent),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
