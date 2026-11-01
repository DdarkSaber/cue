part of '../import_screen.dart';

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
