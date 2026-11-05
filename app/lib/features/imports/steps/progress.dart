part of '../import_screen.dart';

/// Matching and adding: the stage in words, the real progress bar, and a
/// skeleton of the review list to come, shimmering softly while work runs.
/// With reduced motion the skeleton stays still. Only the words and the bar
/// reach screen readers; the placeholders are decoration.
class _Progress extends StatefulWidget {
  const _Progress({required this.label, this.value});
  final String label;
  final double? value;

  /// Placeholder rows: about one screen of the review list.
  static const rows = 6;

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    const placeholders = _SkeletonRows(count: _Progress.rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.label, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: CueSpace.md),
              LinearProgressIndicator(
                value: widget.value,
                color: CueColors.accent,
                backgroundColor: CueColors.surfaceHigh,
              ),
            ],
          ),
        ),
        const SizedBox(height: CueSpace.xl),
        ExcludeSemantics(
          child: KeyedSubtree(
            key: const ValueKey('import-skeleton'),
            child: still
                ? placeholders
                : AnimatedBuilder(
                    animation: _shimmer,
                    child: placeholders,
                    builder: (context, child) => ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (bounds) =>
                          _shimmerGradient(_shimmer.value).createShader(bounds),
                      child: child,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// A soft band of light that sweeps left to right across the placeholders.
/// Painted on top of them (srcATop), so their own shapes and tones show.
LinearGradient _shimmerGradient(double t) => LinearGradient(
  colors: [
    CueColors.text.withValues(alpha: 0),
    CueColors.text.withValues(alpha: 0.07),
    CueColors.text.withValues(alpha: 0),
  ],
  stops: const [0.35, 0.5, 0.65],
  // The band is one widget wide and its centre travels from just off the
  // left edge to just off the right.
  begin: Alignment(-3 + 4 * t, 0),
  end: Alignment(-1 + 4 * t, 0),
);

/// Rows shaped like the review list: a poster, a title, a detail line and
/// a tick box.
class _SkeletonRows extends StatelessWidget {
  const _SkeletonRows({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: CueColors.surfaceHigh,
          borderRadius: BorderRadius.circular(CueRadius.chip),
        ),
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.only(bottom: CueSpace.sm),
            padding: const EdgeInsets.all(CueSpace.md),
            decoration: BoxDecoration(
              color: CueColors.surface,
              borderRadius: BorderRadius.circular(CueRadius.chip),
              border: Border.all(color: CueColors.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 56,
                  decoration: BoxDecoration(
                    color: CueColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(CueSpace.xs + 2),
                  ),
                ),
                const SizedBox(width: CueSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Varied widths so the rows read as a list, not a grid.
                      bar(
                        const [0.72, 0.55, 0.64, 0.48, 0.68, 0.58][i % 6],
                        12,
                      ),
                      const SizedBox(height: CueSpace.sm),
                      bar(const [0.38, 0.3, 0.42, 0.34, 0.28, 0.4][i % 6], 10),
                    ],
                  ),
                ),
                const SizedBox(width: CueSpace.md),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: CueColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(CueSpace.xs),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
