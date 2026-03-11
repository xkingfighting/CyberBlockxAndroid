import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/game_state.dart';
import '../../../game/cyber_blockx_game.dart';
import '../../../services/audio_manager.dart';
import '../../../services/localization_service.dart';
import '../../../ui/theme/cyber_theme.dart';
import '../../../ui/widgets/touch_controls.dart';
import '../../models/match_config.dart';
import '../../models/match_state.dart';
import '../../models/challenge_result.dart';
import '../../core/challenge_orchestrator.dart';
import '../../replay/replay_storage.dart';
import '../../services/match_service.dart';
import '../widgets/challenge_left_hud.dart';
import '../widgets/challenge_top_bar.dart';
import '../widgets/opponent_ghost_hud.dart';
import '../widgets/match_countdown_overlay.dart';

/// Main game screen for challenge (1v1) mode.
///
/// Mirrors the structure of the solo [GameScreen] but is adapted for challenge:
/// - Creates a [ChallengeOrchestrator] instead of a bare GameState
/// - Uses [ChallengeTopBar] at the top for timer/mode/opponent info
/// - Uses [OpponentGhostHUD] on the right instead of [RightHUD]
/// - Shows [MatchCountdownOverlay] during the countdown phase
/// - Shows a challenge result overlay during the result phase
/// - Touch controls forward to orchestrator player input proxies
class ChallengeGameScreen extends StatefulWidget {
  final MatchConfig config;
  final VoidCallback onReturnToMenu;

  const ChallengeGameScreen({
    super.key,
    required this.config,
    required this.onReturnToMenu,
  });

  @override
  State<ChallengeGameScreen> createState() => _ChallengeGameScreenState();
}

class _ChallengeGameScreenState extends State<ChallengeGameScreen> {
  late ChallengeOrchestrator _orchestrator;
  late CyberBlockxGame _game;
  final FocusNode _focusNode = FocusNode();
  final AudioManager _audio = AudioManager.instance;

  bool _resultSubmitted = false;
  bool _resultSubmitting = false;

  @override
  void initState() {
    super.initState();

    _orchestrator = ChallengeOrchestrator(config: widget.config);

    // Create Flame game using the player's GameState
    _game = CyberBlockxGame(gameState: _orchestrator.playerState);

    // Let the Flame game loop drive the orchestrator (countdown, bot, etc.)
    _game.challengeOrchestrator = _orchestrator;

    _orchestrator.addListener(_onOrchestratorChanged);

    // Start background music and countdown
    _audio.onGameStart();
    _orchestrator.startCountdown();
  }

  @override
  void dispose() {
    _orchestrator.removeListener(_onOrchestratorChanged);
    _orchestrator.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onOrchestratorChanged() {
    // Feed opponent projection to the game for ghost board rendering
    _game.opponentProjection = _orchestrator.opponentProjection;

    // Handle game events from player state
    _handlePlayerEvents();

    // Sync Flame engine pause state
    _syncEngineState();

    // Auto-submit result when match ends (for all matches including local bot)
    if (_orchestrator.phase == MatchPhase.result && !_resultSubmitted && !_resultSubmitting) {
      _submitResult();
    }

    setState(() {});
  }

  void _handlePlayerEvents() {
    final events = _orchestrator.playerState.popEvents();
    for (final event in events) {
      switch (event) {
        case GameEvent.pieceLocked:
          _audio.playSound(GameSound.lock);
          if (_orchestrator.playerState.lastLockedPiece != null) {
            _game.triggerLockEffect(_orchestrator.playerState.lastLockedPiece!);
          }
        case GameEvent.linesCleared:
          _audio.playSound(GameSound.lineClear);
          if (_orchestrator.playerState.lastClearedRows.isNotEmpty) {
            _game.triggerLineClearEffect(
                _orchestrator.playerState.lastClearedRows);
          }
        case GameEvent.tetris:
          _audio.playSound(GameSound.tetris);
        case GameEvent.levelUp:
          _audio.playSound(GameSound.levelUp);
        case GameEvent.gameOver:
          _audio.onGameOver();
        case GameEvent.combo:
          _audio.playSound(GameSound.combo);
        case GameEvent.perfectClear:
          _audio.playSound(GameSound.perfectClear);
      }
    }
  }

  /// Pause Flame rendering during non-playing phases to save GPU/CPU.
  void _syncEngineState() {
    final shouldPause = _orchestrator.phase == MatchPhase.result ||
        _orchestrator.phase == MatchPhase.finishing;
    if (shouldPause && !_game.paused) {
      _game.pauseEngine();
    } else if (!shouldPause && _game.paused) {
      _game.resumeEngine();
    }
  }

  /// Submit match result to the server.
  /// Works for both server-created matches and local bot matches.
  /// For local matches, extra metadata is sent so the server can create the record.
  Future<void> _submitResult() async {
    if (_resultSubmitted || _resultSubmitting) return;
    final result = _orchestrator.result;
    if (result == null) return;

    setState(() => _resultSubmitting = true);

    final config = widget.config;
    final response = await MatchService.instance.submitResult(
      matchId: result.matchId,
      score: result.playerScore,
      lines: result.playerLines,
      level: result.playerLevel,
      piecesPlaced: 0, // TODO: track pieces placed in orchestrator
      duration: result.matchDuration.inSeconds.toDouble(),
      gameToken: '', // TODO: integrity token
      opponentFinalScore: result.opponentScore,
      opponentFinalLines: result.opponentLines,
      isOpponentBot: result.isOpponentBot,
      // Extra metadata for local bot matches — server uses these to create
      // the match record on-the-fly when matchId starts with "local_".
      modeType: config.modeType,
      seed: config.seed,
      configDuration: config.duration,
      opponentName: config.opponent.displayName,
      // Match history enrichment
      opponentLevel: result.opponentLevel,
      opponentDifficulty: config.opponent.botProfile != null
          ? _difficultyFromProfileId(config.opponent.botProfile!.profileId)
          : null,
      opponentBotProfileId: config.opponent.botProfile?.profileId,
    );

    // Save replay locally (regardless of submit success)
    final replayData = _orchestrator.getReplayData();
    if (replayData != null) {
      await ReplayStorage.save(replayData);
      // Upload to server (fire-and-forget, for cross-device access & AI learning)
      ReplayStorage.uploadToServer(replayData);
    }

    if (mounted) {
      setState(() {
        _resultSubmitted = true;
        _resultSubmitting = false;
      });
      // Show error snackbar if submission failed
      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L.submitFailed.tr, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            backgroundColor: CyberColors.surface,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Map bot profileId to difficulty string.
  static String _difficultyFromProfileId(String profileId) {
    switch (profileId) {
      case 'beginner': return 'easy';
      case 'balanced': return 'medium';
      case 'aggressive': return 'hard';
      default: return 'easy';
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = _orchestrator.phase;
    final isPlaying = phase == MatchPhase.playing;

    return Scaffold(
      backgroundColor: CyberColors.background,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            // Main game layout
            Column(
              children: [
                // Top bar: timer, mode, opponent info
                SafeArea(
                  bottom: false,
                  child: ChallengeTopBar(orchestrator: _orchestrator),
                ),

                // Main game area (Left HUD + Game Board + Opponent Ghost HUD)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left HUD - Hold + Score/Level/Lines + Next queue
                      ChallengeLeftHUD(gameState: _orchestrator.playerState),

                      // Game board in center
                      Expanded(
                        child: GameWidget(game: _game),
                      ),

                      // Right HUD - Opponent ghost stats
                      ListenableBuilder(
                        listenable: _orchestrator,
                        builder: (context, _) {
                          return OpponentGhostHUD(
                            opponent: _orchestrator.opponentMatchState,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Touch controls at bottom - only during playing phase
                if (isPlaying)
                  SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 200,
                      child: TouchControls(
                        onMoveLeft: () {
                          _orchestrator.playerMoveLeft();
                          _audio.playSound(GameSound.move);
                        },
                        onMoveRight: () {
                          _orchestrator.playerMoveRight();
                          _audio.playSound(GameSound.move);
                        },
                        onSoftDrop: () {
                          _orchestrator.playerSoftDrop();
                          _audio.playSound(GameSound.move);
                        },
                        onHardDrop: () {
                          _orchestrator.playerHardDrop();
                        },
                        onRotateCW: () {
                          _orchestrator.playerRotateCW();
                          _audio.playSound(GameSound.rotate);
                        },
                        onRotateCCW: () {
                          _orchestrator.playerRotateCCW();
                          _audio.playSound(GameSound.rotate);
                        },
                        onHold: () {
                          _orchestrator.playerHold();
                          _audio.playSound(GameSound.hold);
                        },
                        onPause: _togglePause,
                      ),
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

            // Pause overlay — player paused, but bot keeps running
            if (phase == MatchPhase.playing && _orchestrator.isPlayerPaused)
              Positioned.fill(
                child: _ChallengePauseOverlay(
                  onResume: () {
                    _orchestrator.resumePlayer();
                    _audio.onGameResume();
                  },
                  onMenu: widget.onReturnToMenu,
                ),
              ),

            // Match result overlay
            if (phase == MatchPhase.result && _orchestrator.result != null)
              Positioned.fill(
                child: _ChallengeResultOverlay(
                  result: _orchestrator.result!,
                  onReturnToMenu: widget.onReturnToMenu,
                  isSubmitting: _resultSubmitting,
                  isSubmitted: _resultSubmitted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _togglePause() {
    if (_orchestrator.phase != MatchPhase.playing) return;
    if (_orchestrator.isPlayerPaused) {
      _orchestrator.resumePlayer();
      _audio.onGameResume();
    } else {
      _orchestrator.pausePlayer();
      _audio.onGamePause();
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_orchestrator.phase != MatchPhase.playing) return;

    // ESC / P toggle pause
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.keyP) {
      _togglePause();
      return;
    }

    // Block game inputs while paused
    if (_orchestrator.isPlayerPaused) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.keyA:
        _orchestrator.playerMoveLeft();
        _audio.playSound(GameSound.move);
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.keyD:
        _orchestrator.playerMoveRight();
        _audio.playSound(GameSound.move);
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.keyS:
        _orchestrator.playerSoftDrop();
        _audio.playSound(GameSound.move);
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyW:
      case LogicalKeyboardKey.keyX:
        _orchestrator.playerRotateCW();
        _audio.playSound(GameSound.rotate);
      case LogicalKeyboardKey.keyZ:
        _orchestrator.playerRotateCCW();
        _audio.playSound(GameSound.rotate);
      case LogicalKeyboardKey.space:
        _orchestrator.playerHardDrop();
      case LogicalKeyboardKey.keyC:
      case LogicalKeyboardKey.shiftLeft:
        _orchestrator.playerHold();
        _audio.playSound(GameSound.hold);
      default:
        break;
    }
  }
}

/// Challenge result overlay shown after a match ends.
/// Results are auto-submitted; this overlay shows the status indicator.
class _ChallengeResultOverlay extends StatelessWidget {
  final ChallengeResult result;
  final VoidCallback onReturnToMenu;
  final bool isSubmitting;
  final bool isSubmitted;

  const _ChallengeResultOverlay({
    required this.result,
    required this.onReturnToMenu,
    required this.isSubmitting,
    required this.isSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final isWin = result.outcome == MatchOutcome.win;
    final isDraw = result.outcome == MatchOutcome.draw;
    final outcomeColor =
        isWin ? CyberColors.green : (isDraw ? CyberColors.yellow : CyberColors.red);
    final outcomeText =
        isWin ? L.victory.tr : (isDraw ? L.draw.tr : L.defeat.tr);

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Outcome text
                Text(
                  outcomeText,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: outcomeColor,
                    letterSpacing: 6,
                    shadows: [
                      Shadow(
                        color: outcomeColor.withValues(alpha: 0.6),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // vs opponent
                Text(
                  'vs ${result.opponentName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),

                // Score comparison
                _ScoreComparisonRow(
                  label: L.score.tr.toUpperCase(),
                  playerValue: '${result.playerScore}',
                  opponentValue: '${result.opponentScore}',
                  playerIsHigher: result.playerScore >= result.opponentScore,
                ),
                const SizedBox(height: 8),
                _ScoreComparisonRow(
                  label: L.lines.tr.toUpperCase(),
                  playerValue: '${result.playerLines}',
                  opponentValue: '${result.opponentLines}',
                  playerIsHigher: result.playerLines >= result.opponentLines,
                ),
                const SizedBox(height: 8),
                _ScoreComparisonRow(
                  label: L.level.tr.toUpperCase(),
                  playerValue: '${result.playerLevel}',
                  opponentValue: '${result.opponentLevel}',
                  playerIsHigher: result.playerLevel >= result.opponentLevel,
                ),

                // Reward
                if (result.reward > 0) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: CyberColors.yellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: CyberColors.yellow.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '+${result.reward} CBX',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: CyberColors.yellow,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Auto-submit status indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSubmitting)
                      const SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: CyberColors.cyan,
                        ),
                      )
                    else
                      Icon(
                        isSubmitted ? Icons.cloud_done : Icons.cloud_off,
                        size: 14,
                        color: isSubmitted
                            ? CyberColors.green.withValues(alpha: 0.6)
                            : CyberColors.red.withValues(alpha: 0.5),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      isSubmitting
                          ? L.submittingResult.tr
                          : (isSubmitted ? L.submitted.tr : L.submitFailed.tr),
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Return to menu button
                CyberButton(
                  text: L.returnToMenu.tr,
                  onPressed: onReturnToMenu,
                  color: CyberColors.pink,
                  icon: Icons.arrow_back,
                  expanded: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Challenge mode pause overlay.
/// Only freezes the player — opponent bot and timer keep running.
class _ChallengePauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onMenu;

  const _ChallengePauseOverlay({
    required this.onResume,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onResume,
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFD700),
                    Color(0xFFFF8C00),
                  ],
                ).createShader(bounds),
                child: Text(
                  L.paused.tr,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: Colors.white,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(
                        color: Colors.orange.withValues(alpha: 0.5),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Warning text — opponent keeps playing
              Text(
                L.opponentKeepsPlaying.tr,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: CyberColors.red.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),

              // Divider
              Container(
                width: 160,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      CyberColors.cyan.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Resume button
              _ChallengePauseButton(
                text: L.resume.tr,
                icon: Icons.play_arrow,
                color: CyberColors.green,
                onTap: onResume,
              ),
              const SizedBox(height: 10),

              // Main menu (surrender)
              _ChallengePauseButton(
                text: L.mainMenu.tr,
                icon: Icons.home,
                color: CyberColors.purple,
                onTap: onMenu,
              ),
              const SizedBox(height: 20),

              // Hint
              Text(
                L.tapToResume.tr,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.grey.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChallengePauseButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ChallengePauseButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ChallengePauseButton> createState() => _ChallengePauseButtonState();
}

class _ChallengePauseButtonState extends State<_ChallengePauseButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 260,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: _isPressed
              ? widget.color.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isPressed ? widget.color : widget.color.withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(widget.icon, color: widget.color, size: 18),
            const SizedBox(width: 14),
            Text(
              widget.text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: widget.color,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row comparing player vs opponent values.
class _ScoreComparisonRow extends StatelessWidget {
  final String label;
  final String playerValue;
  final String opponentValue;
  final bool playerIsHigher;

  const _ScoreComparisonRow({
    required this.label,
    required this.playerValue,
    required this.opponentValue,
    required this.playerIsHigher,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Player value
        Expanded(
          child: Text(
            playerValue,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: playerIsHigher
                  ? CyberColors.cyan
                  : Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        // Label in center
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1,
            ),
          ),
        ),
        // Opponent value
        Expanded(
          child: Text(
            opponentValue,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: !playerIsHigher
                  ? CyberColors.pink
                  : Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}
