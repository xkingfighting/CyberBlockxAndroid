import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../core/game_state.dart';
import '../../game/cyber_blockx_game.dart';
import '../../services/audio_manager.dart';
import '../../services/leaderboard_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/global_leaderboard_service.dart';
import '../../challenge/core/seeded_random_bag.dart';
import '../../challenge/replay/replay_recorder.dart';
import '../../challenge/replay/replay_data.dart';
import '../../challenge/replay/replay_storage.dart';
import '../../challenge/ui/screens/replay_screen.dart';
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

  // Game screenshot for share card background
  final GlobalKey _gameBoundaryKey = GlobalKey();
  Uint8List? _gameScreenshot;

  // Replay recording
  int _gameSeed = 0;
  final ReplayRecorder _replayRecorder = ReplayRecorder();
  ReplayData? _lastReplayData;

  // High score dialog state
  bool _showHighScoreDialog = false;
  bool _highScoreSubmitted = false;
  bool _scoreSynced = false; // Whether the score was synced to cloud
  ScoreSubmitResponse? _syncedSubmitResult; // Full response from cloud sync
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
    // Resume Flame engine if it was paused (game over / pause)
    if (_game.paused) {
      _game.resumeEngine();
    }

    // Generate deterministic seed for replay
    _gameSeed = DateTime.now().microsecondsSinceEpoch ^ Random().nextInt(2147483647);
    _gameState.setPieceBag(SeededRandomBag(_gameSeed));

    _gameState.startGame();

    // Start replay recording
    _replayRecorder.start();
    _lastReplayData = null;

    _maxCombo = 0;
    _gameStartTime = DateTime.now();
    _gameScreenshot = null;
    _showHighScoreDialog = false;
    _highScoreSubmitted = false;
    _scoreSynced = false;
    _syncedSubmitResult = null;
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
    _gameScreenshot = null; // Release screenshot memory
    super.dispose();
  }

  void _onGameStateChanged() {
    // Track max combo
    if (_gameState.scoring.combo > _maxCombo) {
      _maxCombo = _gameState.scoring.combo;
    }

    // Handle game events (wrapped in try/catch for resilience —
    // if any event handler throws, we still want capture + setState to run)
    try {
      final events = _gameState.popEvents();
      for (final event in events) {
        _handleGameEvent(event);
      }
    } catch (e) {
      debugPrint('ShareCard: Event handler error: $e');
    }

    // Phase-based game over detection (outside event loop for reliability)
    // This ensures capture + checkHighScore run even if an earlier event handler threw
    if (_gameState.phase == GamePhase.gameOver && _gameScreenshot == null && !_highScoreSubmitted) {
      debugPrint('ShareCard: Phase gameOver detected, triggering capture + high score check');

      // Stop replay recording and finalize
      if (_replayRecorder.isRecording) {
        _replayRecorder.stop();
        _finalizeAndSaveReplay();
      }

      try {
        _captureGameScreen();
      } catch (e) {
        debugPrint('ShareCard: Phase capture error: $e');
      }
      if (!_showHighScoreDialog && !_highScoreSubmitted) {
        _checkHighScore();
      }
    }

    // Pause/resume Flame engine based on game phase to free up GPU/CPU
    _syncEngineState();

    setState(() {});
  }

  /// Pause Flame rendering when overlays are shown, resume when playing
  void _syncEngineState() {
    final shouldPause = _gameState.phase == GamePhase.paused ||
        _gameState.phase == GamePhase.gameOver;
    if (shouldPause && !_game.paused) {
      _game.pauseEngine();
    } else if (!shouldPause && _game.paused) {
      _game.resumeEngine();
    }
  }

  /// Capture the game board as a screenshot for the share card background.
  /// Uses OffsetLayer.toImageSync for synchronous capture that works reliably
  /// even during notifyListeners() callbacks.
  void _captureGameScreen() {
    debugPrint('ShareCard: >>> _captureGameScreen() called');
    try {
      final boundary = _gameBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('ShareCard: RepaintBoundary is null, cannot capture');
        return;
      }

      // Use synchronous capture via OffsetLayer.toImageSync
      // This avoids async timing issues with toImage() during notifyListeners
      final layer = boundary.layer as OffsetLayer?;
      if (layer == null) {
        debugPrint('ShareCard: boundary.layer is null, cannot capture');
        return;
      }

      debugPrint('ShareCard: Capturing synchronously, bounds=${boundary.paintBounds}');
      final image = layer.toImageSync(boundary.paintBounds, pixelRatio: 2.0);
      debugPrint('ShareCard: Sync capture OK: ${image.width}x${image.height}');

      // Convert to PNG bytes asynchronously (just encoding, not rendering)
      image.toByteData(format: ui.ImageByteFormat.png).then((byteData) {
        image.dispose();
        if (mounted && byteData != null) {
          debugPrint('ShareCard: PNG ready, ${byteData.lengthInBytes} bytes');
          setState(() {
            _gameScreenshot = byteData.buffer.asUint8List();
          });
        } else {
          debugPrint('ShareCard: toByteData failed - mounted=$mounted, byteData=${byteData != null}');
        }
      }).catchError((e) {
        image.dispose(); // Ensure image is disposed even on error
        debugPrint('ShareCard: toByteData error: $e');
      });
    } catch (e) {
      debugPrint('ShareCard: Capture error: $e');
    }
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
        level: _gameState.scoring.level,
        source: 'game_daily',
        integrity: _gameState.getIntegrityData(),
      );
      if (result != null) {
        debugPrint('GameScreen: Score uploaded successfully, isNewRecord=${result.isNewRecord}, rank=${result.rank}');
        didSync = true;
        _syncedSubmitResult = result;
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
        // Note: _captureGameScreen() and _checkHighScore() are now called
        // from the phase-based detection in _onGameStateChanged() for reliability
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
    // Version marker: appears every time widget builds during game over
    if (_gameState.phase == GamePhase.gameOver) {
      debugPrint('ShareCard: [v5] BUILD phase=gameOver, screenshot=${_gameScreenshot != null ? "HAS_DATA(${_gameScreenshot!.length}b)" : "NULL"}, highScoreDialog=$_showHighScoreDialog');
    }
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
                          child: RepaintBoundary(
                            key: _gameBoundaryKey,
                            child: GameWidget(game: _game),
                          ),
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
                          _replayRecorder.recordPlayerAction(ReplayAction.left);
                        }
                      },
                      onMoveRight: () {
                        if (_gameState.moveRight()) {
                          _audio.playSound(GameSound.move);
                          _replayRecorder.recordPlayerAction(ReplayAction.right);
                        }
                      },
                      onSoftDrop: () {
                        if (_gameState.softDrop()) {
                          _audio.playSound(GameSound.move);
                          _replayRecorder.recordPlayerAction(ReplayAction.softDrop);
                        }
                      },
                      onHardDrop: () {
                        _gameState.hardDrop();
                        _replayRecorder.recordPlayerAction(ReplayAction.hardDrop);
                      },
                      onRotateCW: () {
                        if (_gameState.rotateClockwise()) {
                          _audio.playSound(GameSound.rotate);
                          _replayRecorder.recordPlayerAction(ReplayAction.rotateCW);
                        }
                      },
                      onRotateCCW: () {
                        if (_gameState.rotateCounterClockwise()) {
                          _audio.playSound(GameSound.rotate);
                          _replayRecorder.recordPlayerAction(ReplayAction.rotateCCW);
                        }
                      },
                      onHold: () {
                        _audio.playSound(GameSound.hold);
                        _gameState.hold();
                        _replayRecorder.recordPlayerAction(ReplayAction.hold);
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
                  level: _gameState.scoring.level,
                  lines: _gameState.scoring.totalLines,
                  rank: _scoreRank,
                  playTime: _playTime,
                  gameScreenshot: _gameScreenshot,
                  onSkip: () {
                    _submitScore('Player');
                  },
                  onSubmit: (name, syncToCloud) async {
                    if (_highScoreSubmitted) return null;
                    _highScoreSubmitted = true;

                    ScoreSubmitResponse? result;
                    bool didSync = false;

                    // Upload to cloud if requested
                    if (syncToCloud && AuthService.instance.isBound) {
                      result = await GlobalLeaderboardService.instance.submitScore(
                        score: _gameState.scoring.score,
                        lines: _gameState.scoring.totalLines,
                        level: _gameState.scoring.level,
                        source: 'game_daily',
                        integrity: _gameState.getIntegrityData(),
                      );
                      if (result != null) {
                        didSync = true;
                        _syncedSubmitResult = result;
                      }
                    }

                    // Save to local leaderboard
                    await LeaderboardService.instance.addScore(
                      score: _gameState.scoring.score,
                      level: _gameState.scoring.level,
                      lines: _gameState.scoring.totalLines,
                      name: name,
                      isSynced: didSync,
                    );

                    setState(() {
                      _scoreSynced = didSync;
                    });

                    return result;
                  },
                  onContinue: () {
                    setState(() {
                      _showHighScoreDialog = false;
                    });
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
                  syncedResult: _syncedSubmitResult,
                  integrity: _gameState.getIntegrityData(),
                  gameScreenshot: _gameScreenshot,
                  replayData: _lastReplayData,
                  onWatchReplay: _lastReplayData != null ? _watchReplay : null,
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

  /// Finalize replay data and save locally + upload to server.
  void _finalizeAndSaveReplay() {
    final replay = _replayRecorder.finalize(
      matchId: _gameState.gameToken,
      seed: _gameSeed,
      duration: _gameState.gameDurationSeconds,
      modeType: 'solo',
      opponentName: '',
      outcome: 'game_over',
    );
    _lastReplayData = replay;

    // Save locally
    ReplayStorage.save(replay);

    // Upload to server (fire-and-forget)
    ReplayStorage.uploadSoloReplay(
      replay,
      score: _gameState.scoring.score,
      lines: _gameState.scoring.totalLines,
      level: _gameState.scoring.level,
    );

    debugPrint('[GameScreen] Replay finalized: ${replay.playerActions.length} actions, '
        'seed=$_gameSeed, duration=${replay.duration}s');
  }

  /// Navigate to replay viewer for the last game.
  void _watchReplay() {
    if (_lastReplayData == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReplayScreen(
          replay: _lastReplayData!,
          onClose: () => Navigator.of(context).pop(),
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
          _replayRecorder.recordPlayerAction(ReplayAction.left);
        }
        break;
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.keyD:
        if (_gameState.moveRight()) {
          _audio.playSound(GameSound.move);
          _replayRecorder.recordPlayerAction(ReplayAction.right);
        }
        break;
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.keyS:
        if (_gameState.softDrop()) {
          _audio.playSound(GameSound.move);
          _replayRecorder.recordPlayerAction(ReplayAction.softDrop);
        }
        break;
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyW:
      case LogicalKeyboardKey.keyX:
        if (_gameState.rotateClockwise()) {
          _audio.playSound(GameSound.rotate);
          _replayRecorder.recordPlayerAction(ReplayAction.rotateCW);
        }
        break;
      case LogicalKeyboardKey.keyZ:
        if (_gameState.rotateCounterClockwise()) {
          _audio.playSound(GameSound.rotate);
          _replayRecorder.recordPlayerAction(ReplayAction.rotateCCW);
        }
        break;
      case LogicalKeyboardKey.space:
        _gameState.hardDrop();
        _replayRecorder.recordPlayerAction(ReplayAction.hardDrop);
        break;
      case LogicalKeyboardKey.keyC:
      case LogicalKeyboardKey.shiftLeft:
        _audio.playSound(GameSound.hold);
        _gameState.hold();
        _replayRecorder.recordPlayerAction(ReplayAction.hold);
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
