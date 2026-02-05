import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Draggable;
import 'package:flutter/services.dart';
import '../core/game_state.dart';
import '../core/tetromino.dart';
import '../services/visual_settings.dart';

/// Main game component using Flame engine
class CyberBlockxGame extends FlameGame {
  final GameState gameState;

  // Board rendering parameters
  late double blockSize;
  late Vector2 boardOrigin;
  late Vector2 boardSize;

  // Colors
  static const gridColor = Color(0xFF1A1A2E);
  static const gridLineColor = Color(0xFF16213E);
  static const glowColor = Color(0xFF00FFFF);

  // Background animation
  late CyberpunkBackground _background;

  // Effects
  final List<LockEffect> _lockEffects = [];
  final List<LineClearEffect> _lineClearEffects = [];
  Vector2 _shakeOffset = Vector2.zero();
  double _shakeTime = 0;
  double _shakeDuration = 0;
  double _shakeIntensity = 0;

  CyberBlockxGame({required this.gameState});

  @override
  Color backgroundColor() => const Color(0xFF0A0A0F);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _calculateLayout();
    _background = CyberpunkBackground(gameRef: this);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _calculateLayout();
  }

  /// Trigger lock effect with flash and screen shake
  void triggerLockEffect(Tetromino piece) {
    // Add haptic feedback
    HapticFeedback.mediumImpact();

    // Create flash effects for each block
    for (final pos in piece.absolutePositions) {
      if (pos.y >= 0 && pos.y < gameState.board.height) {
        final screenX = boardOrigin.x + pos.x * blockSize + blockSize / 2;
        final screenY = boardOrigin.y + (gameState.board.height - 1 - pos.y) * blockSize + blockSize / 2;
        _lockEffects.add(LockEffect(
          position: Vector2(screenX, screenY),
          color: piece.type.color,
          size: blockSize,
        ));
      }
    }

    // Start screen shake
    _startShake(intensity: 3.0, duration: 0.12);
  }

  /// Trigger line clear effect (scan line animation matching iOS)
  void triggerLineClearEffect(List<int> rows) {
    for (final row in rows) {
      final y = boardOrigin.y + (gameState.board.height - 1 - row) * blockSize + blockSize / 2;
      _lineClearEffects.add(LineClearEffect(
        y: y,
        boardX: boardOrigin.x,
        boardWidth: gameState.board.width * blockSize,
        glitchIntensity: VisualSettings.instance.glitchEffects,
      ));
    }
    // Screen shake for line clear
    _startShake(intensity: 4.0, duration: 0.15);
  }

  void _startShake({required double intensity, required double duration}) {
    // Scale intensity by glitch effects setting (like iOS)
    final glitchIntensity = VisualSettings.instance.glitchEffects;
    if (glitchIntensity < 0.2) return; // Skip if disabled

    _shakeIntensity = intensity * glitchIntensity;
    _shakeDuration = duration;
    _shakeTime = 0;
  }

  void _calculateLayout() {
    final boardWidth = gameState.board.width;
    final boardHeight = gameState.board.height;

    // Use full available space with minimal margins
    final horizontalMargin = 4.0;
    final topMargin = 20.0; // Add 20px top padding as requested
    final bottomMargin = 4.0;

    final availableWidth = size.x - (horizontalMargin * 2);
    final availableHeight = size.y - topMargin - bottomMargin;

    // Calculate block size to fill available space
    blockSize = (availableWidth / boardWidth)
        .clamp(0.0, availableHeight / boardHeight);

    boardSize = Vector2(
      boardWidth * blockSize,
      boardHeight * blockSize,
    );

    // Position: center horizontally, align top with HUD
    // Extra vertical space goes to bottom (near touch controls)
    boardOrigin = Vector2(
      (size.x - boardSize.x) / 2,
      topMargin,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw cyberpunk background
    _background.render(canvas, size);

    // Apply screen shake
    canvas.save();
    canvas.translate(_shakeOffset.x, _shakeOffset.y);

    // Draw board frame background first
    _drawBoardBackground(canvas);

    // Draw grid on top of background
    _drawGrid(canvas);

    // Draw board frame glow and border
    _drawBoardFrameGlow(canvas);

    // Draw locked blocks
    _drawLockedBlocks(canvas);

    // Draw ghost piece
    _drawGhostPiece(canvas);

    // Draw current piece
    _drawCurrentPiece(canvas);

    // Draw lock effects
    for (final effect in _lockEffects) {
      effect.render(canvas);
    }

    // Draw line clear effects
    for (final effect in _lineClearEffects) {
      effect.render(canvas);
    }

    canvas.restore();
  }

  void _drawGrid(Canvas canvas) {
    // Match iOS grid style: SKColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.3)
    final paint = Paint()
      ..color = const Color(0x4D1A334D) // RGB(26, 51, 77) with 0.3 alpha - matching iOS exactly
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Vertical lines
    for (int x = 0; x <= gameState.board.width; x++) {
      canvas.drawLine(
        Offset(boardOrigin.x + x * blockSize, boardOrigin.y),
        Offset(boardOrigin.x + x * blockSize, boardOrigin.y + boardSize.y),
        paint,
      );
    }

    // Horizontal lines
    for (int y = 0; y <= gameState.board.height; y++) {
      canvas.drawLine(
        Offset(boardOrigin.x, boardOrigin.y + y * blockSize),
        Offset(boardOrigin.x + boardSize.x, boardOrigin.y + y * blockSize),
        paint,
      );
    }
  }

  void _drawBoardBackground(Canvas canvas) {
    // Dark semi-transparent background
    final bgRect = Rect.fromLTWH(
      boardOrigin.x,
      boardOrigin.y,
      boardSize.x,
      boardSize.y,
    );
    final bgPaint = Paint()
      ..color = const Color(0xE6020308) // 90% opacity dark background
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(5)),
      bgPaint,
    );
  }

  void _drawBoardFrameGlow(Canvas canvas) {
    final glowIntensity = VisualSettings.instance.glowIntensity;

    // Outer frame rect
    final outerRect = Rect.fromLTWH(
      boardOrigin.x - 3,
      boardOrigin.y - 3,
      boardSize.x + 6,
      boardSize.y + 6,
    );

    // Outer glow layer 1 (wider, more diffuse)
    final glow1Paint = Paint()
      ..color = const Color(0xFF00CCFF).withValues(alpha: 0.35 * glowIntensity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * glowIntensity);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, const Radius.circular(7)),
      glow1Paint,
    );

    // Outer glow layer 2 (sharper)
    final glow2Paint = Paint()
      ..color = const Color(0xFF00CCFF).withValues(alpha: 0.5 * glowIntensity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * glowIntensity);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, const Radius.circular(7)),
      glow2Paint,
    );

    // Main border
    final borderPaint = Paint()
      ..color = Color.fromRGBO(0, 204, 255, 0.8 * glowIntensity.clamp(0.3, 1.0))
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, const Radius.circular(7)),
      borderPaint,
    );
  }

  void _drawLockedBlocks(Canvas canvas) {
    final board = gameState.board;
    for (int y = 0; y < board.height; y++) {
      for (int x = 0; x < board.width; x++) {
        final cell = board.getCell(x, y);
        if (cell.filled && cell.color != null) {
          _drawBlock(canvas, x, y, cell.color!);
        }
      }
    }
  }

  void _drawGhostPiece(Canvas canvas) {
    final ghost = gameState.getGhostPiece();
    if (ghost == null) return;

    for (final pos in ghost.absolutePositions) {
      if (pos.y >= 0 && pos.y < gameState.board.height) {
        _drawBlock(canvas, pos.x, pos.y, ghost.type.color, isGhost: true);
      }
    }
  }

  void _drawCurrentPiece(Canvas canvas) {
    final piece = gameState.currentPiece;
    if (piece == null) return;

    for (final pos in piece.absolutePositions) {
      if (pos.y >= 0 && pos.y < gameState.board.height) {
        _drawBlock(canvas, pos.x, pos.y, piece.type.color);
      }
    }
  }

  void _drawBlock(Canvas canvas, int gridX, int gridY, Color color, {bool isGhost = false}) {
    final glowIntensity = VisualSettings.instance.glowIntensity;

    // Convert grid coordinates to screen coordinates
    // Note: In our board, y=0 is at the bottom, but on screen y=0 is at top
    final screenX = boardOrigin.x + gridX * blockSize;
    final screenY = boardOrigin.y + (gameState.board.height - 1 - gridY) * blockSize;

    final outerRect = Rect.fromLTWH(
      screenX + 1,
      screenY + 1,
      blockSize - 2,
      blockSize - 2,
    );
    final mainRect = Rect.fromLTWH(
      screenX + 2,
      screenY + 2,
      blockSize - 4,
      blockSize - 4,
    );
    final innerRect = Rect.fromLTWH(
      screenX + 4,
      screenY + 4,
      blockSize - 8,
      blockSize - 8,
    );

    final outerRRect = RRect.fromRectAndRadius(outerRect, const Radius.circular(4));
    final mainRRect = RRect.fromRectAndRadius(mainRect, const Radius.circular(3));
    final innerRRect = RRect.fromRectAndRadius(innerRect, const Radius.circular(2));

    if (isGhost) {
      // Ghost piece - outline only with subtle glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.12 * glowIntensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * glowIntensity);
      canvas.drawRRect(outerRRect, glowPaint);

      final paint = Paint()
        ..color = color.withValues(alpha: 0.32)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(outerRRect, paint);
    } else {
      // Layer 1: Outer glow (bloom effect) - like iOS outerGlow
      final outerGlowPaint = Paint()
        ..color = color.withValues(alpha: 0.2 * glowIntensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * glowIntensity);
      canvas.drawRRect(outerRRect, outerGlowPaint);

      // Layer 2: Main block with acrylic/glass effect - like iOS block
      // Darker color for gradient
      final darkerColor = Color.fromRGBO(
        (color.red * 0.55).round(),
        (color.green * 0.55).round(),
        (color.blue * 0.55).round(),
        1,
      );

      // Main block fill with gradient (acrylic effect)
      final gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.65), darkerColor],
      );
      final fillPaint = Paint()..shader = gradient.createShader(mainRect);
      canvas.drawRRect(mainRRect, fillPaint);

      // Block stroke with glow
      final strokePaint = Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * glowIntensity);
      canvas.drawRRect(mainRRect, strokePaint);

      // Layer 3: Inner glow (energy core) - like iOS innerGlow
      final innerGlowPaint = Paint()
        ..color = color.withValues(alpha: 0.35 * glowIntensity);
      canvas.drawRRect(innerRRect, innerGlowPaint);

      // Layer 4: Highlight (reflective surface) - like iOS highlight
      final highlightRect = Rect.fromLTWH(
        screenX + 5,
        screenY + 3,
        blockSize - 10,
        2.5,
      );
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.28 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(highlightRect, const Radius.circular(1)),
        highlightPaint,
      );

      // Light border for definition
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(mainRRect, borderPaint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    gameState.update(dt);

    // Update background animation
    _background.update(dt);

    // Update screen shake
    if (_shakeTime < _shakeDuration) {
      _shakeTime += dt;
      final progress = _shakeTime / _shakeDuration;
      final intensity = _shakeIntensity * (1 - progress);
      final random = Random();
      _shakeOffset = Vector2(
        (random.nextDouble() - 0.5) * 2 * intensity,
        (random.nextDouble() - 0.5) * 2 * intensity,
      );
    } else {
      _shakeOffset = Vector2.zero();
    }

    // Update lock effects
    for (int i = _lockEffects.length - 1; i >= 0; i--) {
      _lockEffects[i].update(dt);
      if (_lockEffects[i].isDone) {
        _lockEffects.removeAt(i);
      }
    }

    // Update line clear effects
    for (int i = _lineClearEffects.length - 1; i >= 0; i--) {
      _lineClearEffects[i].update(dt);
      if (_lineClearEffects[i].isDone) {
        _lineClearEffects.removeAt(i);
      }
    }
  }
}

/// Lock effect - flash animation when piece locks
class LockEffect {
  final Vector2 position;
  final Color color;
  final double size;
  double _time = 0;
  static const double duration = 0.18;

  LockEffect({
    required this.position,
    required this.color,
    required this.size,
  });

  bool get isDone => _time >= duration;

  void update(double dt) {
    _time += dt;
  }

  void render(Canvas canvas) {
    if (isDone) return;

    final progress = _time / duration;
    final alpha = (1 - progress) * 0.9;

    // White flash
    final flashPaint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * (1 - progress));

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(position.x, position.y),
        width: size - 2,
        height: size - 2,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, flashPaint);

    // Color glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * (1 - progress));
    canvas.drawRRect(rect, glowPaint);
  }
}

/// Line clear effect - scan line animation matching iOS
class LineClearEffect {
  final double y;
  final double boardX;
  final double boardWidth;
  final double glitchIntensity;
  double _time = 0;
  static const double duration = 0.35;
  final Random _random = Random();

  LineClearEffect({
    required this.y,
    required this.boardX,
    required this.boardWidth,
    required this.glitchIntensity,
  });

  bool get isDone => _time >= duration;

  void update(double dt) {
    _time += dt;
  }

  void render(Canvas canvas) {
    if (isDone) return;

    final progress = _time / duration;

    // Glitch horizontal offset (small random displacement like iOS)
    final glitchOffset = glitchIntensity > 0.2
        ? (_random.nextDouble() - 0.5) * 10 * glitchIntensity
        : 0.0;

    // Flash brightness: quick fade in, then fade out
    final flashAlpha = progress < 0.1
        ? progress * 10 // Fast fade in
        : (1 - progress) * 1.1; // Slower fade out

    // White scan line
    final scanLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: flashAlpha.clamp(0.0, 0.9))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * glitchIntensity);

    canvas.drawRect(
      Rect.fromLTWH(
        boardX + glitchOffset,
        y - 1.5,
        boardWidth,
        3,
      ),
      scanLinePaint,
    );

    // Cyan glow underneath
    final glowPaint = Paint()
      ..color = const Color(0xFF00FFFF).withValues(alpha: flashAlpha * 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawRect(
      Rect.fromLTWH(
        boardX + glitchOffset,
        y - 3,
        boardWidth,
        6,
      ),
      glowPaint,
    );
  }
}

/// Cyberpunk animated background
class CyberpunkBackground {
  final FlameGame gameRef;
  final List<_DataRainColumn> _dataRainColumns = [];
  final List<_Building> _buildings = [];
  final List<_Wave> _waves = [];
  double _time = 0;
  final Random _random = Random();
  bool _initialized = false;

  CyberpunkBackground({required this.gameRef});

  void _initialize() {
    if (_initialized || gameRef.size.x <= 0) return;
    _initialized = true;

    // Setup data rain
    final columnCount = (gameRef.size.x / 30).clamp(8, 40).toInt();
    for (int i = 0; i < columnCount; i++) {
      _dataRainColumns.add(_DataRainColumn(
        x: i * 30.0 + _random.nextDouble() * 15,
        speed: 40 + _random.nextDouble() * 80,
        charCount: 4 + _random.nextInt(8),
        alpha: 0.08 + _random.nextDouble() * 0.15,
        startY: -_random.nextDouble() * 400,
      ));
    }

    // Setup city
    double x = 0;
    while (x < gameRef.size.x) {
      final width = 15 + _random.nextDouble() * 35;
      final height = 20 + _random.nextDouble() * 80;
      _buildings.add(_Building(
        x: x,
        width: width,
        height: height,
        hasNeonTop: _random.nextBool(),
        neonColor: [
          const Color(0x99FF0080),
          const Color(0x9900FFFF),
          const Color(0x998000FF),
        ][_random.nextInt(3)],
      ));
      x += width + 3 + _random.nextDouble() * 8;
    }

    // Setup waves
    for (int i = 0; i < 4; i++) {
      _waves.add(_Wave(
        index: i,
        amplitude: 10 - i * 2,
        wavelength: 60 + i * 12,
        yOffset: i * 10.0,
        alpha: 0.4 - i * 0.08,
      ));
    }
  }

  void update(double dt) {
    _initialize();
    _time += dt;

    for (final column in _dataRainColumns) {
      column.y += column.speed * dt;
      if (column.y > gameRef.size.y + 150) {
        column.y = -80;
        column.regenerateChars();
      }
    }

    for (final wave in _waves) {
      wave.phase = _time * (0.4 + wave.index * 0.08);
    }
  }

  void render(Canvas canvas, Vector2 size) {
    _drawGradient(canvas, size);
    _drawCity(canvas, size);
    _drawDataRain(canvas, size);
    _drawWaves(canvas, size);
    // Removed scan lines as per user request
  }

  void _drawGradient(Canvas canvas, Vector2 size) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF020208),
        Color(0xFF040318),
        Color(0xFF020610),
      ],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = gradient);
  }

  void _drawCity(Canvas canvas, Vector2 size) {
    final baseY = size.y * 0.8;

    for (final building in _buildings) {
      final bodyPaint = Paint()
        ..color = const Color(0xFF020206)
        ..style = PaintingStyle.fill;

      final bodyRect = Rect.fromLTWH(
        building.x,
        baseY - building.height,
        building.width,
        building.height,
      );
      canvas.drawRect(bodyRect, bodyPaint);

      final outlinePaint = Paint()
        ..color = const Color(0x40151528)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawRect(bodyRect, outlinePaint);

      if (building.hasNeonTop) {
        final neonPaint = Paint()
          ..color = building.neonColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawRect(
          Rect.fromLTWH(
            building.x + building.width * 0.15,
            baseY - building.height - 1,
            building.width * 0.7,
            1.5,
          ),
          neonPaint,
        );
      }
    }
  }

  void _drawDataRain(Canvas canvas, Vector2 size) {
    final textStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 10,
    );

    for (final column in _dataRainColumns) {
      for (int i = 0; i < column.chars.length; i++) {
        final alpha = (1.0 - i / column.chars.length) * column.alpha;
        final y = column.y - i * 12;

        if (y < -15 || y > size.y + 15) continue;

        final color = i == 0
            ? Color.fromRGBO(100, 255, 180, alpha)
            : Color.fromRGBO(0, 180, 100, alpha);

        final textSpan = TextSpan(
          text: column.chars[i],
          style: textStyle.copyWith(color: color),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(column.x, y));
      }
    }
  }

  void _drawWaves(Canvas canvas, Vector2 size) {
    final baseY = size.y * 0.7;

    for (final wave in _waves) {
      final path = Path();
      path.moveTo(0, baseY + wave.yOffset);

      for (double x = 0; x <= size.x; x += 4) {
        final y = baseY + wave.yOffset +
            wave.amplitude * sin((x / wave.wavelength + wave.phase) * pi * 2);
        path.lineTo(x, y);
      }

      final paint = Paint()
        ..color = Color.fromRGBO(0, 130, 220, wave.alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawPath(path, paint);
    }
  }
}

class _DataRainColumn {
  double x;
  double y;
  double speed;
  int charCount;
  double alpha;
  List<String> chars = [];
  final Random _random = Random();

  _DataRainColumn({
    required this.x,
    required this.speed,
    required this.charCount,
    required this.alpha,
    required double startY,
  }) : y = startY {
    regenerateChars();
  }

  void regenerateChars() {
    chars = List.generate(charCount, (_) => _random.nextInt(2).toString());
  }
}

class _Building {
  final double x;
  final double width;
  final double height;
  final bool hasNeonTop;
  final Color neonColor;

  _Building({
    required this.x,
    required this.width,
    required this.height,
    required this.hasNeonTop,
    required this.neonColor,
  });
}

class _Wave {
  final int index;
  final double amplitude;
  final double wavelength;
  final double yOffset;
  final double alpha;
  double phase = 0;

  _Wave({
    required this.index,
    required this.amplitude,
    required this.wavelength,
    required this.yOffset,
    required this.alpha,
  });
}
