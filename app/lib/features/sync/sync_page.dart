import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/route_scaffold.dart';
import '../../app/router.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../sync/sync_controller.dart';

const _body = TextStyle(fontSize: 14, height: 1.55, color: CueColors.textMuted);

/// Optional sync between your devices. No account: a 32-character code
/// encrypts the library on the device; the Worker stores only ciphertext.
class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncControllerProvider);
    final c = ref.read(syncControllerProvider.notifier);
    final s = status.value ?? const SyncStatus();
    return RouteScaffold(
      kicker: 'Settings',
      title: 'Sync between devices',
      onBack: () => context.go(CueRoutes.settings),
      children: [
        const Text(
          'Keep your phone and the web app on one library. Your library is encrypted on this device with a sync code before it leaves; the Cue Worker stores only the encrypted copy and cannot read it. Free, no account.',
          style: _body,
        ),
        const SizedBox(height: CueSpace.sm),
        const Text(
          'Lose every device and the code, and the copy cannot be recovered: nobody else holds the key. Additions and changes sync; removing a title on one device does not remove it on the others yet.',
          style: _body,
        ),
        const SizedBox(height: CueSpace.lg),
        if (status.isLoading && status.value == null)
          const LinearProgressIndicator(color: CueColors.accent)
        else if (!s.enabled) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: CuePrimaryButton(
              label: 'Turn on sync',
              onPressed: s.busy ? null : c.enable,
            ),
          ),
          const CueSectionLabel('Already synced on another device?'),
          Row(
            spacing: CueSpace.sm,
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 48,
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: 'XXXX-XXXX-XXXX-XXXX-…',
                  ),
                ),
              ),
              CueSecondaryButton(
                label: 'Join',
                onPressed: s.busy ? null : () => c.join(_code.text),
              ),
            ],
          ),
        ] else ...[
          const CueSectionLabel('Your sync code'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CueColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CueColors.line),
            ),
            child: SelectableText(
              s.code ?? '',
              style: const TextStyle(
                fontSize: 17,
                letterSpacing: 1.2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Treat it like a password: anyone with it can read and change this library.',
            style: TextStyle(fontSize: 13, color: CueColors.notNow),
          ),
          const SizedBox(height: CueSpace.md),
          Wrap(
            spacing: CueSpace.md,
            runSpacing: CueSpace.sm,
            children: [
              CueSecondaryButton(
                label: 'Copy code',
                onPressed: s.code == null
                    ? null
                    : () => Clipboard.setData(ClipboardData(text: s.code!)),
              ),
              CuePrimaryButton(
                label: 'Sync now',
                onPressed: s.busy ? null : () => c.syncNow(),
              ),
            ],
          ),
          const SizedBox(height: CueSpace.sm),
          Text(
            s.lastSynced == null
                ? 'Not synced yet.'
                : 'Last synced ${DateFormat.yMMMd().add_jm().format(s.lastSynced!.toLocal())}.',
            style: const TextStyle(fontSize: 13, color: CueColors.textMuted),
          ),
          const SizedBox(height: CueSpace.xl),
          const Divider(color: CueColors.line),
          Wrap(
            spacing: CueSpace.md,
            runSpacing: CueSpace.sm,
            children: [
              CueSecondaryButton(
                label: 'Turn off on this device',
                onPressed: s.busy ? null : c.disable,
              ),
              CueSecondaryButton(
                label: 'Delete the synced copy',
                destructive: true,
                onPressed: s.busy
                    ? null
                    : () async {
                        final ok = await confirmAction(
                          context,
                          title: 'Delete the synced copy?',
                          body: 'The encrypted copy on the Cue Worker is deleted and sync stops. Each device keeps its own library.',
                          confirmLabel: 'Delete copy',
                        );
                        if (ok) await c.deleteRemote();
                      },
              ),
            ],
          ),
        ],
        if (s.busy) ...[
          const SizedBox(height: CueSpace.md),
          const LinearProgressIndicator(color: CueColors.accent),
        ],
        if (s.message != null) ...[
          const SizedBox(height: CueSpace.md),
          Semantics(
            liveRegion: true,
            child: Text(
              s.message!,
              style: const TextStyle(fontSize: 14, color: Color(0xFFC1DEF7)),
            ),
          ),
        ],
      ],
    );
  }
}
