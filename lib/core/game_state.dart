import 'dart:math';
import 'package:flutter/foundation.dart';
import 'tetromino.dart';
import 'board.dart';

/// Game phases
enum GamePhase { menu, playing, paused, gameOver }

/// Game events for audio/visual feedback
enum GameEvent {
  pieceLocked,
  linesCleared,
  levelUp,
  gameOver,
  tetris,
  combo,
  perfectClear,
}

/// Scoring system
class Scoring {
  int score = 0;
  int level = 1;
  int totalLines = 0;
  int combo = 0;
  int backToBack = 0; // Track consecutive Tetris for bonus

  /// Lines needed to advance to next level
  int get linesToNextLevel => level * 10 - totalLines;

  /// Calculate drop speed based on level (in seconds)
  /// Uses official Tetris Guideline formula matching iOS
  double get dropInterval {
    // Formula based on Tetris Guideline
    // Level 1: ~1 second, Level 15+: very fast
    const baseSpeed = 1.0;
    final speedFactor = pow(0.8 - (level - 1) * 0.007, level - 1);
    return max(baseSpeed * speedFactor, 0.016); // Min ~60fps
  }

  /// Add score for cleared lines
  int addLinesCleared(int lines, {bool perfectClear = false}) {
    if (lines == 0) {
      combo = 0;
      return 0;
    }

    totalLines += lines;

    // Base score calculation
    int baseScore;
    switch (lines) {
      case 1:
        baseScore = 100;
        break;
      case 2:
        baseScore = 300;
        break;
      case 3:
        baseScore = 500;
        break;
      case 4:
        baseScore = 800; // Tetris!
        break;
      default:
        baseScore = 0;
    }

    // Apply multipliers
    int points = baseScore * level;

    // Combo bonus (iOS: checks if combo > 0 before adding)
    if (combo > 0) {
      points += 50 * combo * level;
    }
    combo++;

    // Back-to-back bonus for Tetris (4 lines) - matching iOS
    if (lines == 4) {
      if (backToBack > 0) {
        points = (points * 1.5).toInt();
      }
      backToBack++;
    } else {
      backToBack = 0;
    }

    // Perfect clear bonus
    if (perfectClear) {
      points += 1000 * level;
    }

    score += points;

    // Check for level up (iOS formula: newLevel = (totalLines / 10) + 1)
    final newLevel = (totalLines ~/ 10) + 1;
    if (newLevel > level) {
      level = newLevel;
    }

    return points;
  }

  /// Add score for soft drop
  void addSoftDrop(int cells) {
    score += cells;
  }

  /// Add score for hard drop
  void addHardDrop(int cells) {
    score += cells * 2;
  }

  void reset() {
    score = 0;
    level = 1;
    totalLines = 0;
    combo = 0;
    backToBack = 0;
  }
}

/// Main game state manager
class GameState extends ChangeNotifier {
  final Board board = Board();
  final Scoring scoring = Scoring();
  final Random _random = Random();

  GamePhase _phase = GamePhase.menu;
  Tetromino? _currentPiece;
  Tetromino? _holdPiece;
  List<TetrominoType> _previewQueue = [];
  List<TetrominoType> _bag = [];

  bool _canHold = true;
  double _dropTimer = 0;
  double _lockDelayTimer = 0;
  bool _isLocking = false;
  int _lockMoves = 0;

  // Lock delay settings
  static const double lockDelay = 0.5;
  static const int maxLockMoves = 15;

  // Events queue
  final List<GameEvent> _eventQueue = [];

  // Last locked piece info for visual effects
  Tetromino? _lastLockedPiece;

  // Last cleared rows for line clear animation
  List<int> _lastClearedRows = [];

  // Getters
  GamePhase get phase => _phase;
  Tetromino? get currentPiece => _currentPiece;
  TetrominoType? get holdPiece => _holdPiece?.type;
  List<TetrominoType> get previewQueue => _previewQueue.take(5).toList();
  bool get canHold => _canHold;
  Tetromino? get lastLockedPiece => _lastLockedPiece;
  List<int> get lastClearedRows => _lastClearedRows;

  /// Start a new game
  void startGame() {
    board.clear();
    scoring.reset();
    _holdPiece = null;
    _canHold = true;
    _bag.clear();
    _previewQueue.clear();
    _eventQueue.clear();

    // Fill preview queue
    _refillBag();
    for (int i = 0; i < 5; i++) {
      _previewQueue.add(_getNextFromBag());
    }

    // Spawn first piece
    _spawnPiece();

    _phase = GamePhase.playing;
    notifyListeners();
  }

  /// Update game state (called every frame)
  void update(double deltaTime) {
    if (_phase != GamePhase.playing || _currentPiece == null) return;

    // Handle lock delay
    if (_isLocking) {
      _lockDelayTimer += deltaTime;
      if (_lockDelayTimer >= lockDelay) {
        _lockPiece();
      }
      return;
    }

    // Handle gravity
    _dropTimer += deltaTime;
    if (_dropTimer >= scoring.dropInterval) {
      _dropTimer = 0;
      if (!_moveDown()) {
        _startLockDelay();
      }
    }
  }

  /// Move piece left
  bool moveLeft() {
    if (_currentPiece == null || _phase != GamePhase.playing) return false;

    _currentPiece!.x--;
    if (!board.canPlace(_currentPiece!)) {
      _currentPiece!.x++;
      return false;
    }

    _resetLockDelayIfNeeded();
    notifyListeners();
    return true;
  }

  /// Move piece right
  bool moveRight() {
    if (_currentPiece == null || _phase != GamePhase.playing) return false;

    _currentPiece!.x++;
    if (!board.canPlace(_currentPiece!)) {
      _currentPiece!.x--;
      return false;
    }

    _resetLockDelayIfNeeded();
    notifyListeners();
    return true;
  }

  /// Move piece down (soft drop)
  bool softDrop() {
    if (_currentPiece == null || _phase != GamePhase.playing) return false;

    if (_moveDown()) {
      scoring.addSoftDrop(1);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Hard drop
  void hardDrop() {
    if (_currentPiece == null || _phase != GamePhase.playing) return;

    int dropDistance = 0;
    while (_moveDown()) {
      dropDistance++;
    }
    scoring.addHardDrop(dropDistance);
    _lockPiece();
  }

  /// Rotate clockwise
  bool rotateClockwise() {
    return _tryRotate(true);
  }

  /// Rotate counter-clockwise
  bool rotateCounterClockwise() {
    return _tryRotate(false);
  }

  /// Hold current piece
  void hold() {
    if (_currentPiece == null || !_canHold || _phase != GamePhase.playing) return;

    final currentType = _currentPiece!.type;

    if (_holdPiece == null) {
      _holdPiece = Tetromino(type: currentType, x: 0, y: 0);
      _spawnPiece();
    } else {
      final holdType = _holdPiece!.type;
      _holdPiece = Tetromino(type: currentType, x: 0, y: 0);
      _spawnPiece(type: holdType);
    }

    _canHold = false;
    notifyListeners();
  }

  /// Pause the game
  void togglePause() {
    if (_phase == GamePhase.playing) {
      _phase = GamePhase.paused;
    } else if (_phase == GamePhase.paused) {
      _phase = GamePhase.playing;
    }
    notifyListeners();
  }

  /// Resume from pause
  void resumeGame() {
    if (_phase == GamePhase.paused) {
      _phase = GamePhase.playing;
      notifyListeners();
    }
  }

  /// Return to menu
  void returnToMenu() {
    _phase = GamePhase.menu;
    notifyListeners();
  }

  /// Get and clear events
  List<GameEvent> popEvents() {
    final events = List<GameEvent>.from(_eventQueue);
    _eventQueue.clear();
    return events;
  }

  /// Get ghost piece position
  Tetromino? getGhostPiece() {
    if (_currentPiece == null) return null;

    final ghost = _currentPiece!.copy();
    while (board.canPlace(ghost)) {
      ghost.y--;
    }
    ghost.y++;
    return ghost;
  }

  // Private methods

  bool _moveDown() {
    if (_currentPiece == null) return false;

    _currentPiece!.y--;
    if (!board.canPlace(_currentPiece!)) {
      _currentPiece!.y++;
      return false;
    }
    return true;
  }

  bool _tryRotate(bool clockwise) {
    if (_currentPiece == null || _phase != GamePhase.playing) return false;

    final originalRotation = _currentPiece!.rotation;

    if (clockwise) {
      _currentPiece!.rotateClockwise();
    } else {
      _currentPiece!.rotateCounterClockwise();
    }

    // Try wall kicks
    final kicks = WallKickData.getKicks(
      _currentPiece!.type,
      originalRotation,
      clockwise,
    );

    for (final kick in kicks) {
      _currentPiece!.x += kick.x.toInt();
      _currentPiece!.y += kick.y.toInt();

      if (board.canPlace(_currentPiece!)) {
        _resetLockDelayIfNeeded();
        notifyListeners();
        return true;
      }

      _currentPiece!.x -= kick.x.toInt();
      _currentPiece!.y -= kick.y.toInt();
    }

    // Rotation failed, restore original
    _currentPiece!.rotation = originalRotation;
    return false;
  }

  void _startLockDelay() {
    _isLocking = true;
    _lockDelayTimer = 0;
  }

  void _resetLockDelayIfNeeded() {
    if (_isLocking && _lockMoves < maxLockMoves) {
      _lockDelayTimer = 0;
      _lockMoves++;
    }
  }

  void _lockPiece() {
    if (_currentPiece == null) return;

    // Store the locked piece for visual effects
    _lastLockedPiece = _currentPiece!.copy();

    board.lockPiece(_currentPiece!);
    _eventQueue.add(GameEvent.pieceLocked);

    // Store cleared rows before clearing them (for animation)
    _lastClearedRows = board.getFullLines();

    // Check for line clears
    final linesCleared = board.clearLines();
    if (linesCleared > 0) {
      final prevLevel = scoring.level;
      final isPerfectClear = board.isEmpty();

      scoring.addLinesCleared(linesCleared, perfectClear: isPerfectClear);

      _eventQueue.add(GameEvent.linesCleared);

      if (linesCleared == 4) {
        _eventQueue.add(GameEvent.tetris);
      }
      if (scoring.combo > 1) {
        _eventQueue.add(GameEvent.combo);
      }
      if (isPerfectClear) {
        _eventQueue.add(GameEvent.perfectClear);
      }
      if (scoring.level > prevLevel) {
        _eventQueue.add(GameEvent.levelUp);
      }
    } else {
      // No lines cleared - reset combo (matching iOS behavior)
      scoring.addLinesCleared(0);
    }

    // Reset lock state
    _isLocking = false;
    _lockDelayTimer = 0;
    _lockMoves = 0;
    _canHold = true;

    // Spawn next piece
    _spawnPiece();
  }

  void _spawnPiece({TetrominoType? type}) {
    final pieceType = type ?? _getNextFromBag();
    if (type == null) {
      _previewQueue.removeAt(0);
      _previewQueue.add(_getNextFromBag());
    }

    _currentPiece = Tetromino(
      type: pieceType,
      x: pieceType.spawnOffset,
      y: board.height - 1,
    );

    _dropTimer = 0;

    // Check for game over
    if (!board.canPlace(_currentPiece!)) {
      _phase = GamePhase.gameOver;
      _eventQueue.add(GameEvent.gameOver);
    }

    notifyListeners();
  }

  TetrominoType _getNextFromBag() {
    if (_bag.isEmpty) {
      _refillBag();
    }
    return _bag.removeLast();
  }

  void _refillBag() {
    _bag = List.from(TetrominoType.values);
    _bag.shuffle(_random);
  }
}
