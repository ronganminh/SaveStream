import 'package:flutter/material.dart';

/// Stroke icons drawn from the same 24×24 path data as the v2 artboards, so
/// the app and the designs share one icon set without an SVG dependency.
enum SsV2IconGlyph {
  back('M15 5l-7 7 7 7'),
  chevronRight('M9 6l6 6-6 6'),
  eye(
    'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
  ),
  eyeOff(
    'M3 3l18 18M10.6 5.1A10.5 10.5 0 0 1 12 5c6 0 10 7 10 7a17 17 0 0 1-3.2 3.9M6.6 6.6C3.8 8.4 2 12 2 12s4 7 10 7c1.7 0 3.2-.5 4.5-1.2M9.9 9.9a3 3 0 0 0 4.2 4.2',
  ),
  alert('M12 8v5M12 16h.01M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z'),
  clock('M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3 2'),
  mail('M3 6h18v12H3zM3 7l9 6 9-6'),
  lock('M5 11h14v10H5zM8 11V7a4 4 0 0 1 8 0v4'),
  check('M5 12.5l4.5 4.5L19 7.5'),
  person('M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0'),
  cloud('M7 18h10a4.5 4.5 0 0 0 .5-9A6 6 0 0 0 6 9.5 4.3 4.3 0 0 0 7 18z'),
  bell('M6 9a6 6 0 0 1 12 0c0 6 2 7 2 7H4s2-1 2-7M10 20a2 2 0 0 0 4 0'),
  home('M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z'),
  channels(
    'M12 9.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5zM6.3 6.3a8 8 0 0 0 0 11.4M17.7 6.3a8 8 0 0 1 0 11.4',
  ),
  recordings(
    'M3 6a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM10 9l5 3-5 3z',
  ),
  refresh('M20 11a8 8 0 1 0-2.3 5.7M20 5v6h-6'),
  plus('M12 5v14M5 12h14'),
  close('M6 6l12 12M18 6L6 18'),
  copy('M8 8h11v11H8zM5 16V5h11'),
  shield('M12 3l8 3v6c0 4.5-3.4 8.3-8 9-4.6-.7-8-4.5-8-9V6l8-3z'),
  help(
    'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6V14M12 17h.01',
  ),
  more('M12 5h.01M12 12h.01M12 19h.01'),
  trash('M4 7h16M10 11v6M14 11v6M6 7l1 14h10l1-14M9 7V4h6v3'),
  search('M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM20 20l-3.5-3.5'),
  play('M7 4v16l13-8z'),
  download('M12 3v12M7 10l5 5 5-5M5 21h14'),
  ad(
    'M4 5h16v14H4zM9 15l2-6 2 6M9.7 13h2.6M15 9v6h1a2 2 0 0 0 2-2v-2a2 2 0 0 0-2-2z',
  ),
  chart('M4 20V10M10 20V4M16 20v-7M22 20H2');

  const SsV2IconGlyph(this.pathData);

  final String pathData;
}

class SsV2Icon extends StatelessWidget {
  const SsV2Icon(
    this.glyph, {
    this.size = 24,
    this.color,
    this.strokeWidth = 2,
    super.key,
  });

  final SsV2IconGlyph glyph;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final Color resolved =
        color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color!;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _StrokePathPainter(
          path: parseSvgPathData(glyph.pathData),
          color: resolved,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _StrokePathPainter extends CustomPainter {
  const _StrokePathPainter({
    required this.path,
    required this.color,
    required this.strokeWidth,
  });

  final Path path;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StrokePathPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.path != path;
  }
}

/// SaveStream mark: rounded purple square with the white broadcast glyph.
class SsV2LogoMark extends StatelessWidget {
  const SsV2LogoMark({this.size = 28, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(size: Size.square(size), painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  static final Path _waves = parseSvgPathData(
    'M19 10.5a8 8 0 0 1 0 11M22.5 7.5a12.5 12.5 0 0 1 0 17',
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 32, 32),
        const Radius.circular(9),
      ),
      Paint()..color = const Color(0xFF6D4AFF),
    );
    final Paint white = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(const Offset(12.5, 16), 4, white);
    canvas.drawPath(
      _waves,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}

/// Four-color Google "G" used on the Continue with Google buttons.
class SsV2GoogleMark extends StatelessWidget {
  const SsV2GoogleMark({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(size: Size.square(size), painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  static final List<(Path, Color)> _parts = <(Path, Color)>[
    (
      parseSvgPathData(
        'M21.6 12.2c0-.7-.1-1.4-.2-2H12v3.8h5.4a4.6 4.6 0 0 1-2 3v2.5h3.2c1.9-1.7 3-4.3 3-7.3z',
      ),
      const Color(0xFF4285F4),
    ),
    (
      parseSvgPathData(
        'M12 22c2.7 0 5-.9 6.6-2.5l-3.2-2.5c-.9.6-2 1-3.4 1-2.6 0-4.8-1.8-5.6-4.1H3.1v2.6A10 10 0 0 0 12 22z',
      ),
      const Color(0xFF34A853),
    ),
    (
      parseSvgPathData('M6.4 13.9a6 6 0 0 1 0-3.8V7.5H3.1a10 10 0 0 0 0 9z'),
      const Color(0xFFFBBC05),
    ),
    (
      parseSvgPathData(
        'M12 6c1.5 0 2.8.5 3.8 1.5l2.9-2.9A10 10 0 0 0 3.1 7.5l3.3 2.6C7.2 7.8 9.4 6 12 6z',
      ),
      const Color(0xFFEA4335),
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    for (final (Path path, Color color) in _parts) {
      canvas.drawPath(path, Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}

final Map<String, Path> _pathCache = <String, Path>{};

/// Parses SVG path data (M L H V C S Q T A Z, absolute and relative).
Path parseSvgPathData(String data) {
  final Path? cached = _pathCache[data];
  if (cached != null) return cached;
  final Path path = _SvgPathParser(data).parse();
  _pathCache[data] = path;
  return path;
}

class _SvgPathParser {
  _SvgPathParser(this._data);

  final String _data;
  int _i = 0;

  bool get _done => _i >= _data.length;

  void _skipSeparators() {
    while (!_done) {
      final String c = _data[_i];
      if (c == ' ' || c == ',' || c == '\n' || c == '\t' || c == '\r') {
        _i++;
      } else {
        break;
      }
    }
  }

  bool _atNumber() {
    _skipSeparators();
    if (_done) return false;
    final String c = _data[_i];
    return c == '-' || c == '+' || c == '.' || _isDigit(c);
  }

  static bool _isDigit(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  double _number() {
    _skipSeparators();
    final int start = _i;
    if (_data[_i] == '-' || _data[_i] == '+') _i++;
    bool seenDot = false;
    bool seenExp = false;
    while (!_done) {
      final String c = _data[_i];
      if (_isDigit(c)) {
        _i++;
      } else if (c == '.' && !seenDot && !seenExp) {
        seenDot = true;
        _i++;
      } else if ((c == 'e' || c == 'E') && !seenExp) {
        seenExp = true;
        _i++;
        if (!_done && (_data[_i] == '-' || _data[_i] == '+')) _i++;
      } else {
        break;
      }
    }
    return double.parse(_data.substring(start, _i));
  }

  bool _flag() {
    _skipSeparators();
    final String c = _data[_i];
    _i++;
    return c == '1';
  }

  Path parse() {
    final Path path = Path();
    double x = 0;
    double y = 0;
    double startX = 0;
    double startY = 0;
    double? lastCtrlX;
    double? lastCtrlY;
    String command = '';

    while (true) {
      _skipSeparators();
      if (_done) break;
      final String c = _data[_i];
      if (!(c == '-' || c == '+' || c == '.' || _isDigit(c))) {
        command = c;
        _i++;
      } else if (command == 'M') {
        command = 'L';
      } else if (command == 'm') {
        command = 'l';
      }
      final bool rel = command.toLowerCase() == command;
      switch (command.toUpperCase()) {
        case 'M':
          final double nx = _number() + (rel ? x : 0);
          final double ny = _number() + (rel ? y : 0);
          path.moveTo(nx, ny);
          x = startX = nx;
          y = startY = ny;
          lastCtrlX = lastCtrlY = null;
        case 'L':
          x = _number() + (rel ? x : 0);
          y = _number() + (rel ? y : 0);
          path.lineTo(x, y);
          lastCtrlX = lastCtrlY = null;
        case 'H':
          x = _number() + (rel ? x : 0);
          path.lineTo(x, y);
          lastCtrlX = lastCtrlY = null;
        case 'V':
          y = _number() + (rel ? y : 0);
          path.lineTo(x, y);
          lastCtrlX = lastCtrlY = null;
        case 'C':
          final double x1 = _number() + (rel ? x : 0);
          final double y1 = _number() + (rel ? y : 0);
          final double x2 = _number() + (rel ? x : 0);
          final double y2 = _number() + (rel ? y : 0);
          final double nx = _number() + (rel ? x : 0);
          final double ny = _number() + (rel ? y : 0);
          path.cubicTo(x1, y1, x2, y2, nx, ny);
          lastCtrlX = x2;
          lastCtrlY = y2;
          x = nx;
          y = ny;
        case 'S':
          final double x1 = lastCtrlX == null ? x : 2 * x - lastCtrlX;
          final double y1 = lastCtrlY == null ? y : 2 * y - lastCtrlY;
          final double x2 = _number() + (rel ? x : 0);
          final double y2 = _number() + (rel ? y : 0);
          final double nx = _number() + (rel ? x : 0);
          final double ny = _number() + (rel ? y : 0);
          path.cubicTo(x1, y1, x2, y2, nx, ny);
          lastCtrlX = x2;
          lastCtrlY = y2;
          x = nx;
          y = ny;
        case 'Q':
          final double x1 = _number() + (rel ? x : 0);
          final double y1 = _number() + (rel ? y : 0);
          final double nx = _number() + (rel ? x : 0);
          final double ny = _number() + (rel ? y : 0);
          path.quadraticBezierTo(x1, y1, nx, ny);
          lastCtrlX = x1;
          lastCtrlY = y1;
          x = nx;
          y = ny;
        case 'T':
          final double x1 = lastCtrlX == null ? x : 2 * x - lastCtrlX;
          final double y1 = lastCtrlY == null ? y : 2 * y - lastCtrlY;
          final double nx = _number() + (rel ? x : 0);
          final double ny = _number() + (rel ? y : 0);
          path.quadraticBezierTo(x1, y1, nx, ny);
          lastCtrlX = x1;
          lastCtrlY = y1;
          x = nx;
          y = ny;
        case 'A':
          final double rx = _number();
          final double ry = _number();
          final double rotation = _number();
          final bool largeArc = _flag();
          final bool sweep = _flag();
          final double nx = _number() + (rel ? x : 0);
          final double ny = _number() + (rel ? y : 0);
          path.arcToPoint(
            Offset(nx, ny),
            radius: Radius.elliptical(rx, ry),
            rotation: rotation,
            largeArc: largeArc,
            clockwise: sweep,
          );
          x = nx;
          y = ny;
          lastCtrlX = lastCtrlY = null;
        case 'Z':
          path.close();
          x = startX;
          y = startY;
          lastCtrlX = lastCtrlY = null;
          // A number after Z would be malformed; stop to avoid looping.
          if (_atNumber()) return path;
        default:
          return path;
      }
    }
    return path;
  }
}
