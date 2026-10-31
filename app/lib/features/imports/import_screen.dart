import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/icons.dart';
import '../../app/layout.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../data/db/database.dart';
import '../../imports/adapters/generic_csv.dart';
import '../../imports/adapters/netflix_csv.dart';
import '../../imports/detect.dart';
import '../../imports/import_service.dart';
import '../../imports/matcher.dart';
import '../../imports/records.dart';
import 'sign_in_import.dart';

enum _Step { choose, mapColumns, matching, preview, committing, summary }

/// Import: one upload with auto-detect, plus one row per source. Nothing
/// is added until the preview's "Import N".
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _Step _step = _Step.choose;
  String? _error;
  Uint8List? _raw;
  Detected? _detected;
  StagedImport? _staged;
  ImportSummary? _summary;
  (int, int) _progress = (0, 0);
  bool _offlineOnly = false;
  bool _dayFirst = false;
  CsvMapping? _mapping;
  List<String> _csvHeader = const [];

  void _reset() => setState(() {
    _step = _Step.choose;
    _error = null;
    _raw = null;
    _detected = null;
    _staged = null;
    _summary = null;
    _mapping = null;
  });

  Future<void> _pickFile() async {
    setState(() => _error = null);
    final Uint8List bytes;
    final String name;
    try {
      final files = await FilePicker.pickFiles();
      final file = files.firstOrNull;
      if (file == null) return;
      final size = await file.length();
      if (size != null && size > ImportLimits.maxFileBytes) {
        setState(() => _error = 'Files up to 20 MB can be imported.');
        return;
      }
      bytes = await file.readAsBytes();
      name = file.name;
    } on Object {
      setState(() => _error = 'Could not open that file.');
      return;
    }
    await readBytes(bytes, name);
  }

  /// Detects the format from the bytes and moves to the next step.
  @visibleForTesting
  Future<void> readBytes(Uint8List bytes, String name) async {
    try {
      final d = detect(bytes, name);
      _raw = bytes;
      _detected = d;
      if (d.format == DetectedFormat.genericCsv) {
        final csv = GenericCsvAdapter();
        setState(() {
          _csvHeader = csv.header(d.bytes);
          _mapping = csv.guessMapping(d.bytes);
          _step = _Step.mapColumns;
        });
        return;
      }
      if (d.format == DetectedFormat.netflixCsv) {
        _dayFirst = NetflixCsvAdapter.impliesDayFirst(d.bytes);
      }
      await _parseAndStage();
    } on ImportRejected catch (e) {
      setState(() {
        _error = e.message;
        _step = _Step.choose;
      });
    }
  }

  Future<void> _parseAndStage() async {
    final d = _detected!;
    final mapping = _mapping;
    final dayFirst = _dayFirst;
    try {
      // Parse off the UI thread on native; the web build parses inline.
      final parsed = kIsWeb
          ? parseDetected(d, mapping: mapping, dayFirst: dayFirst)
          : await compute(_parseJob, _ParseJob(d, mapping, dayFirst));
      await _stage(parsed);
    } on ImportRejected catch (e) {
      setState(() {
        _error = e.message;
        _step = _Step.choose;
      });
    }
  }

  Future<void> _stage(ParsedImport parsed) async {
    if (parsed.records.isEmpty) {
      setState(() {
        _error = 'Cue read the file but found no titles in it.';
        _step = _Step.choose;
      });
      return;
    }
    setState(() {
      _step = _Step.matching;
      _progress = (0, parsed.records.length);
    });
    final profileId = await ref.read(profileIdProvider.future);
    final staged = await ref
        .read(importServiceProvider)
        .stage(
          profileId,
          parsed,
          rawBytes: _raw,
          offlineOnly: _offlineOnly,
          onProgress: (done, total) {
            if (mounted) setState(() => _progress = (done, total));
          },
        );
    if (!mounted) return;
    setState(() {
      _staged = staged;
      _step = _Step.preview;
    });
  }

  Future<void> _commit() async {
    final staged = _staged!;
    setState(() => _step = _Step.committing);
    final profileId = await ref.read(profileIdProvider.future);
    final summary = await ref
        .read(importServiceProvider)
        .commit(profileId, staged);
    await ref.read(libraryRepositoryProvider).recomputeWeights(profileId);
    ref.read(libraryVersionProvider.notifier).bump();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _step = _Step.summary;
    });
  }

  void _back() {
    if (_step == _Step.choose || _step == _Step.summary) {
      context.go(CueRoutes.library);
    } else if (_step != _Step.committing) {
      _reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = context.cueLayout == CueLayout.desktop;
    final Widget body = switch (_step) {
      _Step.choose => _ChooseSource(
        error: _error,
        offlineOnly: _offlineOnly,
        onOfflineOnly: (v) => setState(() => _offlineOnly = v),
        onUpload: _pickFile,
        onRecords: _stage,
      ),
      _Step.mapColumns => _MapColumns(
        header: _csvHeader,
        mapping: _mapping!,
        onChanged: (m) => setState(() => _mapping = m),
        onContinue: _parseAndStage,
        onCancel: _reset,
      ),
      _Step.matching => _Progress(
        label:
            'Matching ${_progress.$1} of ${_progress.$2} against the catalog…'
            '${_progress.$2 > 150 ? '\nAnime and comic lookups are limited to about 30 a minute, so a big list takes a couple of minutes. You can leave this screen open.' : ''}',
        value: _progress.$2 == 0 ? null : _progress.$1 / _progress.$2,
      ),
      _Step.preview => _Preview(
        staged: _staged!,
        dayFirst: _dayFirst,
        onDayFirst: (v) {
          setState(() => _dayFirst = v);
          _parseAndStage();
        },
        onChanged: () => setState(() {}),
        onImport: _commit,
        onCancel: _reset,
      ),
      _Step.committing => const _Progress(label: 'Adding to your library…'),
      _Step.summary => _Summary(
        summary: _summary!,
        onDone: () => context.go(CueRoutes.forYou),
      ),
    };
    return PopScope(
      canPop: _step == _Step.choose || _step == _Step.summary,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          desktop ? 4 : 10,
          desktop ? 96 : CueSpace.lg,
          desktop ? 4 : 10,
          CueSpace.xl,
        ),
        children: [
          Row(
            children: [
              CueRoundButton(
                icon: CueIcons.back,
                tooltip: 'Back',
                visualSize: 40,
                iconSize: 18,
                onPressed: _back,
              ),
              const SizedBox(width: CueSpace.sm),
              const Expanded(
                child: CueRouteHeader(
                  kicker: 'Bring your history',
                  title: 'Import',
                ),
              ),
            ],
          ),
          const SizedBox(height: CueSpace.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: body,
          ),
          const SizedBox(height: CueSpace.xl),
          if (_step == _Step.choose) const _PastImports(),
        ],
      ),
    );
  }
}

class _ParseJob {
  const _ParseJob(this.d, this.m, this.dayFirst);
  final Detected d;
  final CsvMapping? m;
  final bool dayFirst;
}

ParsedImport _parseJob(_ParseJob j) =>
    parseDetected(j.d, mapping: j.m, dayFirst: j.dayFirst);

const _muted = TextStyle(fontSize: 14, height: 1.5, color: CueColors.textMuted);

class _ChooseSource extends StatelessWidget {
  const _ChooseSource({
    required this.error,
    required this.offlineOnly,
    required this.onOfflineOnly,
    required this.onUpload,
    required this.onRecords,
  });

  final String? error;
  final bool offlineOnly;
  final ValueChanged<bool> onOfflineOnly;
  final VoidCallback onUpload;
  final Future<void> Function(ParsedImport) onRecords;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Processed on this device. Matching sends title names or catalog ids to the Cue catalog, never the whole file.',
          style: _muted,
        ),
        const SizedBox(height: CueSpace.lg),
        CuePrimaryButton(label: 'Upload any file', onPressed: onUpload),
        const SizedBox(height: CueSpace.sm),
        Text(supportedList, style: _muted.copyWith(fontSize: 13)),
        if (error != null) ...[
          const SizedBox(height: CueSpace.md),
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: const TextStyle(
                fontSize: 14,
                color: CueColors.notInterested,
              ),
            ),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: offlineOnly,
          onChanged: onOfflineOnly,
          title: const Text(
            'Match on this device only',
            style: TextStyle(fontSize: 15),
          ),
          subtitle: const Text(
            'Nothing leaves the device. Only titles Cue has already cached can be matched; the rest wait for review.',
            style: TextStyle(fontSize: 13, color: CueColors.textMuted),
          ),
          activeThumbColor: CueColors.onActionPrimary,
          activeTrackColor: CueColors.actionPrimary,
        ),
        const CueSectionLabel('Bring it straight from a service'),
        for (final p in SignInProvider.values)
          SignInSourceRow(provider: p, onRecords: onRecords),
        const SourceRow(
          name: 'MyDramaList',
          status: 'Planned',
          detail: 'MyDramaList has no official API or sign-in. Cue will never ask for your password; a public-list reader is planned after a terms check.',
        ),
        SourceRow(
          name: 'Netflix',
          status: 'Get my file',
          detail: 'On netflix.com: Account, choose the profile, Viewing activity, Download all. Then upload the CSV here. You can untick shows someone else watched.',
          action: CueSecondaryButton(
            label: 'Upload the file',
            onPressed: onUpload,
          ),
        ),
        SourceRow(
          name: 'Mihon or Tachiyomi',
          status: 'Get my file',
          detail: 'In the app: More, Backup and restore, Create backup. Upload the .tachibk file here. Only titles and read chapters are kept; settings and tracker logins are skipped.',
          action: CueSecondaryButton(
            label: 'Upload the file',
            onPressed: onUpload,
          ),
        ),
        const SourceRow(
          name: 'Prime Video',
          status: 'Not yet supported',
          detail: 'Amazon data exports vary by region and have not been verified yet. A CSV with a title column works through Upload any file.',
        ),
      ],
    );
  }
}

/// One expandable source row with its steps.
class SourceRow extends StatefulWidget {
  const SourceRow({
    super.key,
    required this.name,
    required this.status,
    required this.detail,
    this.action,
  });

  final String name;
  final String status;
  final String detail;
  final Widget? action;

  @override
  State<SourceRow> createState() => _SourceRowState();
}

class _SourceRowState extends State<SourceRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: CueSpace.sm),
      decoration: BoxDecoration(
        color: CueColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CueColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _open = !_open),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: CueSize.minTarget + 8,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        widget.status,
                        style: const TextStyle(
                          fontSize: 13,
                          color: CueColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.detail, style: _muted),
                  if (widget.action != null) ...[
                    const SizedBox(height: CueSpace.md),
                    widget.action!,
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MapColumns extends StatelessWidget {
  const _MapColumns({
    required this.header,
    required this.mapping,
    required this.onChanged,
    required this.onContinue,
    required this.onCancel,
  });

  final List<String> header;
  final CsvMapping mapping;
  final ValueChanged<CsvMapping> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  CsvMapping _with({
    int? title,
    int? status,
    int? date,
    int? rating,
    String? field,
  }) => CsvMapping(
    title: title ?? mapping.title,
    status: field == 'status' ? status : mapping.status,
    date: field == 'date' ? date : mapping.date,
    rating: field == 'rating' ? rating : mapping.rating,
    delimiter: mapping.delimiter,
  );

  @override
  Widget build(BuildContext context) {
    Widget picker(
      String label,
      int? value,
      ValueChanged<int?> set, {
      bool optional = true,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CueSpace.md),
        child: DropdownButtonFormField<int?>(
          isExpanded: true,
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: [
            if (optional)
              const DropdownMenuItem(
                value: null,
                child: Text('Not in this file'),
              ),
            for (var i = 0; i < header.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(header[i].isEmpty ? 'Column ${i + 1}' : header[i]),
              ),
          ],
          onChanged: set,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tell Cue which columns hold what. Values are read as plain text.',
          style: _muted,
        ),
        const SizedBox(height: CueSpace.lg),
        picker(
          'Title',
          mapping.title,
          (v) => onChanged(_with(title: v ?? 0)),
          optional: false,
        ),
        picker(
          'Status (optional)',
          mapping.status,
          (v) => onChanged(_with(status: v, field: 'status')),
        ),
        picker(
          'Date watched (optional)',
          mapping.date,
          (v) => onChanged(_with(date: v, field: 'date')),
        ),
        picker(
          'Your rating (optional)',
          mapping.rating,
          (v) => onChanged(_with(rating: v, field: 'rating')),
        ),
        Row(
          spacing: CueSpace.md,
          children: [
            CueSecondaryButton(label: 'Cancel', onPressed: onCancel),
            CuePrimaryButton(label: 'Continue', onPressed: onContinue),
          ],
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.label, this.value});
  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: CueSpace.md),
          LinearProgressIndicator(
            value: value,
            color: CueColors.accent,
            backgroundColor: CueColors.surfaceHigh,
          ),
        ],
      ),
    );
  }
}

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
              'Untick to import only id matches; the rest wait for review.',
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
                label: n == 0 ? 'Nothing to import' : 'Import $n',
                expand: true,
                onPressed: n == 0 ? null : onImport,
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

class _Summary extends StatelessWidget {
  const _Summary({required this.summary, required this.onDone});
  final ImportSummary summary;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final text = s.alreadyImported
        ? 'You already imported this exact file. Nothing changed.'
        : '${s.checked} records checked. ${s.added} added, ${s.updated} existing titles updated, '
              '${s.unchanged} unchanged, ${s.review} need review. No changes were made to your source service.';
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontSize: 16, height: 1.5)),
          if (s.review > 0) ...[
            const SizedBox(height: CueSpace.sm),
            const Text(
              'Titles that need review wait in Library. They never change recommendations until you match them.',
              style: _muted,
            ),
          ],
          const SizedBox(height: CueSpace.lg),
          CuePrimaryButton(label: 'Back to For you', onPressed: onDone),
        ],
      ),
    );
  }
}

class _PastImports extends ConsumerStatefulWidget {
  const _PastImports();

  @override
  ConsumerState<_PastImports> createState() => _PastImportsState();
}

class _PastImportsState extends ConsumerState<_PastImports> {
  late Future<List<ImportBatch>> _batches = _load();
  String? _message;

  Future<List<ImportBatch>> _load() async {
    final id = await ref.read(profileIdProvider.future);
    return ref.read(importServiceProvider).batches(id);
  }

  Future<void> _undo(ImportBatch b) async {
    final ok = await confirmAction(
      context,
      title: 'Undo this import?',
      body: 'Titles this import added or changed go back to how they were. Anything you edited since stays as it is.',
      confirmLabel: 'Undo import',
    );
    if (!ok) return;
    final id = await ref.read(profileIdProvider.future);
    final r = await ref.read(importServiceProvider).undo(id, b.id);
    await ref.read(libraryRepositoryProvider).recomputeWeights(id);
    ref.read(libraryVersionProvider.notifier).bump();
    if (!mounted) return;
    setState(() {
      _message = r.kept == 0
          ? 'Import undone. ${r.reverted} titles restored.'
          : 'Import undone. ${r.reverted} titles restored; ${r.kept} you edited since were kept.';
      _batches = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _batches,
      builder: (context, snap) {
        // Sync merges are bookkeeping, not imports the person made.
        final list = (snap.data ?? const <ImportBatch>[])
            .where((b) => b.sourceType != 'sync')
            .toList();
        if (list.isEmpty && _message == null) return const SizedBox.shrink();
        final fmt = DateFormat.yMMMd().add_jm();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CueSectionLabel('Past imports'),
            if (_message != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFC1DEF7),
                  ),
                ),
              ),
            for (final b in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  importSourceName(b.sourceType),
                  style: const TextStyle(fontSize: 15),
                ),
                subtitle: Text(
                  '${fmt.format(b.createdAt)} · ${b.state == 'undone' ? 'Undone' : 'Imported'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: CueColors.textMuted,
                  ),
                ),
                trailing: b.state == 'completed'
                    ? CueSecondaryButton(
                        label: 'Undo',
                        onPressed: () => _undo(b),
                      )
                    : null,
              ),
          ],
        );
      },
    );
  }
}

String importSourceName(String type) => switch (type) {
  'mal_xml' => 'MyAnimeList file',
  'netflix_csv' => 'Netflix activity',
  'cue_backup' => 'Cue backup',
  'xlsx' => 'Spreadsheet',
  'generic_csv' => 'CSV file',
  'mihon_backup' => 'Mihon backup',
  'mal_api' => 'MyAnimeList sign-in',
  'anilist_api' => 'AniList sign-in',
  'trakt_api' => 'Trakt sign-in',
  'sync' => 'sync',
  _ => 'Import',
};
