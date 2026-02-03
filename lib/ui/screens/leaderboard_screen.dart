import 'package:flutter/material.dart';
import '../../services/leaderboard_service.dart';
import '../../services/localization_service.dart';
import '../theme/cyber_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  final VoidCallback onClose;

  const LeaderboardScreen({super.key, required this.onClose});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _animateRows = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Trigger row animations after a short delay (like iOS)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _animateRows = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title and close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: CyberColors.yellow,
                            size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        L.leaderboard.tr,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: CyberColors.yellow,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Table header
              _buildTableHeader(),
              const SizedBox(height: 8),

              // Leaderboard entries
              Expanded(
                child: ListenableBuilder(
                  listenable: LeaderboardService.instance,
                  builder: (context, _) {
                    final entries = LeaderboardService.instance.entries;

                    if (entries.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        return _AnimatedLeaderboardRow(
                          index: index,
                          entry: entries[index],
                          animate: _animateRows,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CyberColors.cyan.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CyberColors.cyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '#',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: CyberColors.cyan.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              L.playerName.tr.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: CyberColors.cyan.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              L.score.tr.toUpperCase(),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: CyberColors.cyan.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              L.level.tr.toUpperCase(),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: CyberColors.cyan.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              L.lines.tr.toUpperCase(),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: CyberColors.cyan.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: CyberColors.yellow.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            L.noRecords.tr,
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'monospace',
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            L.playToRecord.tr,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated leaderboard row that slides in from left with staggered delay
class _AnimatedLeaderboardRow extends StatefulWidget {
  final int index;
  final LeaderboardEntry entry;
  final bool animate;

  const _AnimatedLeaderboardRow({
    required this.index,
    required this.entry,
    required this.animate,
  });

  @override
  State<_AnimatedLeaderboardRow> createState() => _AnimatedLeaderboardRowState();
}

class _AnimatedLeaderboardRowState extends State<_AnimatedLeaderboardRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Calculate staggered delay based on index (50ms per row, like iOS)
    final delay = Duration(milliseconds: widget.index * 50);

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: -50, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Start animation with staggered delay if animate is true
    if (widget.animate) {
      Future.delayed(delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void didUpdateWidget(_AnimatedLeaderboardRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If animate changed to true, start the animation
    if (widget.animate && !oldWidget.animate) {
      final delay = Duration(milliseconds: widget.index * 50);
      Future.delayed(delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rank = widget.index + 1;
    Color rankColor;
    IconData? rankIcon;

    switch (rank) {
      case 1:
        rankColor = CyberColors.yellow;
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = Colors.grey.shade300;
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = CyberColors.orange;
        rankIcon = Icons.emoji_events;
        break;
      default:
        rankColor = Colors.white.withOpacity(0.7);
        rankIcon = null;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value, 0),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: rank <= 3
                    ? rankColor.withOpacity(0.1)
                    : Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: rank <= 3
                      ? rankColor.withOpacity(0.4)
                      : CyberColors.cyan.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: rankIcon != null
                        ? Icon(rankIcon, color: rankColor, size: 20)
                        : Text(
                            '$rank',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: rankColor,
                            ),
                          ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      widget.entry.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                        fontFamily: 'monospace',
                        color: rank <= 3 ? rankColor : Colors.white.withOpacity(0.9),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatScore(widget.entry.score),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: rank == 1 ? CyberColors.yellow : CyberColors.cyan,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${widget.entry.level}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        color: CyberColors.green,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${widget.entry.lines}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        color: CyberColors.purple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatScore(int score) {
    if (score >= 1000000) {
      return '${(score / 1000000).toStringAsFixed(1)}M';
    } else if (score >= 1000) {
      return '${(score / 1000).toStringAsFixed(1)}K';
    }
    return score.toString();
  }
}
