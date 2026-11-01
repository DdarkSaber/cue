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
                  body,
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

class _ParseJob {
  const _ParseJob(this.d, this.m, this.dayFirst);
  final Detected d;
  final CsvMapping? m;
  final bool dayFirst;
}

ParsedImport _parseJob(_ParseJob j) =>
    parseDetected(j.d, mapping: j.m, dayFirst: j.dayFirst);

const _muted = TextStyle(fontSize: 14, height: 1.5, color: CueColors.textMuted);
