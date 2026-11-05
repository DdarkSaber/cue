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
              'Titles that need review are not yet recognised as history, so they may still appear in suggestions. Match them in Library to avoid repeats.',
              style: _muted,
            ),
          ],
          const SizedBox(height: CueSpace.lg),
          Wrap(
            spacing: CueSpace.md,
            runSpacing: CueSpace.sm,
            children: [
              CuePrimaryButton(label: 'Back to For you', onPressed: onDone),
              if (s.review > 0)
                CueSecondaryButton(
                  label: 'Review ${s.review} in Library',
                  onPressed: () => context.go(CueRoutes.library),
                )
              else
                Consumer(
                  builder: (context, ref, _) => CueSecondaryButton(
                    label: 'Rate titles in Library',
                    onPressed: () async {
                      // The same rating deck as Library; leaving it lands
                      // in Library with the new ratings.
                      await openLibraryRating(context, ref);
                      if (context.mounted) context.go(CueRoutes.library);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
