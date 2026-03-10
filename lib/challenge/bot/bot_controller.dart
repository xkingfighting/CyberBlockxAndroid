import '../../core/game_state.dart';
import '../../core/tetromino.dart';
import '../models/match_config.dart';
import 'bot_evaluator.dart';
import 'bot_input_scheduler.dart';

/// Drives the opponent's GameState using AI decisions.
///
/// The bot:
/// 1. Observes the current piece and board
/// 2. Evaluates all placements via BotEvaluator
/// 3. Schedules humanized inputs via BotInputScheduler
/// 4. Executes inputs on the GameState at scheduled times
class BotController {
  final GameState gameState;
  final BotProfileConfig profile;

  late final BotEvaluator _evaluator;
  late final BotInputScheduler _scheduler;

  /// Queued inputs for the current piece.
  List<ScheduledInput> _pendingInputs = [];

  /// Whether we've already planned for the current piece.
  TetrominoType? _lastPlannedPiece;
  int _lastPlannedPieceCount = -1;

  /// Accumulated time in seconds.
  double _elapsed = 0;

  BotController({
    required this.gameState,
    required this.profile,
  }) {
    _evaluator = BotEvaluator(aggressiveness: profile.aggressiveness);
    _scheduler = BotInputScheduler(profile: profile);
  }

  /// Called every frame. Evaluates and executes bot inputs.
  void update(double dt) {
    if (gameState.phase != GamePhase.playing) return;

    _elapsed += dt;

    // Plan inputs for the current piece if we haven't yet
    _planIfNeeded();

    // Execute any pending inputs whose time has come
    _executePendingInputs();
  }

  /// Plan the bot's moves for the current piece.
  void _planIfNeeded() {
    final piece = gameState.currentPiece;
    if (piece == null) return;

    // Don't re-plan for the same piece
    if (piece.type == _lastPlannedPiece &&
        gameState.piecesPlaced == _lastPlannedPieceCount) {
      return;
    }

    _lastPlannedPiece = piece.type;
    _lastPlannedPieceCount = gameState.piecesPlaced;
    _pendingInputs.clear();

    // Evaluate best placement
    final placement = _evaluator.findBestPlacement(
      gameState.board,
      piece.type,
      mistakeRate: profile.mistakeRate,
    );

    if (placement == null) {
      // No valid placement - just hard drop (game over soon)
      _pendingInputs.add(ScheduledInput(
        action: 'hard_drop',
        executeAt: _elapsed + 0.3,
      ));
      return;
    }

    // Schedule humanized inputs
    _pendingInputs = _scheduler.scheduleInputs(
      currentX: piece.x,
      currentRotation: piece.rotation,
      targetX: placement.x,
      targetRotation: placement.rotation,
      startTime: _elapsed,
    );
  }

  /// Execute inputs that are due.
  void _executePendingInputs() {
    while (_pendingInputs.isNotEmpty) {
      final next = _pendingInputs.first;
      if (_elapsed < next.executeAt) break;

      _pendingInputs.removeAt(0);

      // Verify game is still playing (piece might have locked from gravity)
      if (gameState.phase != GamePhase.playing || gameState.currentPiece == null) {
        _pendingInputs.clear();
        _lastPlannedPiece = null; // Force re-plan
        return;
      }

      _executeAction(next.action);
    }
  }

  /// Execute a single bot action on the GameState.
  void _executeAction(String action) {
    switch (action) {
      case 'left':
        gameState.moveLeft();
      case 'right':
        gameState.moveRight();
      case 'rotate_cw':
        gameState.rotateClockwise();
      case 'rotate_ccw':
        gameState.rotateCounterClockwise();
      case 'hard_drop':
        gameState.hardDrop();
      case 'soft_drop':
        gameState.softDrop();
      case 'hold':
        gameState.hold();
    }
  }

  /// Reset bot state (e.g., when starting a new match).
  void reset() {
    _pendingInputs.clear();
    _lastPlannedPiece = null;
    _lastPlannedPieceCount = -1;
    _elapsed = 0;
  }
}
