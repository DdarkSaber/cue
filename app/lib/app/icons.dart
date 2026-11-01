import 'package:flutter/widgets.dart';

/// Stroke icons ported from the design prototype.
/// Each is SVG path data on a 24x24 grid, drawn with a 1.6 round stroke.
enum CueIcons {
  tune('M4 7h7m5 0h4M4 17h3m5 0h8M11 4v6M7 14v6'),
  save('M6 4h12v17l-6-4-6 4z'),
  close('m6 6 12 12M6 18 18 6'),
  check('m5 12 4 4L19 6'),
  repeat('M4 9a7 7 0 0 1 12-4l3 3m0-5v5h-5M20 15a7 7 0 0 1-12 4l-3-3m0 5v-5h5'),
  cue('M17 5a8 8 0 1 0 0 14M12 8l7 4-7 4z'),
  undo('M4 10h10a6 6 0 1 1-4 11M4 10l5-5m-5 5 5 5'),
  info('M12 3a9 9 0 1 0 0.001 0zM12 11v6m0-10v1'),
  more(
    'M6 11a1 1 0 1 0 0.001 0zM12 11a1 1 0 1 0 0.001 0zM18 11a1 1 0 1 0 0.001 0z',
  ),
  arrow('M5 12h14m-5-5 5 5-5 5'),
  back('M19 12H5m5-5-5 5 5 5'),
  down('M12 5v14m-5-5 5 5 5-5'),
  up('M12 19V5m-5 5 5-5 5 5'),
  library('M4 4h4v16H4zm7 0h4v16h-4zm7 1 4 14'),
  settings(
    'm9 3-1 3-3 1-2 4 2 2v4l4 2 3-1 3 1 4-2v-4l2-2-2-4-3-1-1-3z'
    'M15 12a3 3 0 1 0-6 0 3 3 0 1 0 6 0z',
  ),
  shield('m12 3 8 3v6c0 4-5 8-8 9-3-1-8-5-8-9V6zm-4 9 3 3 5-6');

  const CueIcons(this.data);
  final String data;
}

class CueIcon extends StatelessWidget {
  const CueIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 1.6,
  });

  final CueIcons icon;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? const Color(0xFFFFFFFF);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _IconPainter(svgPath(icon.data), c, strokeWidth),
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.path, this.color, this.strokeWidth);

  final Path path;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || old.path != path;
}

final _pathCache = <String, Path>{};
final _token = RegExp(r'[MmLlHhVvCcAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?');

/// Parses the subset of SVG path syntax the icon set uses.
Path svgPath(String data) => _pathCache.putIfAbsent(data, () {
  final unsupported = RegExp(r'[^MmLlHhVvCcAaZz\d\s,.\-e]').firstMatch(data);
  if (unsupported != null) {
    throw FormatException('Unsupported SVG command ${unsupported.group(0)}');
  }
  final tokens = _token.allMatches(data).map((m) => m.group(0)!).toList();
  final path = Path();
  var i = 0;
  var cmd = 'M';
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;

  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double next() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'M':
        final nx = next(), ny = next();
        x = rel ? x + nx : nx;
        y = rel ? y + ny : ny;
        path.moveTo(x, y);
        startX = x;
        startY = y;
        // Subsequent pairs after a move are implicit line-tos.
        cmd = rel ? 'l' : 'L';
      case 'L':
        final nx = next(), ny = next();
        x = rel ? x + nx : nx;
        y = rel ? y + ny : ny;
        path.lineTo(x, y);
      case 'H':
        final nx = next();
        x = rel ? x + nx : nx;
        path.lineTo(x, y);
      case 'V':
        final ny = next();
        y = rel ? y + ny : ny;
        path.lineTo(x, y);
      case 'C':
        final v = List.generate(6, (_) => next());
        final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
        path.cubicTo(
          ox + v[0],
          oy + v[1],
          ox + v[2],
          oy + v[3],
          ox + v[4],
          oy + v[5],
        );
        x = ox + v[4];
        y = oy + v[5];
      case 'A':
        final rx = next(), ry = next(), rot = next();
        final large = next() != 0, sweep = next() != 0;
        final nx = next(), ny = next();
        x = rel ? x + nx : nx;
        y = rel ? y + ny : ny;
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rot,
          largeArc: large,
          clockwise: sweep,
        );
      case 'Z':
        path.close();
        x = startX;
        y = startY;
      default:
        throw FormatException('Unsupported SVG command $cmd');
    }
  }
  return path;
});
