import 'package:flutter/foundation.dart';
import '../../core/game_state.dart';
import '../../core/board.dart';
import '../models/match_state.dart';
import '../models/opponent_projection.dart';
import '../core/seeded_random_bag.dart';
import 'replay_data.dart';

/// Orchestrates replay playback of a recorded challenge match.
///
/// Creates two fresh GameState instances from the same seed,
/// then replays recorded actions at their original timestamps.
/// Supports pause, resume, and speed control (1x/2x/4x).
class ReplayOrchestrator extends ChangeNotifier {
  final ReplayData replay;

  /// Player's game state (replayed from recorded actions).
  late final GameState playerState;

  /// Opponent's game state (replayed from recorded actions).
  late final GameState opponentState;

  /// Playback lifecycle.
  MatchPhase _phase = MatchPhase.idle;
  MatchPhase get phase => _phase;

  /// Countdown timer.
  double _countdownSeconds = 3.0;
  double get countdownSeconds => _countdownSeconds;

  /// Current playback time in milliseconds (relative to match start).
  double _currentTimeMs = 0;
  double get currentTimeMs => _currentTimeMs;

  /// Playback speed multiplier (1.0, 2.0, or 4.0).
  double _speed = 1.0;
  double get speed => _speed;

  /// Whether playback is paused.
  bool _paused = false;
  bool get isPaused => _paused;

  /// Index of next player action to execute.
  int _playerActionIndex = 0;

  /// Index of next opponent action to execute.
  int _opponentActionIndex = 0;

  /// Total duration for progress calculation.
  int get totalDurationMs => replay.totalDurationMs;

  /// Playback progress (0.0 – 1.0).
  double get progress {
    if (totalDurationMs <= 0) return 1.0;
    return (_currentTimeMs / totalDurationMs).clamp(0.0, 1.0);
  }

  /// Opponent projection for ghost board rendering.
  OpponentProjection _opponentProjection = OpponentProjection.empty();
  OpponentProjection get opponentProjection => _opponentProjection;

  /// Recent clear decay timer for ghost visual effect.
  double _clearDecayTimer = 0;
  List<int> _recentClearRows = [];

  ReplayOrchestrator({required this.replay}) {
    // Create both game states with the same seeded random bag
    final playerBag = SeededRandomBag(replay.seed);
    final opponentBag = SeededRandomBag(replay.seed);

    playerState = GameState(pieceBag: playerBag);
    opponentState = GameState(pieceBag: opponentBag);
  }

  /// Start the replay countdown.
  void startCountdown() {
    _phase = MatchPhase.countdown;
    _countdownSeconds = 3.0;
    notifyListeners();
  }

  /// Called every frame by the game loop.
  void update(double dt) {
    switch (_phase) {
      case MatchPhase.countdown:
        _updateCountdown(dt);
      case MatchPhase.playing:
        if (!_paused) {
          _updatePlaying(dt);
        }
      default:
        break;
    }
  }

  void _updateCountdown(double dt) {
    _countdownSeconds -= dt;
    if (_countdownSeconds <= 0) {
      _startPlayback();
    }
    notifyListeners();
  }

  void _startPlayback() {
    _phase = MatchPhase.playing;
    _currentTimeMs = 0;
    _playerActionIndex = 0;
    _opponentActionIndex = 0;

    playerState.startGame();
    opponentState.startGame();

    notifyListeners();
  }

  void _updatePlaying(double dt) {
    final adjustedDt = dt * _speed;
    _currentTimeMs += adjustedDt * 1000;

    // Update game physics (gravity, lock delay)
    playerState.update(adjustedDt);
    opponentState.update(adjustedDt);

    // Execute player actions up to current time
    while (_playerActionIndex < replay.playerActions.length) {
      final action = replay.playerActions[_playerActionIndex];
      if (action.timestampMs > _currentTimeMs) break;
      _executeAction(playerState, action.actionCode);
      _playerActionIndex++;
    }

    // Execute opponent actions up to current time
    while (_opponentActionIndex < replay.opponentActions.length) {
      final action = replay.opponentActions[_opponentActionIndex];
      if (action.timestampMs > _currentTimeMs) break;
      _executeAction(opponentState, action.actionCode);
      _opponentActionIndex++;
    }

    // Update opponent projection
    _updateOpponentProjection(adjustedDt);

    // Check if replay is complete
    if (_playerActionIndex >= replay.playerActions.length &&
        _opponentActionIndex >= replay.opponentActions.length &&
        _currentTimeMs >= totalDurationMs) {
      _finishPlayback();
    }

    notifyListeners();
  }

  /// Execute a single action on a GameState.
  void _executeAction(GameState state, int actionCode) {
    if (state.phase != GamePhase.playing) return;
    switch (actionCode) {
      case ReplayAction.left:
        state.moveLeft();
      case ReplayAction.right:
        state.moveRight();
      case ReplayAction.rotateCW:
        state.rotateClockwise();
      case ReplayAction.rotateCCW:
        state.rotateCounterClockwise();
      case ReplayAction.hardDrop:
        state.hardDrop();
      case ReplayAction.softDrop:
        state.softDrop();
      case ReplayAction.hold:
        state.hold();
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
        _clearDecayTimer = 0.5;
      }
    }

    _opponentProjection = OpponentProjection(
      boardGrid: _extractBoolGrid(opponentState.board),
      score: opponentState.scoring.score,
      level: opponentState.scoring.level,
      lines: opponentState.scoring.totalLines,
      isAlive: opponentState.phase != GamePhase.gameOver,
      opacity: 0.28,
      recentClearRows: _recentClearRows,
      recentClearDecay: _clearDecayTimer.clamp(0, 1),
    );
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

  void _finishPlayback() {
    _phase = MatchPhase.result;
    notifyListeners();
  }

  // -- Playback Controls --

  /// Toggle pause/resume.
  void togglePause() {
    if (_phase != MatchPhase.playing) return;
    _paused = !_paused;
    notifyListeners();
  }

  /// Set playback speed (1.0, 2.0, or 4.0).
  void setSpeed(double newSpeed) {
    _speed = newSpeed.clamp(1.0, 4.0);
    notifyListeners();
  }

  @override
  void dispose() {
    playerState.dispose();
    opponentState.dispose();
    super.dispose();
  }
}
