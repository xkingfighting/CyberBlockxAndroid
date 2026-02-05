import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/game_state.dart';
import '../../game/cyber_blockx_game.dart';
import '../../services/audio_manager.dart';
import '../../services/leaderboard_service.dart';
import '../../services/auth_service.dart';
import '../../services/global_leaderboard_service.dart';
import '../theme/cyber_theme.dart';
import '../widgets/game_hud.dart';
import '../widgets/touch_controls.dart';
import '../widgets/pause_overlay.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/high_score_overlay.dart';
import 'settings_screen.dart';

class GameScreen extends StatefulWidget {
  final VoidCallback onReturnToMenu;
  final VoidCallback? onShowLeaderboard;

  const GameScreen({
    super.key,
    required this.onReturnToMenu,
    this.onShowLeaderboard,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState _gameState;
  late CyberBlockxGame _game;
  final FocusNode _focusNode = FocusNode();
  final AudioManager _audio = AudioManager.instance;

  // Track game stats
  int _maxCombo = 0;
  DateTime? _gameStartTime;

  // High score dialog state
  bool _showHighScoreDialog = false;
  bool _highScoreSubmitted = false;
  bool _scoreSynced = false; // Whether the score was synced to cloud
  int _scoreRank = 0;

  @override
  void initState() {
    super.initState();
    _gameState = GameState();
    _game = CyberBlockxGame(gameState: _gameState);
    _startNewGame();
    _gameState.addListener(_onGameStateChanged);

    // Start background music
    _audio.onGameStart();
  }

  void _startNewGame() {
    _gameState.startGame();
    _maxCombo = 0;
    _gameStartTime = DateTime.now();
    _showHighScoreDialog = false;
    _highScoreSubmitted = false;
    _scoreSynced = false;
    _scoreRank = 0;
  }

  Duration? get _playTime {
    if (_gameStartTime == null) return null;
    return DateTime.now().difference(_gameStartTime!);
  }

  @override
  void dispose() {
    _gameState.removeListener(_onGameStateChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    // Track max combo
    if (_gameState.scoring.combo > _maxCombo) {
      _maxCombo = _gameState.scoring.combo;
    }

    // Handle game events
    final events = _gameState.popEvents();
    for (final event in events) {
      _handleGameEvent(event);
    }
    setState(() {});
  }

  void _checkHighScore() {
    final score = _gameState.scoring.score;
    final leaderboard = LeaderboardService.instance;

    // Check if score qualifies for leaderboard
    if (leaderboard.isHighScore(score)) {
      // Calculate potential rank
      final entries = leaderboard.entries;
      int rank = 1;
      for (final entry in entries) {
        if (score > entry.score) break;
        rank++;
      }

      setState(() {
        _scoreRank = rank;
        _showHighScoreDialog = true;
      });
    } else {
      // Not a high score, just save with default name
      _submitScore('Player');
    }
  }

  Future<void> _submitScore(String name, {bool syncToCloud = false, bool navigateToLeaderboard = false}) async {
    if (_highScoreSubmitted) return;
    _highScoreSubmitted = true;

    bool didSync = false;

    // Upload to cloud if requested
    if (syncToCloud && AuthService.instance.isBound) {
      debugPrint('GameScreen: Uploading score to cloud...');
      final result = await GlobalLeaderboardService.instance.submitScore(
        score: _gameState.scoring.score,
        lines: _gameState.scoring.totalLines,
        source: 'game_daily',
      );
      if (result != null) {
        debugPrint('GameScreen: Score uploaded successfully, isNewRecord=${result.isNewRecord}, rank=${result.rank}');
        didSync = true;
      } else {
        debugPrint('GameScreen: Score upload failed');
      }
    }

    // Save to local leaderboard with sync status
    await LeaderboardService.instance.addScore(
      score: _gameState.scoring.score,
      level: _gameState.scoring.level,
      lines: _gameState.scoring.totalLines,
      name: name,
      isSynced: didSync,
    );

    setState(() {
      _showHighScoreDialog = false;
      _scoreSynced = didSync;
    });

    // Navigate to leaderboard after submitting high score
    if (navigateToLeaderboard && widget.onShowLeaderboard != null) {
      widget.onShowLeaderboard!();
    }
  }

  void _handleGameEvent(GameEvent event) {
    switch (event) {
      case GameEvent.pieceLocked:
        _audio.playSound(GameSound.lock);
        // Trigger visual lock effect with flash and screen shake
        if (_gameState.lastLockedPiece != null) {
          _game.triggerLockEffect(_gameState.lastLockedPiece!);
        }
        break;
      case GameEvent.linesCleared:
        _audio.playSound(GameSound.lineClear);
        // Trigger line clear visual effect
        if (_gameState.lastClearedRows.isNotEmpty) {
          _game.triggerLineClearEffect(_gameState.lastClearedRows);
        }
        break;
      case GameEvent.tetris:
        _audio.playSound(GameSound.tetris);
        break;
      case GameEvent.levelUp:
        _audio.playSound(GameSound.levelUp);
        break;
      case GameEvent.gameOver:
        _audio.onGameOver();
        _checkHighScore();
        break;
      case GameEvent.combo:
        _audio.playSound(GameSound.combo);
        // TODO: Add combo visual effect
        break;
      case GameEvent.perfectClear:
        _audio.playSound(GameSound.perfectClear);
        // TODO: Add perfect clear visual effect
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberColors.background,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            // Game view
            Column(
              children: [
                // Main game area (Left HUD + Game Board + Right HUD)
                Expanded(
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start, // Align tops
                      children: [
                        // Left HUD - Score, Level, Lines
                        LeftHUD(gameState: _gameState),

                        // Game board in center - fills available space
                        Expanded(
                          child: GameWidget(game: _game),
                        ),

                        // Right HUD - Hold + Next
                        RightHUD(gameState: _gameState),
                      ],
                    ),
                  ),
                ),

                // Touch controls at bottom - hide when paused or game over
                if (_gameState.phase == GamePhase.playing)
                SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 200,
                    child: TouchControls(
                      onMoveLeft: () {
                        if (_gameState.moveLeft()) {
                          _audio.playSound(GameSound.move);
                        }
                      },
                      onMoveRight: () {
                        if (_gameState.moveRight()) {
                          _audio.playSound(GameSound.move);
                        }
                      },
                      onSoftDrop: () {
                        if (_gameState.softDrop()) {
                          _audio.playSound(GameSound.move);
                        }
                      },
                      onHardDrop: () {
                        _gameState.hardDrop();
                      },
                      onRotateCW: () {
                        if (_gameState.rotateClockwise()) {
                          _audio.playSound(GameSound.rotate);
                        }
                      },
                      onRotateCCW: () {
                        if (_gameState.rotateCounterClockwise()) {
                          _audio.playSound(GameSound.rotate);
                        }
                      },
                      onHold: () {
                        _audio.playSound(GameSound.hold);
                        _gameState.hold();
                      },
                      onPause: () {
                        _gameState.togglePause();
                        if (_gameState.phase == GamePhase.paused) {
                          _audio.onGamePause();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),

            // Pause overlay - cover entire screen
            if (_gameState.phase == GamePhase.paused)
              Positioned.fill(
                child: PauseOverlay(
                  onResume: () {
                    _gameState.resumeGame();
                    _audio.onGameResume();
                  },
                  onRestart: () {
                    _startNewGame();
                    _audio.onGameStart();
                  },
                  onMenu: widget.onReturnToMenu,
                  onSettings: () => _showSettingsScreen(context),
                ),
              ),

            // High score overlay - show first when qualifying for leaderboard
            if (_gameState.phase == GamePhase.gameOver && _showHighScoreDialog)
              Positioned.fill(
                child: HighScoreOverlay(
                  score: _gameState.scoring.score,
                  rank: _scoreRank,
                  onSkip: () {
                    _submitScore('Player');
                  },
                  onSubmit: (name, syncToCloud) async {
                    await _submitScore(name, syncToCloud: syncToCloud, navigateToLeaderboard: true);
                  },
                ),
              ),

            // Game over overlay - show after high score dialog is dismissed
            if (_gameState.phase == GamePhase.gameOver && !_showHighScoreDialog)
              Positioned.fill(
                child: GameOverOverlay(
                  score: _gameState.scoring.score,
                  level: _gameState.scoring.level,
                  lines: _gameState.scoring.totalLines,
                  maxCombo: _maxCombo,
                  playTime: _playTime,
                  alreadySynced: _scoreSynced,
                  onRestart: () {
                    _startNewGame();
                    _audio.onGameStart();
                  },
                  onMenu: widget.onReturnToMenu,
                  onLeaderboard: () {
                    // Show leaderboard if callback provided, otherwise return to menu
                    if (widget.onShowLeaderboard != null) {
                      widget.onShowLeaderboard!();
                    } else {
                      widget.onReturnToMenu();
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSettingsScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_gameState.phase != GamePhase.playing) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.keyA:
        if (_gameState.moveLeft()) {
          _audio.playSound(GameSound.move);
        }
        break;
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.keyD:
        if (_gameState.moveRight()) {
          _audio.playSound(GameSound.move);
        }
        break;
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.keyS:
        if (_gameState.softDrop()) {
          _audio.playSound(GameSound.move);
        }
        break;
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyW:
      case LogicalKeyboardKey.keyX:
        if (_gameState.rotateClockwise()) {
          _audio.playSound(GameSound.rotate);
        }
        break;
      case LogicalKeyboardKey.keyZ:
        if (_gameState.rotateCounterClockwise()) {
          _audio.playSound(GameSound.rotate);
        }
        break;
      case LogicalKeyboardKey.space:
        _gameState.hardDrop();
        break;
      case LogicalKeyboardKey.keyC:
      case LogicalKeyboardKey.shiftLeft:
        _audio.playSound(GameSound.hold);
        _gameState.hold();
        break;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.keyP:
        _gameState.togglePause();
        if (_gameState.phase == GamePhase.paused) {
          _audio.onGamePause();
        }
        break;
      default:
        break;
    }
  }
}
