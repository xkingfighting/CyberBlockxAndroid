import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/localization_service.dart';
import '../../../ui/theme/cyber_theme.dart';
import '../../models/challenge_result.dart';

/// Challenge result overlay - shows win/lose/draw with score comparison.
class ChallengeResultOverlay extends StatefulWidget {
  final ChallengeResult result;
  final VoidCallback onRematch;
  final VoidCallback onMenu;

  const ChallengeResultOverlay({
    super.key,
    required this.result,
    required this.onRematch,
    required this.onMenu,
  });

  @override
  State<ChallengeResultOverlay> createState() => _ChallengeResultOverlayState();
}

class _ChallengeResultOverlayState extends State<ChallengeResultOverlay>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Color get _outcomeColor {
    switch (widget.result.outcome) {
      case MatchOutcome.win:
        return CyberColors.cyan;
      case MatchOutcome.lose:
        return CyberColors.red;
      case MatchOutcome.draw:
        return CyberColors.yellow;
    }
  }

  String get _outcomeText {
    switch (widget.result.outcome) {
      case MatchOutcome.win:
        return L.victory.tr;
      case MatchOutcome.lose:
        return L.defeat.tr;
      case MatchOutcome.draw:
        return L.draw.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Outcome text
                  AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      return Text(
                        _outcomeText,
                        style: CyberTextStyles.title.copyWith(
                          color: _outcomeColor,
                          fontSize: 48,
                          shadows: [
                            Shadow(
                              color: _outcomeColor.withValues(alpha: 0.5 + _glowController.value * 0.5),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Score comparison
                  _buildScoreComparison(),
                  const SizedBox(height: 24),

                  // Stats grid
                  _buildStatsGrid(),
                  const SizedBox(height: 16),

                  // Reward (if won)
                  if (widget.result.reward > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: CyberColors.cyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CyberColors.cyan.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events, color: CyberColors.yellow, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            '+${widget.result.reward} CBX',
                            style: CyberTextStyles.heading.copyWith(color: CyberColors.cyan),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Duration
                  Text(
                    'MATCH: ${_formatDuration(widget.result.matchDuration)}',
                    style: CyberTextStyles.body.copyWith(color: CyberColors.textMuted),
                  ),
                  const SizedBox(height: 32),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildButton(L.playAgain.tr, CyberColors.cyan, widget.onRematch),
                      const SizedBox(width: 16),
                      _buildButton(L.mainMenu.tr, CyberColors.textSecondary, widget.onMenu),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreComparison() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Player score
        Column(
          children: [
            Text('YOU', style: CyberTextStyles.body.copyWith(color: CyberColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              '${widget.result.playerScore}',
              style: CyberTextStyles.score.copyWith(
                color: CyberColors.textPrimary,
                fontSize: 36,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'VS',
            style: CyberTextStyles.heading.copyWith(color: CyberColors.textMuted),
          ),
        ),
        // Opponent score
        Column(
          children: [
            Text(
              widget.result.opponentName,
              style: CyberTextStyles.body.copyWith(color: CyberColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.result.opponentScore}',
              style: CyberTextStyles.score.copyWith(
                color: CyberColors.textSecondary,
                fontSize: 36,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStat(L.level.tr.toUpperCase(), '${widget.result.playerLevel}', '${widget.result.opponentLevel}'),
        const SizedBox(width: 32),
        _buildStat(L.lines.tr.toUpperCase(), '${widget.result.playerLines}', '${widget.result.opponentLines}'),
      ],
    );
  }

  Widget _buildStat(String label, String player, String opponent) {
    return Column(
      children: [
        Text(label, style: CyberTextStyles.body.copyWith(color: CyberColors.textMuted, fontSize: 10)),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(player, style: CyberTextStyles.body.copyWith(color: CyberColors.textPrimary)),
            Text(' / ', style: CyberTextStyles.body.copyWith(color: CyberColors.textMuted)),
            Text(opponent, style: CyberTextStyles.body.copyWith(color: CyberColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 140,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.6)),
            ),
            alignment: Alignment.center,
            child: Text(
              text,
              style: CyberTextStyles.button.copyWith(color: color, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}
