part of '../import_screen.dart';

class _Preview extends StatelessWidget {
  const _Preview({
    required this.staged,
    required this.dayFirst,
    required this.onDayFirst,
    required this.onChanged,
    required this.onImport,
    required this.onCancel,
  });

  final StagedImport staged;
  final bool dayFirst;
  final ValueChanged<bool> onDayFirst;
  final VoidCallback onChanged;
  final VoidCallback onImport;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = staged.parsed;
    final n = staged.included.length;
    final fmt = DateFormat.yMMMd();
    final titleMatches = staged.matched
        .where((m) => m.matchClass == MatchClass.suggested)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${staged.matched.length} records checked. ${staged.readyNew} ready to add, '
          '${staged.readyUpdates} already in your library, ${staged.needsReview} need review.',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        if (p.skipped > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${p.skipped} rows skipped (no title, or marked not watched).',
              style: _muted,
            ),
          ),
        for (final w in p.warnings)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              w,
              style: const TextStyle(fontSize: 14, color: CueColors.notNow),
            ),
          ),
        if (p.dateRange != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Activity from ${fmt.format(p.dateRange!.$1)} to ${fmt.format(p.dateRange!.$2)}.',
              style: _muted,
            ),
          ),
        if (p.needsDateOrder) ...[
          const CueSectionLabel('How are dates written in this file?'),
          Wrap(
            spacing: 8,
            children: [
              CueChoiceChip(
                label: 'Month first (03/14/24)',
                selected: !dayFirst,
                onTap: () => onDayFirst(false),
              ),
              CueChoiceChip(
                label: 'Day first (14/03/24)',
                selected: dayFirst,
                onTap: () => onDayFirst(true),
              ),
            ],
          ),
        ],
        const CueSectionLabel('What will be added'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in staged.byState.entries)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: CueColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(CueRadius.chip),
                ),
                child: Text(
                  '${e.key.label}: ${e.value}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: CueSpace.md),
        Text(
          '${staged.byId} matched by catalog id, ${staged.byTitle} by exact title. '
          'Ratings from the file stay separate from catalog scores.',
          style: _muted,
        ),
        if (staged.similar > 0)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: staged.matched
                .where((m) => m.matchClass == MatchClass.similar)
                .every((m) => m.included),
            onChanged: (v) {
              for (final m in staged.matched.where(
                (m) => m.matchClass == MatchClass.similar,
              )) {
                m.included = v;
              }
              onChanged();
            },
            title: Text(
              'Include ${staged.similar} similar titles',
              style: const TextStyle(fontSize: 15),
            ),
            subtitle: const Text(
              'Close but not identical, such as a fan name for the official one. Look through the list before ticking; each shows the title it would link to.',
              style: TextStyle(fontSize: 13, color: CueColors.textMuted),
            ),
            activeThumbColor: CueColors.onActionPrimary,
            activeTrackColor: CueColors.actionPrimary,
          ),
        if (staged.unconfirmed > 0)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: staged.matched
                .where((m) => m.resolved && !m.record.confirmed)
                .every((m) => m.included),
            onChanged: (v) {
              for (final m in staged.matched.where(
                (m) => m.resolved && !m.record.confirmed,
              )) {
                m.included = v;
              }
              onChanged();
            },
            title: Text(
              'Include ${staged.unconfirmed} unconfirmed plays',
              style: const TextStyle(fontSize: 15),
            ),
            subtitle: const Text(
              'Netflix says these were played, which can be an autoplayed preview. Off by default, so they do not hide titles you never watched.',
              style: TextStyle(fontSize: 13, color: CueColors.textMuted),
            ),
            activeThumbColor: CueColors.onActionPrimary,
            activeTrackColor: CueColors.actionPrimary,
          ),
        if (staged.adultHidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${staged.adultHidden} titles are rated adult and kept out of Cue (change this in Settings).',
              style: _muted,
            ),
          ),
        if (staged.unchecked > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${staged.unchecked} titles could not be checked just now (offline or busy). They wait in Library, or cancel and try again.',
              style: const TextStyle(fontSize: 14, color: CueColors.notNow),
            ),
          ),
        if (titleMatches.isNotEmpty)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: titleMatches.every((m) => m.included),
            onChanged: (v) {
              for (final m in titleMatches) {
                m.included = v;
              }
              onChanged();
            },
            title: const Text(
              'Include exact-title matches',
              style: TextStyle(fontSize: 15),
            ),
            subtitle: const Text(
              'Untick to leave these exact matches out of this import.',
              style: TextStyle(fontSize: 13, color: CueColors.textMuted),
            ),
            activeThumbColor: CueColors.onActionPrimary,
            activeTrackColor: CueColors.actionPrimary,
          ),
        const CueSectionLabel('Titles'),
        _RecordList(staged: staged, onChanged: onChanged),
        const SizedBox(height: CueSpace.lg),
        Row(
          spacing: CueSpace.md,
          children: [
            CueSecondaryButton(label: 'Cancel', onPressed: onCancel),
            Expanded(
              child: CuePrimaryButton(
                label: n > 0
                    ? 'Import $n'
                    : staged.needsReview > 0
                    ? 'Save ${staged.needsReview} for review'
                    : 'Nothing to import',
                expand: true,
                onPressed: n == 0 && staged.needsReview == 0 ? null : onImport,
              ),
            ),
          ],
        ),
        const SizedBox(height: CueSpace.sm),
        const Text('Cancel leaves your library untouched.', style: _muted),
      ],
    );
  }
}

class _RecordList extends StatefulWidget {
  const _RecordList({required this.staged, required this.onChanged});
  final StagedImport staged;
  final VoidCallback onChanged;

  @override
  State<_RecordList> createState() => _RecordListState();
}

class _RecordListState extends State<_RecordList> {
  String _filter = '';
  int _shown = 40;

  @override
  Widget build(BuildContext context) {
    final items =
        widget.staged.matched
            .where(
              (m) =>
                  _filter.isEmpty ||
                  m.record.title.toLowerCase().contains(_filter),
            )
            .toList()
          ..sort((a, b) => (a.resolved ? 0 : 1).compareTo(b.resolved ? 0 : 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Find a title in this file',
          ),
          onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
        ),
        const SizedBox(height: CueSpace.sm),
        for (final m in items.take(_shown))
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: m.included && m.resolved,
            onChanged: m.resolved
                ? (v) {
                    m.included = v ?? false;
                    widget.onChanged();
                    setState(() {});
                  }
                : null,
            title: Text(m.record.title, style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              [
                m.record.state.label,
                switch (m.matchClass) {
                  MatchClass.exactId => 'matched by id',
                  MatchClass.confirmed => 'confirmed',
                  MatchClass.suggested => 'matched by title',
                  MatchClass.similar =>
                    'similar: ${m.candidateName ?? 'a catalog title'}',
                  MatchClass.unresolved =>
                    m.adultHidden
                        ? 'adult-rated, kept out'
                        : m.unchecked
                        ? 'not checked'
                        : 'needs review',
                },
                if (m.record.plays != null) '${m.record.plays} plays',
              ].join(' · '),
              style: const TextStyle(fontSize: 12, color: CueColors.textMuted),
            ),
          ),
        if (items.length > _shown)
          TextButton(
            onPressed: () => setState(() => _shown += 80),
            child: Text('Show more (${items.length - _shown} left)'),
          ),
      ],
    );
  }
}
