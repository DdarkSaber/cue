part of '../import_screen.dart';

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
