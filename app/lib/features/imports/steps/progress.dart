part of '../import_screen.dart';

/// Matching and adding: the stage in words, the real progress bar, a small
/// wall of poster tiles that keep changing colour, and a skeleton of the
/// review list to come, shimmering softly while work runs. With reduced
/// motion the tiles and skeleton stay still. Only the words and the bar
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
        const ExcludeSemantics(child: _PosterTiles()),
        const SizedBox(height: CueSpace.lg),
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

/// A 3 x 2 wall of poster-shaped tiles in flat, muted tones. Every 0.7 to
/// 1 s one random tile cross-fades to another tone, so the screen keeps
/// visibly working. No images, no network. With reduced motion the tiles
/// hold still and no timer runs.
class _PosterTiles extends StatefulWidget {
  const _PosterTiles();

  static const columns = 3;
  static const count = 6;

  /// Cross-fade length for one tile.
  static const fade = Duration(milliseconds: 600);

  /// Shortest and longest pause between two tile changes.
  static const minGap = Duration(milliseconds: 700);
  static const maxGap = Duration(milliseconds: 1000);

  /// Card-surface tones nudged towards the decision colours: muted enough
  /// to read as placeholders on the dark background.
  static final palette = [
    CueColors.surfaceHigh,
    Color.lerp(CueColors.surface, CueColors.accent, 0.14)!,
    Color.lerp(CueColors.surface, CueColors.willTry, 0.14)!,
    Color.lerp(CueColors.surface, CueColors.notNow, 0.14)!,
    Color.lerp(CueColors.surface, CueColors.watched, 0.1)!,
    Color.lerp(CueColors.surface, CueColors.notInterested, 0.12)!,
  ];

  @override
  State<_PosterTiles> createState() => _PosterTilesState();
}

class _PosterTilesState extends State<_PosterTiles> {
  final _random = Random();

  /// Palette index per tile; starts as a fixed, varied arrangement.
  final _tones = [
    for (var i = 0; i < _PosterTiles.count; i++)
      (i * 2 + i ~/ _PosterTiles.columns) % _PosterTiles.palette.length,
  ];
  Timer? _timer;
  bool _still = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= _schedule();
    }
  }

  Timer _schedule() {
    final span = _PosterTiles.maxGap - _PosterTiles.minGap;
    final gap =
        _PosterTiles.minGap +
        Duration(milliseconds: _random.nextInt(span.inMilliseconds + 1));
    return Timer(gap, _tick);
  }

  void _tick() {
    if (!mounted || _still) return;
    setState(() {
      final tile = _random.nextInt(_PosterTiles.count);
      // Any tone but the current one, so every tick visibly changes.
      final shift = 1 + _random.nextInt(_PosterTiles.palette.length - 1);
      _tones[tile] = (_tones[tile] + shift) % _PosterTiles.palette.length;
    });
    _timer = _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const rows = _PosterTiles.count ~/ _PosterTiles.columns;
    return Center(
      key: const ValueKey('import-tiles'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          children: [
            for (var r = 0; r < rows; r++) ...[
              if (r > 0) const SizedBox(height: CueSpace.sm),
              Row(
                children: [
                  for (var c = 0; c < _PosterTiles.columns; c++) ...[
                    if (c > 0) const SizedBox(width: CueSpace.sm),
                    Expanded(child: _tile(r * _PosterTiles.columns + c)),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(int i) => AspectRatio(
    aspectRatio: 2 / 3,
    child: AnimatedContainer(
      key: ValueKey('import-tile-$i'),
      duration: _still ? Duration.zero : _PosterTiles.fade,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _PosterTiles.palette[_tones[i]],
        // Same rounding as the poster tiles in the taste quickstart.
        borderRadius: BorderRadius.circular(CueRadius.chip),
      ),
    ),
  );
}
