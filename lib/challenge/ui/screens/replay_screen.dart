import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../../core/game_state.dart';
import '../../../game/cyber_blockx_game.dart';
import '../../../services/localization_service.dart';
import '../../../ui/theme/cyber_theme.dart';
import '../../models/match_state.dart';
import '../../replay/replay_data.dart';
import '../../replay/replay_orchestrator.dart';
import '../widgets/challenge_left_hud.dart';
import '../widgets/opponent_ghost_hud.dart';
import '../../../ui/widgets/game_hud.dart';
import '../widgets/match_countdown_overlay.dart';

/// Replay viewer screen for watching recorded challenge matches.
///
/// Mirrors the ChallengeGameScreen layout but replaces touch controls
/// with playback controls (play/pause, speed, progress bar).
/// No game input is accepted — the replay drives both game states.
class ReplayScreen extends StatefulWidget {
  final ReplayData replay;
  final VoidCallback onClose;

  const ReplayScreen({
    super.key,
    required this.replay,
    required this.onClose,
  });

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  late ReplayOrchestrator _orchestrator;
  late CyberBlockxGame _game;

  @override
  void initState() {
    super.initState();

    _orchestrator = ReplayOrchestrator(replay: widget.replay);

    // Create Flame game using the player's GameState
    _game = CyberBlockxGame(gameState: _orchestrator.playerState);

    // Let the Flame game loop drive the replay orchestrator
    _game.replayOrchestrator = _orchestrator;

    _orchestrator.addListener(_onOrchestratorChanged);

    // Start countdown
    _orchestrator.startCountdown();
  }

  @override
  void dispose() {
    _orchestrator.removeListener(_onOrchestratorChanged);
    _orchestrator.dispose();
    super.dispose();
  }

  void _onOrchestratorChanged() {
    // Feed opponent projection to the game for ghost board rendering (skip for solo)
    if (!_orchestrator.isSinglePlayer) {
      _game.opponentProjection = _orchestrator.opponentProjection;
    }

    // Handle game events from player state (visual effects only, no audio during replay)
    _handlePlayerEvents();

    // Sync Flame engine pause state
    _syncEngineState();

    setState(() {});
  }

  void _handlePlayerEvents() {
    final events = _orchestrator.playerState.popEvents();
    for (final event in events) {
      switch (event) {
        case GameEvent.pieceLocked:
          if (_orchestrator.playerState.lastLockedPiece != null) {
            _game.triggerLockEffect(_orchestrator.playerState.lastLockedPiece!);
          }
        case GameEvent.linesCleared:
          if (_orchestrator.playerState.lastClearedRows.isNotEmpty) {
            _game.triggerLineClearEffect(
                _orchestrator.playerState.lastClearedRows);
          }
        default:
          break;
      }
    }
  }

  void _syncEngineState() {
    final shouldPause = _orchestrator.phase == MatchPhase.result;
    if (shouldPause && !_game.paused) {
      _game.pauseEngine();
    } else if (!shouldPause && _game.paused) {
      _game.resumeEngine();
    }
  }

  void _restartReplay() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReplayScreen(
          replay: widget.replay,
          onClose: widget.onClose,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phase = _orchestrator.phase;

    return Scaffold(
      backgroundColor: CyberColors.background,
      body: Stack(
        children: [
          // Main layout
          Column(
            children: [
              // Top bar: REPLAY title + opponent info + result chip
              SafeArea(
                bottom: false,
                child: _ReplayTopBar(
                  replay: widget.replay,
                  onClose: widget.onClose,
                ),
              ),

              // Main game area (Left HUD + Game Board + Opponent Ghost HUD)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left HUD - Hold + Score/Level/Lines (+ Next queue in challenge mode)
                    ChallengeLeftHUD(
                      gameState: _orchestrator.playerState,
                      showNext: !_orchestrator.isSinglePlayer,
                    ),

                    // Game board in center
                    Expanded(
                      child: GameWidget(game: _game),
                    ),

                    // Right HUD
                    if (!_orchestrator.isSinglePlayer)
                      // Challenge mode: Opponent ghost stats
                      ListenableBuilder(
                        listenable: _orchestrator,
                        builder: (context, _) {
                          return OpponentGhostHUD(
                            opponent: _orchestrator.opponentMatchState,
                          );
                        },
                      )
                    else
                      // Solo mode: NEXT queue on right side
                      SizedBox(
                        width: 58,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 2, top: 10),
                          child: Column(
                            children: [
                              SideNextQueue(
                                label: L.next.tr,
                                pieces: _orchestrator.playerState.previewQueue,
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom: Playback controls (replaces touch controls)
              if (phase == MatchPhase.playing || phase == MatchPhase.result)
                SafeArea(
                  top: false,
                  child: _ReplayControls(
                    orchestrator: _orchestrator,
                  ),
                ),
            ],
          ),

          // Countdown overlay
          if (phase == MatchPhase.countdown)
            Positioned.fill(
              child: MatchCountdownOverlay(
                countdownSeconds: _orchestrator.countdownSeconds,
              ),
            ),

          // Replay complete overlay
          if (phase == MatchPhase.result)
            Positioned.fill(
              child: _ReplayCompleteOverlay(
                replay: widget.replay,
                onClose: widget.onClose,
                onReplay: _restartReplay,
              ),
            ),
        ],
      ),
    );
  }
}

/// Opponent match state helper for the replay HUD.
extension on ReplayOrchestrator {
  PlayerMatchState get opponentMatchState => PlayerMatchState(
        playerId: 'opponent',
        displayName: replay.opponentName,
        isBot: true,
        score: opponentState.scoring.score,
        level: opponentState.scoring.level,
        lines: opponentState.scoring.totalLines,
        combo: opponentState.scoring.combo,
        isAlive: opponentState.phase != GamePhase.gameOver,
      );
}

/// Top bar for replay mode.
class _ReplayTopBar extends StatelessWidget {
  final ReplayData replay;
  final VoidCallback onClose;

  const _ReplayTopBar({required this.replay, required this.onClose});

  bool get _isSolo => replay.opponentActions.isEmpty;

  @override
  Widget build(BuildContext context) {
    final outcomeColor = replay.outcome == 'win'
        ? CyberColors.green
        : (replay.outcome == 'draw' ? CyberColors.yellow : CyberColors.red);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CyberColors.surface.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: CyberColors.cyan.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onClose,
            child: Icon(Icons.arrow_back,
                color: CyberColors.cyan.withValues(alpha: 0.8), size: 20),
          ),
          const SizedBox(width: 12),

          // Title: "SOLO REPLAY" or "REPLAY"
          Text(
            _isSolo ? L.soloReplay.tr : L.replayTitle.tr,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: CyberColors.cyan,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(width: 12),

          // vs opponent (hidden for solo)
          if (!_isSolo)
            Expanded(
              child: Text(
                'vs ${replay.opponentName}',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

          if (_isSolo) const Spacer(),

          // Outcome chip (hidden for solo — always "game_over")
          if (!_isSolo)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: outcomeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: outcomeColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                replay.outcome.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: outcomeColor,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom playback controls for replay mode.
class _ReplayControls extends StatelessWidget {
  final ReplayOrchestrator orchestrator;

  const _ReplayControls({required this.orchestrator});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CyberColors.surface.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(
            color: CyberColors.cyan.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: orchestrator.progress,
              backgroundColor: CyberColors.surface,
              valueColor: const AlwaysStoppedAnimation<Color>(CyberColors.cyan),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 10),

          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: orchestrator.togglePause,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CyberColors.cyan.withValues(alpha: 0.15),
                    border: Border.all(
                        color: CyberColors.cyan.withValues(alpha: 0.5)),
                  ),
                  child: Icon(
                    orchestrator.isPaused ? Icons.play_arrow : Icons.pause,
                    color: CyberColors.cyan,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Speed selector
              _SpeedChip(
                label: '1x',
                isSelected: orchestrator.speed == 1.0,
                onTap: () => orchestrator.setSpeed(1.0),
              ),
              const SizedBox(width: 6),
              _SpeedChip(
                label: '2x',
                isSelected: orchestrator.speed == 2.0,
                onTap: () => orchestrator.setSpeed(2.0),
              ),
              const SizedBox(width: 6),
              _SpeedChip(
                label: '4x',
                isSelected: orchestrator.speed == 4.0,
                onTap: () => orchestrator.setSpeed(4.0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Speed selector chip with cyberpunk styling.
class _SpeedChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpeedChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? CyberColors.cyan.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? CyberColors.cyan
                : CyberColors.cyan.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            color: isSelected
                ? CyberColors.cyan
                : CyberColors.cyan.withValues(alpha: 0.5),
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// Overlay shown when replay playback is complete.
class _ReplayCompleteOverlay extends StatelessWidget {
  final ReplayData replay;
  final VoidCallback onClose;
  final VoidCallback onReplay;

  const _ReplayCompleteOverlay({
    required this.replay,
    required this.onClose,
    required this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                L.replayComplete.tr,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: CyberColors.cyan,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(
                      color: CyberColors.cyan.withValues(alpha: 0.5),
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Replay Again ---
              _overlayButton(
                icon: Icons.replay,
                label: L.replayAgain.tr,
                onTap: onReplay,
              ),
              const SizedBox(height: 12),

              // --- Return to Menu ---
              _overlayButton(
                icon: Icons.close,
                label: L.returnToMenu.tr,
                onTap: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlayButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: CyberColors.cyan.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: CyberColors.cyan,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: CyberColors.cyan, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: CyberColors.cyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

