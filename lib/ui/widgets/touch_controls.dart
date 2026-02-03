import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iOS-matching button colors for touch controls
class _ButtonColors {
  static const cyan = Color(0xFF32D4DE);      // iOS system cyan
  static const orange = Color(0xFFFF9F0A);    // iOS system orange
  static const green = Color(0xFF30D158);     // iOS system green
  static const purple = Color(0xFFBF5AF2);    // iOS system purple
  static const pink = Color(0xFFFF2D55);      // iOS system pink
}

class TouchControls extends StatelessWidget {
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onSoftDrop;
  final VoidCallback onHardDrop;
  final VoidCallback onRotateCW;
  final VoidCallback onRotateCCW;
  final VoidCallback onHold;
  final VoidCallback onPause;
  final VoidCallback? onMoveLeftRelease;
  final VoidCallback? onMoveRightRelease;
  final VoidCallback? onSoftDropRelease;

  const TouchControls({
    super.key,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onSoftDrop,
    required this.onHardDrop,
    required this.onRotateCW,
    required this.onRotateCCW,
    required this.onHold,
    required this.onPause,
    this.onMoveLeftRelease,
    this.onMoveRightRelease,
    this.onSoftDropRelease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.92),
      child: Stack(
        children: [
          // Top glow line with enhanced cyberpunk effect (matching iOS exactly)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Main glow line - iOS: cyan(0.8) → purple(0.6) → pink(0.8)
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _ButtonColors.pink.withOpacity(0.8),  // pink left
                        _ButtonColors.purple.withOpacity(0.6), // purple center
                        _ButtonColors.cyan.withOpacity(0.8),   // cyan right
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _ButtonColors.cyan.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: _ButtonColors.pink.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
                // Secondary glow line - iOS: white(0.3) → cyan(0.2) → white(0.3)
                Transform.translate(
                  offset: const Offset(0, -1),
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.3),
                          _ButtonColors.cyan.withOpacity(0.2),
                          Colors.white.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Background watermark
          Center(
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  _ButtonColors.cyan.withOpacity(0.06),
                  _ButtonColors.purple.withOpacity(0.08),
                  _ButtonColors.pink.withOpacity(0.06),
                ],
              ).createShader(bounds),
              child: const Text(
                'C Y B E R  B L O C K X',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Main controls
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 12),
            child: Row(
              children: [
                // LEFT THUMB AREA - Movement
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Left/Right row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ThumbButton(
                            iconWidget: const Icon(Icons.chevron_left, size: 32),
                            color: _ButtonColors.cyan,
                            size: 56,
                            onPress: onMoveLeft,
                            onRelease: onMoveLeftRelease,
                            repeatable: true,
                          ),
                          const SizedBox(width: 12),
                          ThumbButton(
                            iconWidget: const Icon(Icons.chevron_right, size: 32),
                            color: _ButtonColors.cyan,
                            size: 56,
                            onPress: onMoveRight,
                            onRelease: onMoveRightRelease,
                            repeatable: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Soft drop below
                      ThumbButton(
                        iconWidget: const Icon(Icons.keyboard_arrow_down, size: 32),
                        color: _ButtonColors.cyan,
                        size: 56,
                        onPress: onSoftDrop,
                        onRelease: onSoftDropRelease,
                        repeatable: true,
                      ),
                    ],
                  ),
                ),

                // CENTER - Pause button + Watermark
                SizedBox(
                  width: 90,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Game controller style pause button
                      _PauseButton(onTap: onPause),
                      const SizedBox(height: 4),
                      // Watermark below pause button
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            _ButtonColors.cyan.withOpacity(0.4),
                            _ButtonColors.purple.withOpacity(0.4),
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'Cyber Blockx',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),

                // RIGHT THUMB AREA - Actions
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Top row: Rotate CW + Hard Drop
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ThumbButton(
                            iconWidget: CustomPaint(
                              size: const Size(22, 22),
                              painter: ArrowClockwisePainter(color: _ButtonColors.orange),
                            ),
                            color: _ButtonColors.orange,
                            size: 56,
                            onPress: onRotateCW,
                          ),
                          const SizedBox(width: 12),
                          ThumbButton(
                            iconWidget: CustomPaint(
                              size: const Size(28, 28),
                              painter: DoubleChevronDownPainter(color: _ButtonColors.green),
                            ),
                            color: _ButtonColors.green,
                            size: 56,
                            onPress: onHardDrop,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Bottom row: Rotate CCW + Hold
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ThumbButton(
                            iconWidget: CustomPaint(
                              size: const Size(22, 22),
                              painter: ArrowCounterClockwisePainter(color: _ButtonColors.orange),
                            ),
                            color: _ButtonColors.orange,
                            size: 56,
                            onPress: onRotateCCW,
                          ),
                          const SizedBox(width: 12),
                          ThumbButton(
                            iconWidget: CustomPaint(
                              size: const Size(26, 26),
                              painter: SquareOnSquarePainter(color: _ButtonColors.purple),
                            ),
                            color: _ButtonColors.purple,
                            size: 56,
                            onPress: onHold,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Game controller style pause button (capsule with two vertical bars)
class _PauseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PauseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 80,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.8),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.8),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ergonomic thumb button with iOS-style ring (no background fill)
class ThumbButton extends StatefulWidget {
  final Widget iconWidget;
  final Color color;
  final double size;
  final VoidCallback onPress;
  final VoidCallback? onRelease;
  final bool repeatable;

  const ThumbButton({
    super.key,
    required this.iconWidget,
    required this.color,
    required this.size,
    required this.onPress,
    this.onRelease,
    this.repeatable = false,
  });

  @override
  State<ThumbButton> createState() => _ThumbButtonState();
}

class _ThumbButtonState extends State<ThumbButton> {
  bool _isPressed = false;
  Timer? _repeatTimer;

  static const _initialDelay = Duration(milliseconds: 200);
  static const _repeatDelay = Duration(milliseconds: 50);

  void _handlePress() {
    if (_isPressed) return;
    setState(() => _isPressed = true);
    HapticFeedback.mediumImpact();
    widget.onPress();

    if (widget.repeatable) {
      _repeatTimer = Timer(_initialDelay, () {
        _repeatTimer = Timer.periodic(_repeatDelay, (_) {
          widget.onPress();
        });
      });
    }
  }

  void _handleRelease() {
    setState(() => _isPressed = false);
    _repeatTimer?.cancel();
    _repeatTimer = null;
    widget.onRelease?.call();
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (_) => _handlePress(),
      onPanEnd: (_) => _handleRelease(),
      onPanCancel: _handleRelease,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring only - completely transparent inside when not pressed
              if (_isPressed)
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              // Ring border (always visible) - iOS uses 0.4 opacity when not pressed
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withOpacity(_isPressed ? 0.8 : 0.4),
                    width: 2,
                  ),
                ),
              ),
              // Icon - use ColorFiltered to change icon color
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  _isPressed ? Colors.black : widget.color,
                  BlendMode.srcIn,
                ),
                child: widget.iconWidget,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for arrow.clockwise (iOS SF Symbol style)
class ArrowClockwisePainter extends CustomPainter {
  final Color color;

  ArrowClockwisePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.36;

    // Arc: gap at top, starts at ~10:30, goes clockwise to ~1:30
    const startAngle = -2.2; // ~10:30 position
    const sweepAngle = 5.1;  // ~290 degrees clockwise

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

    // Arrowhead at arc end
    final endAngle = startAngle + sweepAngle;
    final tipX = cx + r * math.cos(endAngle);
    final tipY = cy + r * math.sin(endAngle);

    // Tangent direction - rotate arrowhead LEFT ~20 degrees
    final tangent = endAngle + math.pi / 2 - 0.35;

    // Arrowhead: chevron pointing along tangent
    const arrowLen = 5.0;
    const halfSpread = 0.5; // ~30 degrees

    // Wing points extend backward from tip along tangent
    final w1x = tipX - arrowLen * math.cos(tangent - halfSpread);
    final w1y = tipY - arrowLen * math.sin(tangent - halfSpread);
    final w2x = tipX - arrowLen * math.cos(tangent + halfSpread);
    final w2y = tipY - arrowLen * math.sin(tangent + halfSpread);

    canvas.drawLine(Offset(w1x, w1y), Offset(tipX, tipY), paint);
    canvas.drawLine(Offset(tipX, tipY), Offset(w2x, w2y), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for arrow.counterclockwise (iOS SF Symbol style)
class ArrowCounterClockwisePainter extends CustomPainter {
  final Color color;

  ArrowCounterClockwisePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.36;

    // Arc: gap at top, starts at ~1:30, goes counter-clockwise to ~10:30
    const startAngle = -0.95; // ~1:30 position
    const sweepAngle = -5.1;  // ~290 degrees counter-clockwise

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

    // Arrowhead at arc end
    final endAngle = startAngle + sweepAngle;
    final tipX = cx + r * math.cos(endAngle);
    final tipY = cy + r * math.sin(endAngle);

    // Tangent direction + rotate arrowhead RIGHT ~20 degrees
    final tangent = endAngle - math.pi / 2 + 0.35;

    // Arrowhead: chevron pointing along tangent
    const arrowLen = 5.0;
    const halfSpread = 0.5; // ~30 degrees

    // Wing points extend backward from tip along tangent
    final w1x = tipX - arrowLen * math.cos(tangent - halfSpread);
    final w1y = tipY - arrowLen * math.sin(tangent - halfSpread);
    final w2x = tipX - arrowLen * math.cos(tangent + halfSpread);
    final w2y = tipY - arrowLen * math.sin(tangent + halfSpread);

    canvas.drawLine(Offset(w1x, w1y), Offset(tipX, tipY), paint);
    canvas.drawLine(Offset(tipX, tipY), Offset(w2x, w2y), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for chevron.down.2 (iOS SF Symbol style - double chevron)
class DoubleChevronDownPainter extends CustomPainter {
  final Color color;

  DoubleChevronDownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final centerX = size.width / 2;
    final chevronWidth = size.width * 0.5;

    // First chevron (top)
    final path1 = Path()
      ..moveTo(centerX - chevronWidth / 2, size.height * 0.2)
      ..lineTo(centerX, size.height * 0.45)
      ..lineTo(centerX + chevronWidth / 2, size.height * 0.2);
    canvas.drawPath(path1, paint);

    // Second chevron (bottom)
    final path2 = Path()
      ..moveTo(centerX - chevronWidth / 2, size.height * 0.5)
      ..lineTo(centerX, size.height * 0.75)
      ..lineTo(centerX + chevronWidth / 2, size.height * 0.5);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for square.on.square (iOS SF Symbol style - two overlapping squares)
class SquareOnSquarePainter extends CustomPainter {
  final Color color;

  SquareOnSquarePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final squareSize = size.width * 0.52;
    final cornerRadius = 3.0;

    // Calculate positions for overlapping effect
    final backLeft = size.width * 0.08;
    final backTop = size.height * 0.08;
    final frontLeft = size.width * 0.40;
    final frontTop = size.height * 0.40;

    // Back square (top-left) - stroke only
    final backRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(backLeft, backTop, squareSize, squareSize),
      Radius.circular(cornerRadius),
    );
    canvas.drawRRect(backRect, paint);

    // Front square (bottom-right) - stroke only, no fill
    final frontRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(frontLeft, frontTop, squareSize, squareSize),
      Radius.circular(cornerRadius),
    );
    canvas.drawRRect(frontRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
