import 'package:flutter/material.dart';
import '../../../ui/theme/cyber_theme.dart';

/// Displays 5 colored dots representing the last 5 match results.
/// Green = win, Red = lose, Yellow = draw.
class RecentFormIndicator extends StatelessWidget {
  final List<String> recentForm;

  const RecentFormIndicator({super.key, required this.recentForm});

  @override
  Widget build(BuildContext context) {
    if (recentForm.isEmpty) return const SizedBox.shrink();

    // Show up to 5 most recent, oldest first (left to right)
    final display = recentForm.length > 5
        ? recentForm.sublist(recentForm.length - 5)
        : recentForm;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < display.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _FormDot(outcome: display[i]),
        ],
      ],
    );
  }
}

class _FormDot extends StatelessWidget {
  final String outcome;

  const _FormDot({required this.outcome});

  Color get _color {
    switch (outcome) {
      case 'win':
        return CyberColors.green;
      case 'lose':
        return CyberColors.red;
      default:
        return CyberColors.yellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: 0.5),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
