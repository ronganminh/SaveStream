import 'package:flutter/material.dart';

import '../core/config/app_config.dart';

class SaveStreamApp extends StatelessWidget {
  const SaveStreamApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SaveStream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: _BootstrapScreen(config: config),
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen({required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox.square(
                  dimension: 96,
                  child: CustomPaint(painter: _SaveStreamMarkPainter()),
                ),
                const SizedBox(height: 24),
                Text('SaveStream', style: textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Flutter mobile foundation is ready.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      config.environment.label,
                      style: textTheme.labelMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveStreamMarkPainter extends CustomPainter {
  const _SaveStreamMarkPainter();

  static const double _sourceSize = 132;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / _sourceSize;
    canvas.save();
    canvas.scale(scale, scale);

    final Paint backgroundPaint = Paint()..color = const Color(0xFF4F46E5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, _sourceSize, _sourceSize),
        const Radius.circular(30),
      ),
      backgroundPaint,
    );

    final Path streamPath = Path()
      ..moveTo(86.24, 43.92)
      ..cubicTo(77.04, 33.8, 55.88, 32.88, 46.68, 45.76)
      ..cubicTo(38.4, 57.72, 50.36, 65.08, 66, 68.76)
      ..cubicTo(82.56, 73.36, 91.76, 81.64, 83.48, 92.68)
      ..cubicTo(74.28, 104.64, 53.12, 101.88, 43, 90.84);

    final Paint streamPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(streamPath, streamPaint);

    final Paint dotPaint = Paint()..color = const Color(0xFFC4B5FD);
    canvas.drawCircle(const Offset(86.24, 83.48), 6.44, dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SaveStreamMarkPainter oldDelegate) => false;
}
