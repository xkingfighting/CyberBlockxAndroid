import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../ui/theme/cyber_theme.dart';

/// Full-screen overlay for the 3-2-1-GO countdown before a challenge match.
///
/// Shows large numbers (3, 2, 1) or "GO!" with cyberpunk neon glow
/// and scale animation. The countdown value is driven by
/// ChallengeOrchestrator.countdownSeconds.
class MatchCountdownOverlay extends StatefulWidget {
  /// Countdown seconds remaining (3.0 -> 0.0). When <= 0, shows "GO!".
  final double countdownSeconds;

  const MatchCountdownOverlay({
    super.key,
    required this.countdownSeconds,
  });

  @override
  State<MatchCountdownOverlay> createState() => _MatchCountdownOverlayState();
}

class _MatchCountdownOverlayState extends State<MatchCountdownOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _lastDisplayNumber = 4; // Track which number we're showing to detect changes

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant MatchCountdownOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentNumber = _currentDisplayNumber;
    if (currentNumber != _lastDisplayNumber) {
      _lastDisplayNumber = currentNumber;
      _animController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  int get _currentDisplayNumber {
    if (widget.countdownSeconds <= 0) return 0; // "GO!"
    return widget.countdownSeconds.ceil().clamp(1, 3);
  }

  @override
  Widget build(BuildContext context) {
    final displayNumber = _currentDisplayNumber;
    final isGo = displayNumber == 0;
    final displayText = isGo ? 'GO!' : '$displayNumber';
    final glowColor = isGo ? CyberColors.green : CyberColors.cyan;

    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            // Scale: starts large, settles to 1.0
            final scaleValue = Curves.elasticOut.transform(
              _animController.value.clamp(0.0, 1.0),
            );
            final scale = 0.3 + (scaleValue * 0.7);

            // Opacity: fade in quickly, hold
            final opacity = Curves.easeOut
                .transform((_animController.value * 2).clamp(0.0, 1.0));

            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: _CountdownText(
                  text: displayText,
                  glowColor: glowColor,
                  isGo: isGo,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The large countdown number or "GO!" text with neon glow effect.
class _CountdownText extends StatelessWidget {
  final String text;
  final Color glowColor;
  final bool isGo;

  const _CountdownText({
    required this.text,
    required this.glowColor,
    required this.isGo,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow layer (large blur)
        Text(
          text,
          style: TextStyle(
            fontSize: isGo ? 72 : 96,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            color: glowColor.withValues(alpha: 0.3),
            shadows: [
              Shadow(
                color: glowColor.withValues(alpha: 0.5),
                blurRadius: 40,
              ),
              Shadow(
                color: glowColor.withValues(alpha: 0.3),
                blurRadius: 80,
              ),
            ],
          ),
        ),
        // Inner glow layer (tighter)
        Text(
          text,
          style: TextStyle(
            fontSize: isGo ? 72 : 96,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            color: glowColor.withValues(alpha: 0.6),
            shadows: [
              Shadow(
                color: glowColor.withValues(alpha: 0.8),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        // Main text (white core for neon look)
        Text(
          text,
          style: TextStyle(
            fontSize: isGo ? 72 : 96,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            color: Colors.white,
            shadows: [
              Shadow(
                color: glowColor,
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
