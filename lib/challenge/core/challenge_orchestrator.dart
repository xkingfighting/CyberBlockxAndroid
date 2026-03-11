import 'package:flutter/foundation.dart';
import '../../core/game_state.dart';
import '../../core/board.dart';
import '../models/match_config.dart';
import '../models/match_state.dart';
import '../models/opponent_projection.dart';
import '../models/challenge_result.dart';
import '../bot/bot_controller.dart';
import '../replay/replay_data.dart';
import '../replay/replay_recorder.dart';
import 'seeded_random_bag.dart';

/// Orchestrates a 1v1 challenge match.
///
/// Manages two GameState instances (player + opponent),
/// the match lifecycle (countdown → playing → result),
/// and produces OpponentProjection for ghost rendering.
class ChallengeOrchestrator extends ChangeNotifier {
  final MatchConfig config;

  /// Player's game state (driven by user input).
  late final GameState playerState;

  /// Opponent's game state (driven by bot or network).
  late final GameState opponentState;

  /// Bot controller (null if opponent is human - Phase 2).
  BotController? _botController;

  /// Replay recorder for capturing match actions.
  final ReplayRecorder _replayRecorder = ReplayRecorder();

  /// Match lifecycle.
  MatchPhase _phase = MatchPhase.idle;
  MatchPhase get phase => _phase;

  /// Whether the player has paused.
  /// When paused, only the player freezes — bot and timer keep running.
  bool _playerPaused = false;
  bool get isPlayerPaused => _playerPaused;

  double _elapsedSeconds = 0;
  double get elapsedSeconds => _elapsedSeconds;

  double _countdownSeconds = 3.0;
  double get countdownSeconds => _countdownSeconds;

  /// Throttled timer display — only updates when integer second changes (~1/sec vs 60/sec).
  int _displayedRemainingSeconds = 0;
  int get displayedRemainingSeconds => _displayedRemainingSeconds;

  /// Remaining match time (for timed modes).
  double get remainingSeconds {
    if (config.duration <= 0) return double.infinity;
    return (config.duration - _elapsedSeconds).clamp(0, config.duration.toDouble());
  }

  /// Opponent projection for ghost board rendering.
  OpponentProjection _opponentProjection = OpponentProjection.empty();
  OpponentProjection get opponentProjection => _opponentProjection;

  /// Recent clear decay timer for ghost visual effect.
  double _clearDecayTimer = 0;
  List<int> _recentClearRows = [];

  /// Pre-allocated grid buffer for ghost rendering — avoids 21 list allocations per frame.
  final List<List<bool>> _gridBuffer = List.generate(
    20, (_) => List.filled(10, false),
  );

  /// Match result (available after finishing).
  ChallengeResult? _result;
  ChallengeResult? get result => _result;

  /// Player match state (for HUD display).
  PlayerMatchState get playerMatchState => PlayerMatchState(
        playerId: 'self',
        displayName: 'YOU',
        score: playerState.scoring.score,
        level: playerState.scoring.level,
        lines: playerState.scoring.totalLines,
        combo: playerState.scoring.combo,
        isAlive: playerState.phase != GamePhase.gameOver,
      );

  /// Opponent match state (for HUD display).
  PlayerMatchState get opponentMatchState => PlayerMatchState(
        playerId: config.opponent.playerId,
        displayName: config.opponent.displayName,
        isBot: config.opponent.isBot,
        score: opponentState.scoring.score,
        level: opponentState.scoring.level,
        lines: opponentState.scoring.totalLines,
        combo: opponentState.scoring.combo,
        isAlive: opponentState.phase != GamePhase.gameOver,
      );

  ChallengeOrchestrator({required this.config}) {
    // Create both game states with the same seeded random bag
    final playerBag = SeededRandomBag(config.seed);
    final opponentBag = SeededRandomBag(config.seed);

    playerState = GameState(pieceBag: playerBag);
    opponentState = GameState(pieceBag: opponentBag);

    // Set up bot if opponent is AI
    if (config.opponent.isBot && config.opponent.botProfile != null) {
      _botController = BotController(
        gameState: opponentState,
        profile: config.opponent.botProfile!,
      );
      // Record bot actions for replay
      _botController!.onActionExecuted = (action) {
        final code = ReplayAction.fromActionString(action);
        if (code >= 0) _replayRecorder.recordOpponentAction(code);
      };
    }
  }

  /// Start the match countdown.
  void startCountdown() {
    _phase = MatchPhase.countdown;
    _countdownSeconds = 3.0;
    _displayedRemainingSeconds = config.duration > 0 ? config.duration : -1;
    notifyListeners();
  }

  /// Called every frame by the game screen.
  void update(double dt) {
    switch (_phase) {
      case MatchPhase.countdown:
        _updateCountdown(dt);
      case MatchPhase.playing:
        _updatePlaying(dt);
      case MatchPhase.finishing:
        // Brief delay before showing result
        _elapsedSeconds += dt;
      default:
        break;
    }
  }

  void _updateCountdown(double dt) {
    _countdownSeconds -= dt;
    if (_countdownSeconds <= 0) {
      _startMatch();
    }
    notifyListeners();
  }

  void _startMatch() {
    _phase = MatchPhase.playing;
    _elapsedSeconds = 0;

    playerState.startGame();
    opponentState.startGame();
    _botController?.reset();
    _replayRecorder.start();

    notifyListeners();
  }

  /// Pause the player's game. Bot and timer keep running.
  void pausePlayer() {
    if (_phase != MatchPhase.playing || _playerPaused) return;
    _playerPaused = true;
    notifyListeners();
  }

  /// Resume the player's game.
  void resumePlayer() {
    if (!_playerPaused) return;
    _playerPaused = false;
    notifyListeners();
  }

  void _updatePlaying(double dt) {
    _elapsedSeconds += dt;

    // Update player game state (gravity, lock delay) — skip when player paused
    if (!_playerPaused) {
      playerState.update(dt);
    }

    // Update bot (evaluates and executes inputs) — always runs
    _botController?.update(dt);

    // Update opponent projection for ghost rendering
    _updateOpponentProjection(dt);

    // Check if match should end
    _checkMatchEnd();

    // Throttle: only notify when displayed timer changes (~1/sec) to avoid
    // rebuilding the full widget tree 60x/sec. Per-frame game operations
    // (ghost projection, player events) are handled in the Flame game loop.
    final newDisplayed = config.duration > 0
        ? (config.duration - _elapsedSeconds).ceil().clamp(0, config.duration)
        : -1;
    if (newDisplayed != _displayedRemainingSeconds) {
      _displayedRemainingSeconds = newDisplayed;
      notifyListeners();
    }
  }

  void _updateOpponentProjection(double dt) {
    // Decay recent clear highlight
    if (_clearDecayTimer > 0) {
      _clearDecayTimer -= dt;
      if (_clearDecayTimer <= 0) {
        _recentClearRows = [];
      }
    }

    // Check for new line clears from opponent
    final opponentEvents = opponentState.popEvents();
    for (final event in opponentEvents) {
      if (event == GameEvent.linesCleared) {
        _recentClearRows = opponentState.lastClearedRows;
        _clearDecayTimer = 0.5; // 0.5s highlight duration
      }
    }

    // Fill pre-allocated grid buffer in-place (zero allocations)
    _fillBoolGrid(opponentState.board);

    _opponentProjection = OpponentProjection(
      boardGrid: _gridBuffer,
      score: opponentState.scoring.score,
      level: opponentState.scoring.level,
      lines: opponentState.scoring.totalLines,
      isAlive: opponentState.phase != GamePhase.gameOver,
      opacity: config.visibilityRule.ghostOpacity,
      recentClearRows: _recentClearRows,
      recentClearDecay: _clearDecayTimer.clamp(0, 1),
    );
  }

  void _checkMatchEnd() {
    final bool timeUp = config.duration > 0 && _elapsedSeconds >= config.duration;
    final bool playerDead = playerState.phase == GamePhase.gameOver;
    final bool opponentDead = opponentState.phase == GamePhase.gameOver;

    bool shouldEnd = false;

    switch (config.winCondition.type) {
      case 'highest_score':
        // End when: timer expires, EITHER player dies, or both die.
        // No need to wait for the opponent bot to also top out.
        shouldEnd = timeUp || playerDead || opponentDead;
      case 'last_standing':
        shouldEnd = playerDead || opponentDead;
      case 'first_to_target':
        final target = config.winCondition.targetScore ?? 99999;
        shouldEnd = playerState.scoring.score >= target ||
            opponentState.scoring.score >= target ||
            playerDead || opponentDead;
      default:
        shouldEnd = timeUp || playerDead || opponentDead;
    }

    // Also end if time's up (for timed modes, force stop)
    if (timeUp && config.duration > 0) {
      shouldEnd = true;
    }

    if (shouldEnd) {
      _finishMatch();
    }
  }

  void _finishMatch() {
    _phase = MatchPhase.finishing;
    _replayRecorder.stop();

    // Determine winner
    final MatchOutcome outcome;
    if (config.winCondition.type == 'last_standing') {
      if (playerState.phase == GamePhase.gameOver &&
          opponentState.phase != GamePhase.gameOver) {
        outcome = MatchOutcome.lose;
      } else if (opponentState.phase == GamePhase.gameOver &&
          playerState.phase != GamePhase.gameOver) {
        outcome = MatchOutcome.win;
      } else {
        outcome = playerState.scoring.score >= opponentState.scoring.score
            ? MatchOutcome.win
            : MatchOutcome.lose;
      }
    } else {
      if (playerState.scoring.score > opponentState.scoring.score) {
        outcome = MatchOutcome.win;
      } else if (playerState.scoring.score < opponentState.scoring.score) {
        outcome = MatchOutcome.lose;
      } else {
        outcome = MatchOutcome.draw;
      }
    }

    _result = ChallengeResult(
      matchId: config.matchId,
      outcome: outcome,
      playerScore: playerState.scoring.score,
      playerLines: playerState.scoring.totalLines,
      playerLevel: playerState.scoring.level,
      opponentScore: opponentState.scoring.score,
      opponentLines: opponentState.scoring.totalLines,
      opponentLevel: opponentState.scoring.level,
      opponentName: config.opponent.displayName,
      isOpponentBot: config.opponent.isBot,
      reward: outcome == MatchOutcome.win ? config.prizePool : 0,
      matchDuration: Duration(seconds: _elapsedSeconds.toInt()),
    );

    _phase = MatchPhase.result;
    notifyListeners();
  }

  /// Fill pre-allocated grid buffer from board — zero allocations per frame.
  void _fillBoolGrid(Board board) {
    final height = board.height < _gridBuffer.length ? board.height : _gridBuffer.length;
    final width = board.width < _gridBuffer[0].length ? board.width : _gridBuffer[0].length;
    for (int y = height - 1; y >= 0; y--) {
      final bufferRow = _gridBuffer[height - 1 - y];
      for (int x = 0; x < width; x++) {
        bufferRow[x] = board.getCell(x, y).filled;
      }
    }
  }

  // -- Player input proxies --
  // These forward to playerState so the game screen can call them.
  // All inputs are blocked while the player is paused.

  void playerMoveLeft() {
    if (!_playerPaused) { playerState.moveLeft(); _replayRecorder.recordPlayerAction(ReplayAction.left); }
  }
  void playerMoveRight() {
    if (!_playerPaused) { playerState.moveRight(); _replayRecorder.recordPlayerAction(ReplayAction.right); }
  }
  void playerSoftDrop() {
    if (!_playerPaused) { playerState.softDrop(); _replayRecorder.recordPlayerAction(ReplayAction.softDrop); }
  }
  void playerHardDrop() {
    if (!_playerPaused) { playerState.hardDrop(); _replayRecorder.recordPlayerAction(ReplayAction.hardDrop); }
  }
  void playerRotateCW() {
    if (!_playerPaused) { playerState.rotateClockwise(); _replayRecorder.recordPlayerAction(ReplayAction.rotateCW); }
  }
  void playerRotateCCW() {
    if (!_playerPaused) { playerState.rotateCounterClockwise(); _replayRecorder.recordPlayerAction(ReplayAction.rotateCCW); }
  }
  void playerHold() {
    if (!_playerPaused) { playerState.hold(); _replayRecorder.recordPlayerAction(ReplayAction.hold); }
  }

  /// Get the recorded replay data after a match finishes.
  ReplayData? getReplayData() {
    if (_result == null) return null;
    return _replayRecorder.finalize(
      matchId: config.matchId,
      seed: config.seed,
      duration: config.duration,
      modeType: config.modeType,
      opponentName: config.opponent.displayName,
      outcome: _result!.outcome.name,
    );
  }

  @override
  void dispose() {
    playerState.dispose();
    opponentState.dispose();
    super.dispose();
  }
}
