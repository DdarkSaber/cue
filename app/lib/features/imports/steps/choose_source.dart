part of '../import_screen.dart';

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
