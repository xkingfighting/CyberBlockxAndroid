import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/cyber_theme.dart';

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
                        CyberColors.pink.withOpacity(0.8),  // pink left
                        CyberColors.purple.withOpacity(0.6), // purple center
                        CyberColors.cyan.withOpacity(0.8),   // cyan right
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CyberColors.cyan.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: CyberColors.pink.withOpacity(0.4),
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
                          CyberColors.cyan.withOpacity(0.2),
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
                  CyberColors.cyan.withOpacity(0.06),
                  CyberColors.purple.withOpacity(0.08),
                  CyberColors.pink.withOpacity(0.06),
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
                            icon: Icons.chevron_left,
                            color: CyberColors.cyan,
                            size: 56,
                            onPress: onMoveLeft,
                            onRelease: onMoveLeftRelease,
                            repeatable: true,
                          ),
                          const SizedBox(width: 12),
                          ThumbButton(
                            icon: Icons.chevron_right,
                            color: CyberColors.cyan,
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
                        icon: Icons.keyboard_arrow_down,
                        color: CyberColors.cyan.withOpacity(0.8),
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
                            CyberColors.cyan.withOpacity(0.4),
                            CyberColors.purple.withOpacity(0.4),
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
                            icon: Icons.redo,  // iOS: arrow.clockwise
                            color: CyberColors.orange,
                            size: 56,
                            onPress: onRotateCW,
                          ),
                          const SizedBox(width: 12),
                          ThumbButton(
                            icon: Icons.keyboard_double_arrow_down,  // iOS: chevron.down.2
                            color: CyberColors.green,
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
                            icon: Icons.undo,  // iOS: arrow.counterclockwise
                            color: CyberColors.orange.withOpacity(0.8),
                            size: 56,
                            onPress: onRotateCCW,
                          ),
                          const SizedBox(width: 12),
                          ThumbButton(
                            icon: Icons.filter_none,  // iOS: square.on.square
                            color: CyberColors.purple,
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

/// Ergonomic thumb button with iOS-style radial gradient
class ThumbButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onPress;
  final VoidCallback? onRelease;
  final bool repeatable;

  const ThumbButton({
    super.key,
    required this.icon,
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
              // Outer glow ring
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withOpacity(_isPressed ? 0.8 : 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(_isPressed ? 0.6 : 0.2),
                      blurRadius: _isPressed ? 8 : 4,
                    ),
                  ],
                ),
              ),
              // Inner fill with radial gradient
              Container(
                width: widget.size - 4,
                height: widget.size - 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _isPressed ? widget.color : widget.color.withOpacity(0.15),
                      _isPressed
                          ? widget.color.withOpacity(0.8)
                          : Colors.black.withOpacity(0.5),
                    ],
                    center: Alignment.center,
                    radius: 0.5,
                  ),
                ),
              ),
              // Icon
              Icon(
                widget.icon,
                color: _isPressed ? Colors.black : widget.color,
                size: widget.size * 0.38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
