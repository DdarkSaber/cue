part of '../import_screen.dart';

/// Matching and adding: the stage in words, the real progress bar, a small
/// wall of poster tiles that keep changing, and a skeleton of the review
/// list to come, shimmering softly while work runs. The tiles and the
/// skeleton's thumbnails show posters already cached on this device,
/// dimmed so they read as loading, not results; with too few cached (a
/// fresh install), or until a poster has loaded, they show muted tones.
/// With reduced motion everything stays still. Only the words and the bar
/// reach screen readers; the placeholders are decoration.
class _Progress extends ConsumerStatefulWidget {
  const _Progress({required this.label, this.value});
  final String label;
  final double? value;

  /// Placeholder rows: about one screen of the review list.
  static const rows = 6;

  /// Cached posters sampled for the placeholders.
  static const posterPool = 40;

  /// How much of a poster shows through: dim enough to read as loading.
  static const posterOpacity = 0.7;

  @override
  ConsumerState<_Progress> createState() => _ProgressState();
}

/// What one placeholder shows: a palette tone, with a decoded poster over
/// it once one has loaded.
@immutable
class _Face {
  const _Face(this.tone, [this.url, this.image]);
  final int tone;
  final String? url;
  final ImageProvider? image;
}

class _ProgressState extends ConsumerState<_Progress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  final _random = Random();

  /// Grid tiles, slots 0 to 5; they start as a fixed, varied arrangement.
  final _tiles = [
    for (var i = 0; i < _PosterTiles.count; i++)
      _Face((i * 2 + i ~/ _PosterTiles.columns) % _PosterTiles.palette.length),
  ];

  /// Row thumbnails, slots 6 to 11; their fallback is the plain card tone.
  final _thumbs = [for (var i = 0; i < _Progress.rows; i++) const _Face(0)];

  /// Cached poster URLs to deal from; empty while too few are cached.
  List<String> _pool = const [];
  final _failed = <String>{};

  /// Posters being decoded, by slot. They count as shown, so no poster is
  /// dealt twice.
  final _incoming = <int, String>{};
  Timer? _tileTimer;
  Timer? _thumbTimer;
  bool _still = true;

  @override
  void initState() {
    super.initState();
    _loadPosters();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
    _syncTimers();
  }

  @override
  void dispose() {
    _tileTimer?.cancel();
    _thumbTimer?.cancel();
    _tileTimer = _thumbTimer = null;
    _shimmer.dispose();
    super.dispose();
  }

  Future<void> _loadPosters() async {
    final showAdult = ref.read(currentSettingsProvider).showAdult;
    final List<String> urls;
    try {
      urls = await ref
          .read(catalogRepositoryProvider)
          .randomPosters(limit: _Progress.posterPool, showAdult: showAdult);
    } catch (_) {
      return; // Decoration only: the tones carry on.
    }
    if (!mounted || urls.length < _PosterTiles.count) return;
    _pool = urls;
    const tiles = _PosterTiles.count;
    // Grid first; the rows take the next ones, repeating the grid's only
    // when fewer than twelve are cached.
    for (var i = 0; i < tiles + _Progress.rows; i++) {
      _load(i, urls[i % urls.length]);
    }
    _syncTimers();
  }

  void _syncTimers() {
    if (_still) {
      _tileTimer?.cancel();
      _thumbTimer?.cancel();
      _tileTimer = _thumbTimer = null;
      return;
    }
    _tileTimer ??= _schedule(_tickTile);
    if (_pool.isNotEmpty) _thumbTimer ??= _schedule(_tickThumb);
  }

  Timer _schedule(void Function() tick) {
    final span = _PosterTiles.maxGap - _PosterTiles.minGap;
    final gap =
        _PosterTiles.minGap +
        Duration(milliseconds: _random.nextInt(span.inMilliseconds + 1));
    return Timer(gap, tick);
  }

  /// One random tile changes: a tone shifts at once, and a poster not on
  /// screen replaces it as soon as it is decoded.
  void _tickTile() {
    if (!mounted || _still) return;
    final slot = _random.nextInt(_PosterTiles.count);
    final face = _tiles[slot];
    if (face.image == null) {
      // Any tone but the current one, so every tick visibly changes.
      final shift = 1 + _random.nextInt(_PosterTiles.palette.length - 1);
      setState(
        () => _tiles[slot] = _Face(
          (face.tone + shift) % _PosterTiles.palette.length,
        ),
      );
    }
    _replace(slot);
    _tileTimer = _schedule(_tickTile);
  }

  /// One random row thumbnail changes to a poster not on screen.
  void _tickThumb() {
    if (!mounted || _still) return;
    _replace(_PosterTiles.count + _random.nextInt(_Progress.rows));
    _thumbTimer = _schedule(_tickThumb);
  }

  void _replace(int slot) {
    if (_pool.isEmpty || _incoming.containsKey(slot)) return;
    final url = _fresh(slot);
    if (url != null) _load(slot, url);
  }

  /// A poster on no placeholder at all; failing that, one not in the same
  /// group (grid or rows), so a small cache still keeps changing.
  String? _fresh(int slot) {
    const tiles = _PosterTiles.count;
    Set<String> shown(List<_Face> faces, bool Function(int) inGroup) => {
      for (final f in faces)
        if (f.url != null) f.url!,
      for (final e in _incoming.entries)
        if (inGroup(e.key)) e.value,
    };
    final inGrid = shown(_tiles, (s) => s < tiles);
    final inRows = shown(_thumbs, (s) => s >= tiles);
    List<String> besides(Set<String> avoid) => [
      for (final u in _pool)
        if (!_failed.contains(u) && !avoid.contains(u)) u,
    ];
    var options = besides({...inGrid, ...inRows});
    if (options.isEmpty) options = besides(slot < tiles ? inGrid : inRows);
    return options.isEmpty ? null : options[_random.nextInt(options.length)];
  }

  /// Decodes [url] off screen, then shows it in [slot]: a placeholder
  /// never waits on, or flashes empty for, a poster.
  void _load(int slot, String url) {
    final image = ref.read(posterImagesProvider)(url);
    _incoming[slot] = url;
    var ok = true;
    precacheImage(image, context, onError: (_, _) => ok = false).then((_) {
      if (!mounted || _incoming[slot] != url) return;
      _incoming.remove(slot);
      if (!ok) {
        _failed.add(url);
        return;
      }
      setState(() {
        const tiles = _PosterTiles.count;
        if (slot < tiles) {
          _tiles[slot] = _Face(_tiles[slot].tone, url, image);
        } else {
          final i = slot - tiles;
          _thumbs[i] = _Face(_thumbs[i].tone, url, image);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final placeholders = _SkeletonRows(thumbs: _thumbs, still: still);
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
          child: _PosterTiles(faces: _tiles, still: still),
        ),
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
/// a tick box. The poster block shows a cached poster when there is one.
class _SkeletonRows extends StatelessWidget {
  const _SkeletonRows({required this.thumbs, required this.still});
  final List<_Face> thumbs;
  final bool still;

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
        for (var i = 0; i < thumbs.length; i++)
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
                SizedBox(
                  width: 40,
                  height: 56,
                  child: _PlaceholderFace(
                    key: ValueKey('import-thumb-$i'),
                    face: thumbs[i],
                    color: _PosterTiles.palette[thumbs[i].tone],
                    radius: CueSpace.xs + 2,
                    still: still,
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

/// A 3 x 2 wall of poster-shaped tiles. Every 0.7 to 1 s one random tile
/// cross-fades to another cached poster, or to another muted tone when
/// none are cached, so the screen keeps visibly working.
class _PosterTiles extends StatelessWidget {
  const _PosterTiles({required this.faces, required this.still});
  final List<_Face> faces;
  final bool still;

  static const columns = 3;
  static const count = 6;

  /// Cross-fade length for one tile or thumbnail.
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
  Widget build(BuildContext context) {
    const rows = count ~/ columns;
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
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) const SizedBox(width: CueSpace.sm),
                    Expanded(child: _tile(r * columns + c)),
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
    child: _PlaceholderFace(
      key: ValueKey('import-tile-$i'),
      face: faces[i],
      color: palette[faces[i].tone],
      // Same rounding as the poster tiles in the taste quickstart.
      radius: CueRadius.chip,
      still: still,
    ),
  );
}

/// One placeholder: its tone, or its poster dimmed over the background.
/// A tone change blends colours; a poster change cross-fades. Still with
/// reduced motion.
class _PlaceholderFace extends StatelessWidget {
  const _PlaceholderFace({
    super.key,
    required this.face,
    required this.color,
    required this.radius,
    required this.still,
  });

  final _Face face;
  final Color color;
  final double radius;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final duration = still ? Duration.zero : _PosterTiles.fade;
    final shape = BorderRadius.circular(radius);
    final fill = AnimatedContainer(
      duration: duration,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(color: color, borderRadius: shape),
    );
    final image = face.image;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: image == null
          // One key for every tone, so tone to tone blends in place.
          ? KeyedSubtree(key: const ValueKey('tone'), child: fill)
          : ClipRRect(
              key: ValueKey(face.url),
              borderRadius: shape,
              child: Image(
                image: image,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.5),
                gaplessPlayback: true,
                excludeFromSemantics: true,
                opacity: const AlwaysStoppedAnimation(_Progress.posterOpacity),
                // Already decoded, but never blank if it is not.
                frameBuilder: (context, child, frame, sync) =>
                    sync || frame != null ? child : fill,
                errorBuilder: (_, _, _) => fill,
              ),
            ),
    );
  }
}
