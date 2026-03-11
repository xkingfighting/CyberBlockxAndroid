import 'package:flutter/material.dart';
import '../../../services/localization_service.dart';
import '../../../ui/theme/cyber_theme.dart';
import '../../models/match_history_entry.dart';
import '../../replay/replay_data.dart';
import '../../replay/replay_storage.dart';
import 'replay_screen.dart';

/// Full detail view for a single challenge match record.
class MatchDetailScreen extends StatefulWidget {
  final MatchHistoryEntry entry;
  final VoidCallback onClose;

  const MatchDetailScreen({
    super.key,
    required this.entry,
    required this.onClose,
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _resultScale;
  bool _metadataExpanded = false;
  bool _replayAvailable = false;

  MatchHistoryEntry get e => widget.entry;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _resultScale = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _animController.forward();
    _checkReplayAvailability();
  }

  Future<void> _checkReplayAvailability() async {
    // Check local first, then fall back to server flag
    final localExists = await ReplayStorage.exists(e.matchId);
    final available = localExists || e.replayAvailable;
    if (mounted) setState(() => _replayAvailable = available);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String get _localizedMode {
    return e.modeType == 'survival' ? L.survival.tr : L.scoreRace.tr;
  }

  String _localizedDifficulty(String? diff) {
    switch (diff) {
      case 'easy':
        return L.easy.tr;
      case 'medium':
        return L.medium.tr;
      case 'hard':
        return L.hard.tr;
      default:
        return diff ?? '';
    }
  }

  Color get _outcomeColor {
    switch (e.outcome) {
      case 'win':
        return CyberColors.green;
      case 'lose':
        return CyberColors.red;
      default:
        return CyberColors.yellow;
    }
  }

  String get _outcomeText {
    switch (e.outcome) {
      case 'win':
        return L.victory.tr;
      case 'lose':
        return L.defeat.tr;
      default:
        return L.draw.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: CyberColors.background,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          _buildResultHeader(),
                          const SizedBox(height: 20),
                          _buildScoreComparison(),
                          const SizedBox(height: 16),
                          _buildMatchInfo(),
                          const SizedBox(height: 16),
                          _buildOpponentInfo(),
                          if (e.reward > 0 || e.isNewRecord || e.ratingChange != null) ...[
                            const SizedBox(height: 16),
                            _buildRewardBlock(),
                          ],
                          const SizedBox(height: 16),
                          _buildMetadata(),
                          const SizedBox(height: 16),
                          _buildReplayButton(),
                          const SizedBox(height: 24),
                        ],
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

  // ─── Header ───────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                border: Border.all(
                    color: CyberColors.cyan.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_back,
                  color: CyberColors.cyan, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            L.matchDetail.tr,
            style: CyberTextStyles.subtitle.copyWith(
              color: CyberColors.cyan,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Result Header ────────────────────────────────────

  Widget _buildResultHeader() {
    final modeColor =
        e.modeType == 'survival' ? CyberColors.purple : CyberColors.cyan;

    return ScaleTransition(
      scale: _resultScale,
      child: Column(
        children: [
          // Outcome text with glow
          Text(
            _outcomeText,
            style: CyberTextStyles.title.copyWith(
              fontSize: 32,
              color: _outcomeColor,
              shadows: [
                Shadow(color: _outcomeColor.withValues(alpha: 0.6), blurRadius: 20),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // vs opponent
          Text(
            'vs ${e.opponentName}',
            style: CyberTextStyles.body.copyWith(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          if (e.opponentDifficulty != null) ...[
            const SizedBox(height: 2),
            Text(
              '(${_localizedDifficulty(e.opponentDifficulty)})',
              style: CyberTextStyles.body.copyWith(
                color: CyberColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Chips row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chip(
                e.isBot ? L.bot.tr : L.player.tr,
                e.isBot ? CyberColors.purple : CyberColors.cyan,
              ),
              const SizedBox(width: 8),
              _chip(_localizedMode, modeColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ─── Score Comparison ─────────────────────────────────

  Widget _buildScoreComparison() {
    return _section(
      child: Column(
        children: [
          // Column headers
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    L.you.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: CyberColors.cyan,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 80),
                Expanded(
                  child: Text(
                    L.opp.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: CyberColors.pink,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _scoreRow(L.score.tr, e.playerScore, e.opponentScore),
          _scoreRow(L.lines.tr, e.playerLines, e.opponentLines),
          _scoreRow(L.level.tr, e.playerLevel, e.opponentLevel),
          _scoreRow(L.pieces.tr, e.playerPiecesPlaced, e.opponentPiecesPlaced),
          if (e.playerMaxCombo > 0)
            _scoreRow(L.maxComboLabel.tr, e.playerMaxCombo, 0,
                hideOpponent: true),
        ],
      ),
    );
  }

  Widget _scoreRow(String label, int player, int opponent,
      {bool hideOpponent = false}) {
    final playerHigher = player > opponent;
    final opponentHigher = opponent > player;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _formatScore(player),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: playerHigher ? CyberColors.cyan : Colors.white,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: CyberColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              hideOpponent ? '' : _formatScore(opponent),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: opponentHigher ? CyberColors.pink : CyberColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Match Info ───────────────────────────────────────

  Widget _buildMatchInfo() {
    return _section(
      child: Column(
        children: [
          _infoRow(L.mode.tr, _localizedMode),
          _infoRow(L.duration.tr, e.formattedDuration),
          if (e.configDuration > 0)
            _infoRow(L.timeLimit.tr, '${e.configDuration ~/ 60}:${(e.configDuration % 60).toString().padLeft(2, '0')}'),
          _infoRow(L.date.tr, e.formattedDateTime),
          _infoRow(L.seedLabel.tr, '#${e.seed}'),
        ],
      ),
    );
  }

  // ─── Opponent Info ────────────────────────────────────

  Widget _buildOpponentInfo() {
    return _section(
      child: Column(
        children: [
          _infoRow(L.type.tr, e.isBot ? L.bot.tr : L.player.tr),
          if (e.isBot && e.opponentBotProfileId != null)
            _infoRow(L.profile.tr, e.opponentName),
          if (e.opponentDifficulty != null)
            _infoRow(L.difficulty.tr, _localizedDifficulty(e.opponentDifficulty)),
          if (e.opponentPlayerId != null && !e.isBot)
            _infoRow(L.playerId.tr, e.opponentPlayerId!),
        ],
      ),
    );
  }

  // ─── Reward Block ─────────────────────────────────────

  Widget _buildRewardBlock() {
    return _section(
      child: Column(
        children: [
          if (e.reward > 0)
            _infoRow(L.rewardLabel.tr, '+${e.reward} CBX',
                valueColor: CyberColors.yellow),
          if (e.isNewRecord)
            _infoRow(L.newRecord.tr, '\u2605 Yes',
                valueColor: CyberColors.yellow),
          if (e.ratingChange != null)
            _infoRow(
              L.ratingLabel.tr,
              '${e.ratingChange! >= 0 ? '+' : ''}${e.ratingChange}${e.newRating != null ? ' \u2192 ${_formatScore(e.newRating!)}' : ''}',
              valueColor: e.ratingChange! >= 0
                  ? CyberColors.green
                  : CyberColors.red,
            ),
        ],
      ),
    );
  }

  // ─── Metadata (Collapsed) ─────────────────────────────

  Widget _buildMetadata() {
    return _section(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _metadataExpanded = !_metadataExpanded),
            child: Row(
              children: [
                Text(
                  L.metadata.tr,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: CyberColors.textMuted,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Icon(
                  _metadataExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: CyberColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
          if (_metadataExpanded) ...[
            const SizedBox(height: 8),
            _infoRow(L.matchId.tr, e.matchId.length > 16
                ? '${e.matchId.substring(0, 16)}...'
                : e.matchId),
            if (e.clientPlatform.isNotEmpty)
              _infoRow(L.platform.tr, e.clientPlatform),
            if (e.matchSource.isNotEmpty)
              _infoRow(L.source.tr, e.matchSource),
            _infoRow(L.ruleset.tr, 'v${e.rulesetVersion}'),
          ],
        ],
      ),
    );
  }

  // ─── Replay Button ───────────────────────────────

  Widget _buildReplayButton() {
    return GestureDetector(
      onTap: _replayAvailable ? _openReplay : null,
      child: Opacity(
        opacity: _replayAvailable ? 1.0 : 0.3,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _replayAvailable
                ? CyberColors.cyan.withValues(alpha: 0.08)
                : Colors.transparent,
            border: Border.all(
              color: CyberColors.cyan.withValues(alpha: _replayAvailable ? 0.6 : 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow, color: CyberColors.cyan, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    L.replay.tr,
                    style: CyberTextStyles.button.copyWith(
                      color: CyberColors.cyan,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (!_replayAvailable) ...[
                const SizedBox(height: 2),
                Text(
                  L.comingSoon.tr,
                  style: CyberTextStyles.body.copyWith(
                    color: CyberColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReplay() async {
    // Try local first
    ReplayData? replay = await ReplayStorage.load(e.matchId);

    // If not local, download from server
    if (replay == null) {
      if (!mounted) return;
      // Show brief loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading replay...', style: TextStyle(fontFamily: 'monospace')),
          duration: Duration(seconds: 1),
        ),
      );
      replay = await ReplayStorage.downloadFromServer(e.matchId);
    }

    if (replay == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReplayScreen(
          replay: replay!,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  // ─── Shared Helpers ───────────────────────────────────

  Widget _section({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CyberColors.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CyberColors.cyan.withValues(alpha: 0.1),
        ),
      ),
      child: child,
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: CyberColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.white,
              ),
            ),
          ),
        ],
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
