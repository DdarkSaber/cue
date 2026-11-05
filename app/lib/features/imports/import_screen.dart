import 'dart:async' show Timer;
import 'dart:math' show Random;

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
import '../library/rating_deck.dart';
import 'import_job.dart';
import 'sign_in_import.dart';
import 'source_names.dart';

part 'steps/choose_source.dart';
part 'steps/map_columns.dart';
part 'steps/past_imports.dart';
part 'steps/preview.dart';
part 'steps/progress.dart';
part 'steps/summary.dart';

enum _Step { choose, mapColumns, matching, preview, committing, summary }

/// Import: one upload with auto-detect, plus one row per source. Nothing
/// is added until the preview's "Import N".
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ImportScreenState createState() => ImportScreenState();
}

class ImportScreenState extends ConsumerState<ImportScreen> {
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
  String? _jobProfileId;
  bool _parsing = false;
  int _parseEpoch = 0;

  Future<void> _reset() async {
    _parseEpoch++;
    final cleared = await ref.read(importJobProvider.notifier).clear();
    if (mounted && cleared) setState(_clear);
  }

  void _clear() {
    _step = _Step.choose;
    _error = null;
    _raw = null;
    _detected = null;
    _staged = null;
    _summary = null;
    _mapping = null;
    _parsing = false;
    _parseEpoch++;
  }

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
        setState(
          () => _error = 'That file is over 20 MB, the most Cue can import. Export a smaller list or split it, then try again.',
        );
        return;
      }
      bytes = await file.readAsBytes();
      name = file.name;
    } on Object {
      setState(
        () => _error = 'Could not open that file. Check it is still on this device, then try again.',
      );
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
    final profileId = _jobProfileId;
    final epoch = ++_parseEpoch;
    setState(() {
      _parsing = true;
      _step = _Step.matching;
    });
    try {
      // Parse off the UI thread on native; the web build parses inline.
      final parsed = kIsWeb
          ? parseDetected(d, mapping: mapping, dayFirst: dayFirst)
          : await compute(_parseJob, _ParseJob(d, mapping, dayFirst));
      if (!mounted ||
          epoch != _parseEpoch ||
          (profileId != null && _jobProfileId != profileId)) {
        return;
      }
      _parsing = false;
      await _stage(parsed);
    } on ImportRejected catch (e) {
      if (!mounted ||
          epoch != _parseEpoch ||
          (profileId != null && _jobProfileId != profileId)) {
        return;
      }
      setState(() {
        _parsing = false;
        _error = e.message;
        _step = _Step.choose;
      });
    }
  }

  Future<void> _stage(ParsedImport parsed) async {
    if (parsed.records.isEmpty) {
      setState(() {
        _error = 'Cue read the file but found no titles in it. Check it has a Title column, or choose a different export.';
        _step = _Step.choose;
      });
      return;
    }
    setState(() => _step = _Step.matching);
    // The job keeps running if this screen is left; build() picks up its
    // progress and result.
    await ref
        .read(importJobProvider.notifier)
        .start(
          parsed,
          rawBytes: _raw,
          offlineOnly: _offlineOnly,
          dayFirst: _dayFirst,
        );
  }

  Future<void> _commit() async {
    final staged = _staged!;
    final profileId = _jobProfileId;
    setState(() => _step = _Step.committing);
    final summary = await ref.read(importJobProvider.notifier).commit(staged);
    if (!mounted) return;
    if (_jobProfileId != profileId || _staged?.draftId != staged.draftId) {
      return;
    }
    if (summary == null) {
      setState(() => _step = _Step.preview);
      return;
    }
    setState(() {
      _summary = summary;
      _step = _Step.summary;
    });
  }

  /// Jumps straight to the summary step, for widget tests of its buttons.
  @visibleForTesting
  void debugShowSummary(ImportSummary summary) => setState(() {
    _summary = summary;
    _step = _Step.summary;
  });

  /// The importer lives in the Library tab's stack. Going straight to For you
  /// would leave it parked there, so Library would reopen on the summary:
  /// reset the stack to the Library list first, then switch tabs.
  void _leaveToForYou() {
    final router = GoRouter.of(context);
    router.go(CueRoutes.library);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.go(CueRoutes.forYou);
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
    // Matching runs in importJobProvider, so this screen can be left and
    // reopened: follow its progress, result or error.
    final job = ref.watch(importJobProvider);
    if (_jobProfileId != job.profileId) {
      if (_jobProfileId != null) _clear();
      _jobProfileId = job.profileId;
    }
    if (job.running && _step != _Step.committing && _step != _Step.summary) {
      _step = _Step.matching;
      _error = null;
    }
    if (job.staged != null &&
        !_parsing &&
        _step != _Step.committing &&
        _step != _Step.summary) {
      _staged = job.staged;
      _dayFirst = job.dayFirst;
      _raw = ref.read(importJobProvider.notifier).rawBytes;
      _offlineOnly = ref.read(importJobProvider.notifier).offlineOnly;
      _step = _Step.preview;
    }
    if (job.error != null && _step == _Step.matching) {
      _error = job.error;
      _step = _Step.choose;
    }
    if (job.error != null) _error = job.error;
    _progress = (job.done, job.total);
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
        label: _parsing
            ? 'Reading your file…'
            : 'Matching ${_progress.$1} of ${_progress.$2} against the catalog…'
                  '${_progress.$2 > 150 ? '\nAnime and comic lookups are limited to about 30 a minute, so a big list takes a couple of minutes. You can leave this screen and keep swiping; the deck shows the progress.' : ''}'
                  '\nProgress is saved on this device. If the app closes or you go offline, open Import again and matching carries on from where it stopped.',
        value: _progress.$2 == 0 ? null : _progress.$1 / _progress.$2,
      ),
      _Step.preview => _Preview(
        staged: _staged!,
        dayFirst: _dayFirst,
        onDayFirst: (v) {
          setState(() => _dayFirst = v);
          if (_detected == null && _raw != null) {
            _detected = detect(_raw!, 'import.csv');
          }
          _parseAndStage();
        },
        onChanged: () {
          setState(() {});
          ref.read(importJobProvider.notifier).savePreview();
        },
        onImport: _commit,
        onCancel: _reset,
      ),
      _Step.committing => const _Progress(label: 'Adding to your library…'),
      _Step.summary => _Summary(summary: _summary!, onDone: _leaveToForYou),
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
          // A ListView gives its children the full width, so the cap needs an
          // Align to take effect on wide screens.
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepHeader(step: _step),
                  body,
                  if (job.error != null) ...[
                    if (_step != _Step.choose) Text(job.error!, style: _muted),
                    CueSecondaryButton(
                      label: 'Retry saved import',
                      onPressed: () =>
                          ref.read(importJobProvider.notifier).retry(),
                    ),
                  ],
                  const SizedBox(height: CueSpace.xl),
                  if (_step == _Step.choose) const _PastImports(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Step 2 of 3" with a plain-language name, so the flow is never a mystery.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});
  final _Step step;

  @override
  Widget build(BuildContext context) {
    final (n, name) = switch (step) {
      _Step.choose => (1, 'Pick your list'),
      _Step.mapColumns => (1, 'Tell Cue which column is which'),
      _Step.matching => (2, 'Matching your titles'),
      _Step.preview => (3, 'Check and confirm'),
      _Step.committing => (3, 'Adding to your library'),
      _Step.summary => (3, 'All done'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: CueSpace.md),
      child: Semantics(
        header: true,
        label: 'Step $n of 3: $name',
        excludeSemantics: true,
        child: Row(
          children: [
            for (var i = 1; i <= 3; i++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  width: 22,
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= n ? CueColors.accent : CueColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            const SizedBox(width: CueSpace.sm),
            Expanded(
              child: Text(
                'Step $n of 3 \u00b7 $name',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFA7B5C5),
                ),
              ),
            ),
          ],
        ),
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
