import 'package:flutter/material.dart';
import '../../../services/localization_service.dart';
import '../../../ui/theme/cyber_theme.dart';
import '../../models/match_history_entry.dart';
import '../../services/match_history_service.dart';
import '../widgets/recent_form_indicator.dart';
import 'match_detail_screen.dart';

class MatchHistoryScreen extends StatefulWidget {
  final VoidCallback onClose;

  const MatchHistoryScreen({super.key, required this.onClose});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  final _scrollController = ScrollController();
  bool _animateRows = false;
  MatchHistoryEntry? _selectedDetail;

  @override
  void initState() {
    super.initState();
    MatchHistoryService.instance.refresh();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _animateRows = true);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        MatchHistoryService.instance.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show detail screen if an entry is selected
    if (_selectedDetail != null) {
      return MatchDetailScreen(
        entry: _selectedDetail!,
        onClose: () => setState(() => _selectedDetail = null),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([
        MatchHistoryService.instance,
        LocalizationService.instance,
      ]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: CyberColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildStatsStrip(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Header ───────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: CyberColors.cyan.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.arrow_back, color: CyberColors.cyan, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          L.battleLog.tr,
          style: CyberTextStyles.subtitle.copyWith(
            color: CyberColors.cyan,
            fontSize: 20,
          ),
        ),
      ],
    );
  }

  // ─── Stats Strip ──────────────────────────────────────

  Widget _buildStatsStrip() {
    final stats = MatchHistoryService.instance.stats;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: L.played.tr,
                value: '${stats?.totalMatches ?? 0}',
                accent: CyberColors.cyan,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: L.winRate.tr,
                value: stats != null ? '${(stats.winRate * 100).toInt()}%' : '0%',
                accent: (stats?.winRate ?? 0) >= 0.5
                    ? CyberColors.green
                    : CyberColors.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: L.streak.tr,
                value: '${stats?.currentStreak ?? 0}',
                accent: (stats?.currentStreak ?? 0) > 0
                    ? CyberColors.yellow
                    : CyberColors.textMuted,
              ),
            ),
          ],
        ),
        // Recent form indicator
        if (stats != null && stats.recentForm.isNotEmpty) ...[
          const SizedBox(height: 8),
          RecentFormIndicator(recentForm: stats.recentForm),
        ],
      ],
    );
  }

  // ─── Body ─────────────────────────────────────────────

  Widget _buildBody() {
    final service = MatchHistoryService.instance;

    // Loading (first time)
    if (service.isLoading && !service.hasData) {
      return Center(
        child: CircularProgressIndicator(color: CyberColors.cyan),
      );
    }

    // Error
    if (service.error != null && !service.hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: CyberColors.red.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              L.connectionLost.tr,
              style: CyberTextStyles.subtitle.copyWith(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              L.connectionLostDesc.tr,
              style: CyberTextStyles.body.copyWith(color: CyberColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _RetryButton(onTap: () => service.refresh()),
          ],
        ),
      );
    }

    // Empty
    if (!service.hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal, size: 48, color: CyberColors.cyan.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              L.noRecordsBattleLog.tr,
              style: CyberTextStyles.subtitle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              L.noRecordsBattleLogDesc.tr,
              textAlign: TextAlign.center,
              style: CyberTextStyles.body.copyWith(
                color: CyberColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // List
    return RefreshIndicator(
      color: CyberColors.cyan,
      backgroundColor: CyberColors.surface,
      onRefresh: () => service.refresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: service.entries.length + (service.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= service.entries.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  color: CyberColors.cyan,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          final entry = service.entries[index];
          return _AnimatedRow(
            index: index,
            animate: _animateRows,
            child: GestureDetector(
              onTap: () => setState(() => _selectedDetail = entry),
              child: _MatchRow(entry: entry),
            ),
          );
        },
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: CyberColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: CyberTextStyles.subtitle.copyWith(
              color: accent,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: CyberTextStyles.body.copyWith(
              color: CyberColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Match Row ────────────────────────────────────────

class _MatchRow extends StatelessWidget {
  final MatchHistoryEntry entry;

  const _MatchRow({required this.entry});

  String? _localizedDifficulty(String? diff) {
    if (diff == null) return null;
    switch (diff) {
      case 'easy':
        return L.easy.tr;
      case 'medium':
        return L.medium.tr;
      case 'hard':
        return L.hard.tr;
      default:
        return diff;
    }
  }

  Color get _outcomeColor {
    switch (entry.outcome) {
      case 'win':
        return CyberColors.green;
      case 'lose':
        return CyberColors.red;
      default:
        return CyberColors.yellow;
    }
  }

  String get _outcomeLabel {
    switch (entry.outcome) {
      case 'win':
        return L.won.tr;
      case 'lose':
        return L.lost.tr;
      default:
        return L.drew.tr;
    }
  }

  String get _outcomeIcon {
    switch (entry.outcome) {
      case 'win':
        return '\u2713'; // ✓
      case 'lose':
        return '\u2717'; // ✗
      default:
        return '\u2014'; // —
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocalizationService.instance;
    final modeLabel = entry.modeType == 'survival'
        ? loc.tr(L.survival)
        : loc.tr(L.scoreRace);
    final opponentBadge = entry.isBot ? loc.tr(L.bot) : loc.tr(L.player);
    final diffLabel = entry.isBot ? _localizedDifficulty(entry.opponentDifficulty) : null;

    final dateStr = entry.formattedDate;
    final playerScore = _formatScore(entry.playerScore);
    final opponentScore = _formatScore(entry.opponentScore);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: CyberColors.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _outcomeColor.withValues(alpha: 0.2)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: _outcomeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top line: outcome + mode + opponent type
                    Row(
                      children: [
                        // Outcome badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _outcomeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$_outcomeIcon $_outcomeLabel',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _outcomeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Mode chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: CyberColors.surface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            modeLabel,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: entry.modeType == 'survival'
                                  ? CyberColors.purple
                                  : CyberColors.cyan,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Opponent type badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: entry.isBot
                                ? CyberColors.purple.withValues(alpha: 0.15)
                                : CyberColors.cyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            opponentBadge,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: entry.isBot ? CyberColors.purple : CyberColors.cyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Middle line: opponent name + difficulty
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: entry.opponentName,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (diffLabel != null)
                            TextSpan(
                              text: ' ($diffLabel)',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: CyberColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Bottom line: scores + duration + date
                    Row(
                      children: [
                        Text(
                          playerScore,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          ' ${L.vs.tr} ',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: CyberColors.textMuted,
                          ),
                        ),
                        Text(
                          opponentScore,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: CyberColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.formattedDuration,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: CyberColors.textMuted,
                          ),
                        ),
                        const Spacer(),
                        // Chevron hint
                        Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: CyberColors.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: CyberColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatScore(int score) {
    if (score < 1000) return '$score';
    final s = score.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ─── Animated Row ─────────────────────────────────────

class _AnimatedRow extends StatefulWidget {
  final int index;
  final bool animate;
  final Widget child;

  const _AnimatedRow({
    required this.index,
    required this.animate,
    required this.child,
  });

  @override
  State<_AnimatedRow> createState() => _AnimatedRowState();
}

class _AnimatedRowState extends State<_AnimatedRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(-0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.animate) {
      Future.delayed(Duration(milliseconds: widget.index * 50), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_AnimatedRow old) {
    super.didUpdateWidget(old);
    if (widget.animate && !old.animate) {
      Future.delayed(Duration(milliseconds: widget.index * 50), () {
        if (mounted) _controller.forward();
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
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// ─── Retry Button ─────────────────────────────────────

class _RetryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RetryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: CyberColors.cyan.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          L.retry.tr,
          style: CyberTextStyles.subtitle.copyWith(
            color: CyberColors.cyan,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
