import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../domain/models/deck_filters.dart';
import '../../domain/models/quick_mood.dart';
import '../../domain/models/title.dart';
import '../../domain/mood_rules.dart';
import '../deck/deck_controller.dart';

/// Opens the filter sheet. Draft changes apply only on "Show N picks";
/// closing or Back cancels.
Future<void> showFilterSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final draft = ValueNotifier(container.read(deckFiltersProvider));
  final applied = await showCueSheet<DeckFilters>(
    context,
    kicker: 'Tell Cue what you feel like',
    title: 'Filters',
    body: (_) => FilterBody(draft: draft),
    footer: (ctx) => _Footer(draft: draft),
  );
  if (applied != null) {
    container.read(deckFiltersProvider.notifier).apply(applied);
  }
  draft.dispose();
}

class FilterBody extends StatefulWidget {
  const FilterBody({super.key, required this.draft});
  final ValueNotifier<DeckFilters> draft;

  @override
  State<FilterBody> createState() => _FilterBodyState();
}

class _FilterBodyState extends State<FilterBody> {
  late final _text = TextEditingController(text: widget.draft.value.tellMe);
  List<String> _understood = const [];
  bool _tellMeMissed = false;
  bool _more = false;

  DeckFilters get _f => widget.draft.value;
  set _f(DeckFilters v) => widget.draft.value = v;

  void _changed() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.draft.addListener(_changed);
  }

  @override
  void dispose() {
    widget.draft.removeListener(_changed);
    _text.dispose();
    super.dispose();
  }

  void _tellMe() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final parsed = parseMood(text);
    setState(() {
      _understood = parsed.understood;
      _tellMeMissed = parsed.isEmpty;
    });
    // Unrecognised words still count: the live mood learner (and, when on,
    // Smarter mood text) reads the whole sentence.
    if (parsed.isEmpty) _f = _f.copyWith(tellMe: text);
    if (!parsed.isEmpty) {
      _f = parsed.applyTo(_f, text);
      if (parsed.shortOnly || parsed.era != EraFilter.any || parsed.rewatches) {
        _more = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _f;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CueSectionLabel('Tell me'),
        Row(
          spacing: CueSpace.sm,
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                maxLength: 200,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _tellMe(),
                decoration: InputDecoration(
                  hintText: 'Short, funny anime with new art',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0x08FFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CueRadius.chip),
                    borderSide: const BorderSide(color: Color(0x29FFFFFF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CueRadius.chip),
                    borderSide: const BorderSide(color: Color(0x29FFFFFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CueRadius.chip),
                    borderSide: const BorderSide(
                      color: CueColors.accent,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            CueSecondaryButton(label: 'Apply', onPressed: _tellMe),
          ],
        ),
        if (_understood.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Understood: ${_understood.join(', ')}. Read on this device.',
              style: const TextStyle(fontSize: 13, color: Color(0xFFC1DEF7)),
            ),
          ),
        if (_tellMeMissed)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Saved. Cue learns what these words mean from what you pick next. For instant understanding, turn on Smarter mood text in Settings.',
              style: TextStyle(fontSize: 13, color: CueColors.textMuted),
            ),
          ),
        const CueSectionLabel('Format'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final k in MediaKind.discoverable)
              CueChoiceChip(
                label: k.label,
                selected: f.kinds.contains(k),
                onTap: () {
                  final next = {...f.kinds};
                  next.contains(k) ? next.remove(k) : next.add(k);
                  _f = f.copyWith(kinds: next);
                },
              ),
          ],
        ),
        const CueSectionLabel('Mood'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final m in QuickMood.values)
              CueChoiceChip(
                label: m.label,
                selected: f.mood == m,
                onTap: () => _f = f.copyWith(mood: m),
              ),
          ],
        ),
        const SizedBox(height: CueSpace.md),
        Semantics(
          button: true,
          expanded: _more,
          child: TextButton(
            onPressed: () => setState(() => _more = !_more),
            style: TextButton.styleFrom(
              minimumSize: const Size(CueSize.minTarget, CueSize.minTarget),
              foregroundColor: CueColors.accent,
              padding: EdgeInsets.zero,
            ),
            child: Text(_more ? 'Fewer options' : 'More options'),
          ),
        ),
        if (_more) ...[
          _Toggle(
            label: 'Short season',
            hint: '13 episodes or fewer, or a film',
            value: f.shortOnly,
            onChanged: (v) => _f = f.copyWith(shortOnly: v),
          ),
          _Toggle(
            label: 'Include rewatches',
            hint: 'Titles you rated Rewatched or Would rewatch',
            value: f.includeRewatches,
            onChanged: (v) => _f = f.copyWith(includeRewatches: v),
          ),
          const CueSectionLabel('Art era'),
          Wrap(
            spacing: 8,
            children: [
              for (final (e, label) in [
                (EraFilter.any, 'Any'),
                (EraFilter.newArt, 'New art (2023+)'),
                (EraFilter.classic, 'Classic (before 2010)'),
              ])
                CueChoiceChip(
                  label: label,
                  selected: f.era == e,
                  onTap: () => _f = f.copyWith(era: e),
                ),
            ],
          ),
          const CueSectionLabel('Completion'),
          Wrap(
            spacing: 8,
            children: [
              for (final (s, label) in [
                (StatusFilter.any, 'Any'),
                (StatusFilter.finished, 'Finished'),
                (StatusFilter.ongoing, 'Still airing or ongoing'),
              ])
                CueChoiceChip(
                  label: label,
                  selected: f.status == s,
                  onTap: () => _f = f.copyWith(status: s),
                ),
            ],
          ),
          const CueSectionLabel('Country'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (code, label) in const [
                ('JP', 'Japan'),
                ('KR', 'Korea'),
                ('CN', 'China'),
                ('TW', 'Taiwan'),
                ('US', 'United States'),
                ('GB', 'United Kingdom'),
                ('IN', 'India'),
              ])
                CueChoiceChip(
                  label: label,
                  selected: f.countries.contains(code),
                  onTap: () {
                    final next = {...f.countries};
                    next.contains(code) ? next.remove(code) : next.add(code);
                    _f = f.copyWith(countries: next);
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        hint,
        style: const TextStyle(fontSize: 13, color: CueColors.textMuted),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: CueColors.onActionPrimary,
      activeTrackColor: CueColors.actionPrimary,
    );
  }
}

class _Footer extends ConsumerStatefulWidget {
  const _Footer({required this.draft});
  final ValueNotifier<DeckFilters> draft;

  @override
  ConsumerState<_Footer> createState() => _FooterState();
}

class _FooterState extends ConsumerState<_Footer> {
  int? _count;
  int _query = 0;

  @override
  void initState() {
    super.initState();
    widget.draft.addListener(_recount);
    _recount();
  }

  @override
  void dispose() {
    widget.draft.removeListener(_recount);
    super.dispose();
  }

  Future<void> _recount() async {
    final q = ++_query;
    final n = await ref
        .read(deckControllerProvider.notifier)
        .countFor(widget.draft.value);
    if (mounted && q == _query) setState(() => _count = n);
  }

  @override
  Widget build(BuildContext context) {
    final n = _count;
    final label = n == null
        ? 'Show picks'
        : n == 0
        ? 'No picks match'
        : n == 1
        ? 'Show 1 pick'
        : 'Show $n picks';
    return Row(
      spacing: CueSpace.md,
      children: [
        CueSecondaryButton(
          label: 'Reset',
          onPressed: () =>
              widget.draft.value = DeckFilters(mood: widget.draft.value.mood),
        ),
        Expanded(
          child: CuePrimaryButton(
            label: label,
            expand: true,
            onPressed: n == 0
                ? null
                : () => Navigator.of(context).pop(widget.draft.value),
          ),
        ),
      ],
    );
  }
}
