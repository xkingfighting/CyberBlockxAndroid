import 'package:flutter/material.dart';
import '../../../core/game_state.dart';
import '../../../services/localization_service.dart';
import '../../../ui/theme/cyber_theme.dart';
import '../../../ui/widgets/game_hud.dart';

/// Challenge-specific left HUD that includes hold piece, stats, and next queue.
///
/// In solo mode, hold/next are on the RightHUD. In challenge mode, the right
/// side is replaced by OpponentGhostHUD, so we combine everything on the left.
class ChallengeLeftHUD extends StatelessWidget {
  final GameState gameState;
  final bool showNext;

  const ChallengeLeftHUD({super.key, required this.gameState, this.showNext = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Padding(
        padding: const EdgeInsets.only(left: 2, top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Hold piece (purple accent)
            SidePieceCard(
              label: L.hold.tr,
              piece: gameState.holdPiece,
              accentColor: CyberColors.purple,
            ),
            const SizedBox(height: 6),

            // Score (cyan, star icon)
            SideStatCard(
              label: L.score.tr,
              value: _formatNumber(gameState.scoring.score),
              icon: Icons.star,
              color: CyberColors.cyan,
              isLarge: true,
            ),
            const SizedBox(height: 6),

            // Level (green, bolt icon)
            SideStatCard(
              label: L.level.tr,
              value: '${gameState.scoring.level}',
              icon: Icons.bolt,
              color: CyberColors.green,
            ),
            const SizedBox(height: 6),

            // Lines (yellow, lines icon)
            SideStatCard(
              label: L.lines.tr,
              value: '${gameState.scoring.totalLines}',
              icon: Icons.menu,
              color: CyberColors.yellow,
            ),

            // Combo (only when active)
            if (gameState.scoring.combo > 1) ...[
              const SizedBox(height: 6),
              SideStatCard(
                label: L.combo.tr,
                value: '×${gameState.scoring.combo}',
                icon: Icons.local_fire_department,
                color: CyberColors.orange,
                isPulsing: true,
              ),
            ],

            // Next pieces queue (cyan) — hidden when showNext is false (solo replay moves NEXT to right side)
            if (showNext) ...[
              const SizedBox(height: 6),
              SideNextQueue(
                label: L.next.tr,
                pieces: gameState.previewQueue,
              ),
            ],

            const Spacer(),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        result.write(',');
      }
      result.write(str[i]);
    }
    return result.toString();
  }
}
