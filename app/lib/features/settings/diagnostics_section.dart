part of 'settings_screen.dart';

class DiagnosticsSection extends ConsumerStatefulWidget {
  const DiagnosticsSection({super.key});
  @override
  ConsumerState<DiagnosticsSection> createState() => _DiagnosticsSectionState();
}

class _DiagnosticsSectionState extends ConsumerState<DiagnosticsSection> {
  bool _busy = false;
  bool _showCode = false;
  String? _error;

  Future<void> _toggle(bool on) async {
    final service = ref.read(technicalDiagnosticsProvider);
    if (on) {
      final agreed = await confirmAction(
        context,
        title: 'Share technical diagnostics?',
        body: 'Off by default. Only new catalog/import HTTP requests send app version, provider, timing, status, fixed error codes and random request IDs to Cue. Never titles, searches, Tell me text, history, files, URLs, raw errors, tokens or keys. Up to 100 events per session; access expires 7 days after its first upload. Expired records are physically cleaned on later diagnostics requests, not on an exact deletion timer. Your private recovery code grants access; do not share it publicly. Turning off cancels pending events, but cannot recall an upload already received. Diagnostics cannot explain an incorrect title match without title data. Free-plan quotas or service failures can stop uploads; no free-forever guarantee.',
        confirmLabel: 'Enable diagnostics',
      );
      if (!agreed || !mounted) return;
    }
    await _action(() => service.setEnabled(on));
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error) {
      debugPrint('Diagnostics action failed (${error.runtimeType}).');
      if (mounted) {
        setState(
          () => _error = 'Could not complete diagnostics action. Collection/export status is shown below.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() => _action(() async {
    final json = await ref.read(technicalDiagnosticsProvider).export();
    final result = await FilePicker.saveFile(
      fileName: 'cue-technical-diagnostics.json',
      bytes: Uint8List.fromList(utf8.encode(json)),
      mimeType: 'application/json',
    );
    if (mounted) {
      setState(
        () => _error = result == null
            ? 'Export cancelled.'
            : 'Technical diagnostics exported without the recovery code.',
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(technicalDiagnosticsProvider);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CueSectionLabel('Optional technical diagnostics'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Share technical diagnostics'),
            subtitle: const Text(
              'Off by default. Technical HTTP timings/codes only; no title or personal content.',
            ),
            value: service.enabled,
            onChanged: service.loaded && !_busy ? _toggle : null,
          ),
          const Text(
            'Device-wide consent, never copied by library backup or sync. Up to 100 events per seven-day session. Access expires after 7 days; physical cleanup happens on later diagnostics requests. Only new requests after consent; turning off drops pending events. Uploads require the updated Worker to be deployed separately. Quota/unavailable errors are shown; no automatic retry loop.',
            style: _body,
          ),
          if (service.message != null)
            Semantics(
              liveRegion: true,
              child: Text(service.message!, style: _body),
            ),
          if (_error != null)
            Semantics(liveRegion: true, child: Text(_error!, style: _body)),
          Wrap(
            spacing: CueSpace.sm,
            children: [
              if (service.enabled)
                CueSecondaryButton(
                  label: 'Retry upload (${service.pendingCount})',
                  onPressed:
                      _busy || service.sending || service.pendingCount == 0
                      ? null
                      : () => _action(service.upload),
                ),
              if (service.recoveryCode != null) ...[
                CueSecondaryButton(
                  label: _showCode
                      ? 'Hide recovery code'
                      : 'Show recovery code',
                  onPressed: () => setState(() => _showCode = !_showCode),
                ),
                CueSecondaryButton(
                  label: 'Export technical diagnostics',
                  onPressed: _busy ? null : _export,
                ),
              ],
            ],
          ),
          if (_showCode && service.recoveryCode != null) ...[
            const Text(
              'Private capability: anyone holding this code can retrieve these technical logs. Share only with your trusted troubleshooting session.',
              style: _body,
            ),
            SelectableText(service.recoveryCode!),
            const Text(
              'For CLI retrieval: hash the recovery code with SHA-256 to obtain the session ID, then GET /diagnostics/<session ID> using Authorization: Bearer <recovery code>. Do not put the code in a public issue or URL.',
              style: _body,
            ),
          ],
        ],
      ),
    );
  }
}
