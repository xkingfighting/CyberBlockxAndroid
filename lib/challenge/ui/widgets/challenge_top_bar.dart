import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/localization_service.dart';
import '../../../ui/theme/cyber_theme.dart';
import '../../core/challenge_orchestrator.dart';
import '../../models/match_state.dart';

/// Top bar for challenge mode displaying match timer, mode label, prize pool,
/// and opponent info. Rebuilds via ListenableBuilder on orchestrator changes.
class ChallengeTopBar extends StatelessWidget {
  final ChallengeOrchestrator orchestrator;

  const ChallengeTopBar({super.key, required this.orchestrator});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: orchestrator,
      builder: (context, _) {
        final remaining = orchestrator.remainingSeconds;
        final opponent = orchestrator.opponentMatchState;
        final modeLabel = _formatModeLabel(orchestrator.config.modeType);
        final prizePool = orchestrator.config.prizePool;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    const Color(0xFF08081A).withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  // Left: Match timer
                  _TimerDisplay(remainingSeconds: remaining),

                  const SizedBox(width: 8),

                  // Center: Mode label + prize pool
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          modeLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: CyberColors.cyan,
                            letterSpacing: 2,
                          ),
                        ),
                        if (prizePool > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.card_giftcard,
                                size: 10,
                                color: CyberColors.yellow.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$prizePool CBX',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: CyberColors.yellow.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Right: Opponent display name + BOT tag + avatar
                  _OpponentTag(opponent: opponent),
                ],
              ),
            ),
            // Bottom neon line — purple → cyan → purple gradient
            Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CyberColors.purple.withValues(alpha: 0.6),
                    CyberColors.cyan.withValues(alpha: 0.8),
                    CyberColors.purple.withValues(alpha: 0.6),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: CyberColors.cyan.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatModeLabel(String modeType) {
    switch (modeType) {
      case 'score_race':
        return L.scoreRace.tr;
      case 'survival':
        return L.survival.tr;
      default:
        return modeType.toUpperCase().replaceAll('_', ' ');
    }
  }
}

/// Countdown timer with pulse animation when time is low.
class _TimerDisplay extends StatefulWidget {
  final double remainingSeconds;

  const _TimerDisplay({required this.remainingSeconds});

  @override
  State<_TimerDisplay> createState() => _TimerDisplayState();
}

class _TimerDisplayState extends State<_TimerDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant _TimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isLow = widget.remainingSeconds < 30 &&
        widget.remainingSeconds != double.infinity;
    if (isLow && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isLow && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.remainingSeconds;
    final isInfinite = remaining == double.infinity;
    final displayTime = isInfinite ? '--:--' : _formatTime(remaining);
    final isLow = remaining < 30 && !isInfinite;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final opacity = isLow ? _pulseAnimation.value.clamp(0.4, 1.0) : 1.0;
        final color = isLow ? CyberColors.red : CyberColors.cyan;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color.withValues(alpha: 0.4 * opacity),
              width: 1,
            ),
            boxShadow: isLow
                ? [
                    BoxShadow(
                      color: CyberColors.red.withValues(alpha: 0.3 * opacity),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 12,
                color: color.withValues(alpha: opacity),
              ),
              const SizedBox(width: 3),
              Text(
                displayTime,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: color.withValues(alpha: opacity),
                  shadows: isLow
                      ? [
                          Shadow(
                            color: CyberColors.red.withValues(alpha: 0.5 * opacity),
                            blurRadius: 8,
                          ),
                        ]
                      : [
                          Shadow(
                            color: CyberColors.cyan.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(double seconds) {
    final totalSeconds = math.max(0, seconds.ceil());
    final minutes = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

/// Opponent name with optional BOT tag.
class _OpponentTag extends StatelessWidget {
  final PlayerMatchState opponent;

  const _OpponentTag({required this.opponent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(
                opponent.displayName,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            if (opponent.isBot)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: CyberColors.purple.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'BOT',
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: Colors.black,
                    letterSpacing: 1,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 6),
        // Opponent avatar circle
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A1A2E),
            border: Border.all(
              color: CyberColors.purple.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Icon(
            opponent.isBot ? Icons.smart_toy : Icons.person,
            size: 12,
            color: CyberColors.purple.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
