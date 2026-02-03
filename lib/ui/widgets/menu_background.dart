import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/cyber_theme.dart';

/// Animated cyberpunk background for menu screen (matching iOS)
class MenuBackground extends StatefulWidget {
  final Widget child;

  const MenuBackground({super.key, required this.child});

  @override
  State<MenuBackground> createState() => _MenuBackgroundState();
}

class _MenuBackgroundState extends State<MenuBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_DataRainColumn> _dataRainColumns;
  late List<_Building> _buildings;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _dataRainColumns = [];
    _buildings = [];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initElements(Size size) {
    if (_dataRainColumns.isEmpty && size.width > 0) {
      // Initialize data rain columns
      final columnCount = (size.width / 25).floor();
      _dataRainColumns = List.generate(columnCount, (i) {
        return _DataRainColumn(
          x: i * 25.0 + 12.5,
          speed: _random.nextDouble() * 80 + 40,
          length: _random.nextInt(10) + 5,
          offset: _random.nextDouble() * size.height,
          opacity: _random.nextDouble() * 0.3 + 0.1,
        );
      });

      // Initialize buildings
      double x = 0;
      while (x < size.width) {
        final width = _random.nextDouble() * 40 + 20;
        final height = _random.nextDouble() * 120 + 40;
        _buildings.add(_Building(
          x: x,
          width: width,
          height: height,
          windows: _generateWindows(width, height),
        ));
        x += width + _random.nextDouble() * 10 + 5;
      }
    }
  }

  List<_Window> _generateWindows(double buildingWidth, double buildingHeight) {
    final windows = <_Window>[];
    final cols = (buildingWidth / 12).floor();
    final rows = (buildingHeight / 15).floor();

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (_random.nextDouble() > 0.6) {
          windows.add(_Window(
            x: col * 12.0 + 6,
            y: row * 15.0 + 8,
            color: [CyberColors.cyan, CyberColors.pink, CyberColors.yellow][
                _random.nextInt(3)],
            flickerPhase: _random.nextDouble() * pi * 2,
            flickerSpeed: _random.nextDouble() * 2 + 0.5,
            isFlickering: _random.nextDouble() > 0.7,
          ));
        }
      }
    }
    return windows;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _initElements(size);

        return Stack(
          children: [
            // Gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF050510), // Dark blue-black
                    Color(0xFF0D0520), // Dark purple
                    Color(0xFF030810), // Dark cyan-black
                  ],
                ),
              ),
            ),

            // Animated elements
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: size,
                  painter: _MenuBackgroundPainter(
                    time: DateTime.now().millisecondsSinceEpoch / 1000.0,
                    dataRainColumns: _dataRainColumns,
                    buildings: _buildings,
                  ),
                );
              },
            ),

            // Vignette overlay
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),

            // Child content
            widget.child,
          ],
        );
      },
    );
  }
}

class _DataRainColumn {
  final double x;
  final double speed;
  final int length;
  double offset;
  final double opacity;

  _DataRainColumn({
    required this.x,
    required this.speed,
    required this.length,
    required this.offset,
    required this.opacity,
  });
}

class _Building {
  final double x;
  final double width;
  final double height;
  final List<_Window> windows;

  _Building({
    required this.x,
    required this.width,
    required this.height,
    required this.windows,
  });
}

class _Window {
  final double x;
  final double y;
  final Color color;
  final double flickerPhase;
  final double flickerSpeed;
  final bool isFlickering;

  _Window({
    required this.x,
    required this.y,
    required this.color,
    required this.flickerPhase,
    required this.flickerSpeed,
    required this.isFlickering,
  });
}

class _MenuBackgroundPainter extends CustomPainter {
  final double time;
  final List<_DataRainColumn> dataRainColumns;
  final List<_Building> buildings;
  final Random _random = Random(42); // Fixed seed for consistent characters

  _MenuBackgroundPainter({
    required this.time,
    required this.dataRainColumns,
    required this.buildings,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawHolographicWaves(canvas, size);
    _drawCity(canvas, size);
    _drawDataRain(canvas, size);
  }

  void _drawHolographicWaves(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      final path = Path();
      final amplitude = 15.0 - i * 2;
      final wavelength = 80.0 + i * 15;
      final yBase = size.height * 0.7 + i * 12;
      final phase = time * (0.5 + i * 0.1);

      path.moveTo(0, yBase);
      for (double x = 0; x <= size.width; x += 3) {
        final y = yBase + amplitude * sin((x / wavelength + phase) * pi * 2);
        path.lineTo(x, y);
      }

      wavePaint.color = CyberColors.cyan.withOpacity(0.15 - i * 0.02);
      canvas.drawPath(path, wavePaint);
    }
  }

  void _drawCity(Canvas canvas, Size size) {
    final cityY = size.height * 0.75;

    for (final building in buildings) {
      // Building body
      final bodyRect = Rect.fromLTWH(
        building.x,
        cityY - building.height,
        building.width,
        building.height,
      );

      final bodyPaint = Paint()
        ..color = const Color(0xFF080818);
      canvas.drawRect(bodyRect, bodyPaint);

      // Building outline
      final outlinePaint = Paint()
        ..color = const Color(0xFF1A1A30).withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRect(bodyRect, outlinePaint);

      // Windows
      for (final window in building.windows) {
        double opacity = 0.5;
        if (window.isFlickering) {
          opacity = 0.3 + 0.4 * (0.5 + 0.5 * sin(time * window.flickerSpeed + window.flickerPhase));
        }

        final windowPaint = Paint()
          ..color = window.color.withOpacity(opacity);

        canvas.drawRect(
          Rect.fromLTWH(
            building.x + window.x - 2,
            cityY - building.height + window.y - 3,
            4,
            6,
          ),
          windowPaint,
        );
      }

      // Neon accent on some buildings
      if (building.width > 30 && _random.nextDouble() > 0.5) {
        final accentColors = [CyberColors.pink, CyberColors.cyan, CyberColors.purple];
        final accentPaint = Paint()
          ..color = accentColors[building.x.toInt() % 3].withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

        canvas.drawRect(
          Rect.fromLTWH(
            building.x + building.width * 0.1,
            cityY - building.height - 1,
            building.width * 0.8,
            2,
          ),
          accentPaint,
        );
      }
    }
  }

  void _drawDataRain(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final column in dataRainColumns) {
      // Update position based on time
      final currentOffset = (column.offset + time * column.speed) % (size.height + column.length * 15);

      for (int i = 0; i < column.length; i++) {
        final y = currentOffset - i * 15;
        if (y < -15 || y > size.height) continue;

        // Fade based on position in column
        final fade = 1.0 - (i / column.length);
        final char = _random.nextInt(2).toString(); // 0 or 1

        // Leading character is brighter
        final color = i == 0
            ? Color.fromRGBO(128, 255, 200, column.opacity * fade)
            : Color.fromRGBO(0, 200, 128, column.opacity * fade * 0.7);

        textPainter.text = TextSpan(
          text: char,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: color,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(column.x - 4, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MenuBackgroundPainter oldDelegate) => true;
}

class _ScanLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.08);

    for (double y = 0; y < size.height; y += 4) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
