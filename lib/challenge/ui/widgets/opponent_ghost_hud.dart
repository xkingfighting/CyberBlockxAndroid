import 'package:flutter/material.dart';
import '../../../services/localization_service.dart';
import '../../../ui/theme/cyber_theme.dart';
import '../../models/match_state.dart';

/// Base opacity for all ghost HUD elements.
const _ghostBaseOpacity = 0.6;

/// Dreamy blue-purple fantasy palette for opponent ghost HUD.
const _ghostAccentLight = Color(0xFFB49FFF); // light lavender
const _ghostAccentMid = Color(0xFF8B6FE8);   // mid blue-violet
const _ghostAccentDeep = Color(0xFF6B4FD6);   // deep blue-violet

/// Simplified right-side HUD showing opponent stats during challenge mode.
/// Uses per-stat accent colors with a ghostly reduced-opacity feel.
class OpponentGhostHUD extends StatelessWidget {
  final PlayerMatchState opponent;

  const OpponentGhostHUD({super.key, required this.opponent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Padding(
        padding: const EdgeInsets.only(right: 2, top: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Alive/Dead status indicator
            _StatusIndicator(isAlive: opponent.isAlive),
            const SizedBox(height: 10),

            // Score (light lavender, large)
            _GhostStatCard(
              label: L.score.tr.toUpperCase(),
              value: _formatNumber(opponent.score),
              icon: Icons.star,
              color: _ghostAccentLight,
              isLarge: true,
            ),
            const SizedBox(height: 8),

            // Level (mid blue-violet)
            _GhostStatCard(
              label: L.level.tr.toUpperCase(),
              value: '${opponent.level}',
              icon: Icons.bolt,
              color: _ghostAccentMid,
            ),
            const SizedBox(height: 8),

            // Lines (deep blue-violet)
            _GhostStatCard(
              label: L.lines.tr.toUpperCase(),
              value: '${opponent.lines}',
              icon: Icons.view_headline,
              color: _ghostAccentDeep,
            ),

            // Combo (if active)
            if (opponent.combo > 1) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 12,
                    color: _ghostAccentLight.withValues(alpha: _ghostBaseOpacity),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '\u{00D7}${opponent.combo}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: _ghostAccentLight.withValues(alpha: _ghostBaseOpacity),
                    ),
                  ),
                ],
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

/// Faded opponent name label at the top.
class _GhostLabel extends StatelessWidget {
  final String text;

  const _GhostLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        text,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          color: CyberColors.cyan.withValues(alpha: _ghostBaseOpacity),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Purple BOT capsule tag.
class _BotTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: CyberColors.purple.withValues(alpha: _ghostBaseOpacity),
        borderRadius: BorderRadius.circular(6),
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
    );
  }
}

/// Small alive/dead indicator dot with label.
class _StatusIndicator extends StatelessWidget {
  final bool isAlive;

  const _StatusIndicator({required this.isAlive});

  @override
  Widget build(BuildContext context) {
    final color = isAlive ? _ghostAccentLight : CyberColors.red;
    final label = isAlive ? L.alive.tr : L.dead.tr;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.7),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 5,
              ),
            ],
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            color: color.withValues(alpha: 0.7),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

/// Ghost-styled stat card with icon, value, and label.
/// Uses per-stat accent color with double-layer icon glow.
class _GhostStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLarge;

  const _GhostStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final ghostColor = color.withValues(alpha: _ghostBaseOpacity);

    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: _ghostBaseOpacity * 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon with double-layer glow (blur behind, sharp on top)
          SizedBox(
            height: 18,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow layer (blurred)
                Icon(
                  icon,
                  size: 16,
                  color: color.withValues(alpha: _ghostBaseOpacity * 0.4),
                ),
                // Sharp layer
                Icon(
                  icon,
                  size: 14,
                  color: ghostColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),

          // Value
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isLarge ? 14 : 13,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: ghostColor,
                shadows: isLarge
                    ? [
                        Shadow(
                          color: color.withValues(alpha: _ghostBaseOpacity * 0.5),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 2),

          // Label
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: color.withValues(alpha: _ghostBaseOpacity * 0.7),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
