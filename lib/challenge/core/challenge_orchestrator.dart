import 'package:flutter/foundation.dart';
import '../../core/game_state.dart';
import '../../core/board.dart';
import '../models/match_config.dart';
import '../models/match_state.dart';
import '../models/opponent_projection.dart';
import '../models/challenge_result.dart';
import '../bot/bot_controller.dart';
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
    }
  }

  /// Start the match countdown.
  void startCountdown() {
    _phase = MatchPhase.countdown;
    _countdownSeconds = 3.0;
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

    notifyListeners();
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

    _opponentProjection = OpponentProjection(
      boardGrid: _extractBoolGrid(opponentState.board),
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

  /// Extract a boolean grid from a Board for ghost rendering.
  List<List<bool>> _extractBoolGrid(Board board) {
    final grid = <List<bool>>[];
    for (int y = board.height - 1; y >= 0; y--) {
      final row = <bool>[];
      for (int x = 0; x < board.width; x++) {
        row.add(board.getCell(x, y).filled);
      }
      grid.add(row);
    }
    return grid;
  }

  // -- Player input proxies --
  // These forward to playerState so the game screen can call them.
  // All inputs are blocked while the player is paused.

  void playerMoveLeft() { if (!_playerPaused) playerState.moveLeft(); }
  void playerMoveRight() { if (!_playerPaused) playerState.moveRight(); }
  void playerSoftDrop() { if (!_playerPaused) playerState.softDrop(); }
  void playerHardDrop() { if (!_playerPaused) playerState.hardDrop(); }
  void playerRotateCW() { if (!_playerPaused) playerState.rotateClockwise(); }
  void playerRotateCCW() { if (!_playerPaused) playerState.rotateCounterClockwise(); }
  void playerHold() { if (!_playerPaused) playerState.hold(); }

  @override
  void dispose() {
    playerState.dispose();
    opponentState.dispose();
    super.dispose();
  }
}
