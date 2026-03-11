import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/game_state.dart';
import '../../core/tetromino.dart';
import '../models/match_state.dart';
import 'replay_data.dart';
import 'replay_orchestrator.dart';

/// Exports a replay as an MP4 video with full game UI rendering.
///
/// Uses dart:ui Canvas for high-quality rendering including:
/// - Main game board with grid, pieces, ghost piece
/// - Left HUD: hold piece, score, level, lines, combo, next queue
/// - Right panel: opponent mini board + stats
/// - Header: REPLAY title, opponent name, outcome
/// - Progress bar
///
/// Performance: ~10-20 seconds for a 2-minute match on modern devices.
class ReplayVideoExporter {
  static const _channel = MethodChannel('com.ichuk.cybertetris/video_export');

  // Video settings — 720x1280 HD (9:16 portrait)
  static const _videoWidth = 720;
  static const _videoHeight = 1280;
  static const _fps = 30;
  static const _bitRate = 2500000; // 2.5 Mbps

  // Layout constants
  static const double _headerHeight = 56;
  static const double _boardCols = 10;
  static const double _boardRows = 20;
  static const double _cellSize = 46;
  static const double _boardWidth = _boardCols * _cellSize; // 460
  static const double _leftPanelWidth = 96;
  static const double _rightPanelWidth = 96;
  static const double _boardMarginTop = 70;

  // Board origin — centered between side panels
  static double get _boardOriginX =>
      (_videoWidth - _boardWidth - _leftPanelWidth - _rightPanelWidth) / 2 +
      _leftPanelWidth; // ~84
  static const double _boardOriginY = _headerHeight + 16;

  // Opponent mini board
  static const double _miniCellSize = 7;
  static const double _miniBoardWidth = 10 * _miniCellSize; // 70
  static const double _miniBoardHeight = 20 * _miniCellSize; // 140

  // Colors
  static const Color _bgColor = Color(0xFF0A0A0F);
  static const Color _surfaceColor = Color(0xFF1A1A2E);
  static const Color _cyan = Color(0xFF00FFFF);
  static const Color _green = Color(0xFF00FF66);
  static const Color _red = Color(0xFFFF0045);
  static const Color _yellow = Color(0xFFFFFF00);
  static const Color _orange = Color(0xFFFF8000);
  static const Color _purple = Color(0xFFB49FFF);
  static const Color _textMuted = Color(0xFF666680);

  bool _cancelled = false;

  void cancel() => _cancelled = true;

  /// Export a replay to MP4 video and save to gallery.
  /// Returns true on success.
  Future<bool> export(
    ReplayData replay,
    void Function(double progress) onProgress,
  ) async {
    _cancelled = false;

    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/replay_${replay.matchId}.mp4';

    // Start native encoder
    await _channel.invokeMethod('startExport', {
      'width': _videoWidth,
      'height': _videoHeight,
      'fps': _fps,
      'bitRate': _bitRate,
      'path': outputPath,
    });

    // Create orchestrator for offscreen replay
    final orchestrator = ReplayOrchestrator(replay: replay);
    orchestrator.startCountdown();
    orchestrator.update(3.1); // Skip countdown

    final frameDuration = 1.0 / _fps;
    final totalDurationSec = replay.totalDurationMs / 1000.0;
    final totalFrames = (totalDurationSec * _fps).ceil().clamp(1, 999999);

    try {
      for (var frameIndex = 0; frameIndex < totalFrames; frameIndex++) {
        if (_cancelled) {
          orchestrator.dispose();
          throw Exception('Export cancelled');
        }

        orchestrator.update(frameDuration);

        if (orchestrator.phase == MatchPhase.result && frameIndex > _fps) {
          break;
        }

        // Render frame using dart:ui Canvas
        final rgba = await _renderFrame(
          orchestrator.playerState,
          orchestrator.opponentState,
          replay,
          frameIndex / totalFrames,
        );

        await _channel.invokeMethod('addFrame', {'frame': rgba});

        if (frameIndex % 10 == 0) {
          onProgress(frameIndex / totalFrames);
        }
      }

      await _channel.invokeMethod('finishExport');
      onProgress(1.0);

      final saved = await _channel.invokeMethod<bool>('saveToGallery', {
        'path': outputPath,
        'fileName': 'replay_${replay.matchId}.mp4',
      });

      orchestrator.dispose();
      return saved ?? false;
    } catch (e) {
      orchestrator.dispose();
      rethrow;
    }
  }

  /// Render a single frame using dart:ui Canvas for full UI rendering.
  Future<Uint8List> _renderFrame(
    GameState playerState,
    GameState opponentState,
    ReplayData replay,
    double progress,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, _videoWidth.toDouble(), _videoHeight.toDouble()),
    );

    // 1. Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _videoWidth.toDouble(), _videoHeight.toDouble()),
      Paint()..color = _bgColor,
    );

    // 2. Header
    _drawHeader(canvas, replay);

    // 3. Main board
    _drawBoard(canvas, playerState);

    // 4. Left HUD (hold, score, level, lines, combo, next queue)
    _drawLeftHUD(canvas, playerState);

    // 5. Right panel (opponent mini board + stats)
    _drawRightPanel(canvas, opponentState, replay);

    // 6. Progress bar
    _drawProgressBar(canvas, progress);

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(_videoWidth, _videoHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();

    return byteData!.buffer.asUint8List();
  }

  // ─── HEADER ───────────────────────────────────────────────────────

  void _drawHeader(Canvas canvas, ReplayData replay) {
    // Header background
    final headerRect =
        Rect.fromLTWH(0, 0, _videoWidth.toDouble(), _headerHeight);
    canvas.drawRect(
      headerRect,
      Paint()..color = _surfaceColor.withValues(alpha: 0.8),
    );
    // Bottom border
    canvas.drawLine(
      Offset(0, _headerHeight),
      Offset(_videoWidth.toDouble(), _headerHeight),
      Paint()
        ..color = _cyan.withValues(alpha: 0.3)
        ..strokeWidth = 1,
    );

    // "REPLAY" title
    _drawText(canvas, 'REPLAY', Offset(_boardOriginX, 16),
        fontSize: 18, color: _cyan, fontWeight: FontWeight.w900);

    // "vs OpponentName"
    _drawText(
      canvas,
      'vs ${replay.opponentName}',
      Offset(_boardOriginX + _boardWidth / 2, 20),
      fontSize: 12,
      color: Colors.white.withValues(alpha: 0.5),
      align: TextAlign.center,
    );

    // Outcome chip
    final outcomeColor = replay.outcome == 'win'
        ? _green
        : (replay.outcome == 'draw' ? _yellow : _red);
    final outcomeText = replay.outcome.toUpperCase();

    // Chip background
    final chipWidth = outcomeText.length * 9.0 + 16;
    final chipX = _boardOriginX + _boardWidth - chipWidth;
    final chipRect =
        RRect.fromRectAndRadius(
      Rect.fromLTWH(chipX, 14, chipWidth, 24),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      chipRect,
      Paint()..color = outcomeColor.withValues(alpha: 0.15),
    );
    canvas.drawRRect(
      chipRect,
      Paint()
        ..color = outcomeColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _drawText(
      canvas,
      outcomeText,
      Offset(chipX + chipWidth / 2, 18),
      fontSize: 11,
      color: outcomeColor,
      fontWeight: FontWeight.w900,
      align: TextAlign.center,
    );
  }

  // ─── MAIN BOARD ───────────────────────────────────────────────────

  void _drawBoard(Canvas canvas, GameState state) {
    final bx = _boardOriginX;
    final by = _boardOriginY;

    // Board background
    canvas.drawRect(
      Rect.fromLTWH(bx, by, _boardWidth, _boardRows * _cellSize),
      Paint()..color = const Color(0xFF0F0F19),
    );

    // Grid lines
    final gridPaint = Paint()
      ..color = _cyan.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    for (var col = 0; col <= _boardCols.toInt(); col++) {
      final x = bx + col * _cellSize;
      canvas.drawLine(
        Offset(x, by),
        Offset(x, by + _boardRows * _cellSize),
        gridPaint,
      );
    }
    for (var row = 0; row <= _boardRows.toInt(); row++) {
      final y = by + row * _cellSize;
      canvas.drawLine(
        Offset(bx, y),
        Offset(bx + _boardWidth, y),
        gridPaint,
      );
    }

    // Locked cells
    for (var y = 0; y < _boardRows.toInt(); y++) {
      for (var x = 0; x < _boardCols.toInt(); x++) {
        final cell = state.board.getCell(x, _boardRows.toInt() - 1 - y);
        if (cell.filled && cell.color != null) {
          _drawCell(canvas, bx, by, x, y, cell.color!);
        }
      }
    }

    // Ghost piece
    final ghost = state.getGhostPiece();
    if (ghost != null) {
      final ghostColor = ghost.type.color.withValues(alpha: 0.2);
      for (final pos in ghost.absolutePositions) {
        final screenY = _boardRows.toInt() - 1 - pos.y;
        if (screenY >= 0 &&
            screenY < _boardRows.toInt() &&
            pos.x >= 0 &&
            pos.x < _boardCols.toInt()) {
          _drawCell(canvas, bx, by, pos.x, screenY, ghostColor,
              isGhost: true);
        }
      }
    }

    // Current piece
    final piece = state.currentPiece;
    if (piece != null) {
      for (final pos in piece.absolutePositions) {
        final screenY = _boardRows.toInt() - 1 - pos.y;
        if (screenY >= 0 &&
            screenY < _boardRows.toInt() &&
            pos.x >= 0 &&
            pos.x < _boardCols.toInt()) {
          _drawCell(canvas, bx, by, pos.x, screenY, piece.type.color);
        }
      }
    }

    // Board border glow
    canvas.drawRect(
      Rect.fromLTWH(bx, by, _boardWidth, _boardRows * _cellSize),
      Paint()
        ..color = _cyan.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawCell(
    Canvas canvas,
    double boardX,
    double boardY,
    int col,
    int row,
    Color color, {
    bool isGhost = false,
  }) {
    final x = boardX + col * _cellSize + 1;
    final y = boardY + row * _cellSize + 1;
    final s = _cellSize - 2;

    // Fill
    canvas.drawRect(Rect.fromLTWH(x, y, s, s), Paint()..color = color);

    if (!isGhost) {
      // 3D bevel highlight (top + left edges)
      final highlight = Color.fromARGB(
        90,
        (color.r * 255 + 76).clamp(0, 255).toInt(),
        (color.g * 255 + 76).clamp(0, 255).toInt(),
        (color.b * 255 + 76).clamp(0, 255).toInt(),
      );
      canvas.drawRect(Rect.fromLTWH(x, y, s, 3), Paint()..color = highlight);
      canvas.drawRect(Rect.fromLTWH(x, y, 3, s), Paint()..color = highlight);

      // Dark edge (bottom + right)
      final shadow = color.withValues(alpha: 0.3);
      canvas.drawRect(
          Rect.fromLTWH(x, y + s - 2, s, 2), Paint()..color = shadow);
      canvas.drawRect(
          Rect.fromLTWH(x + s - 2, y, 2, s), Paint()..color = shadow);
    }
  }

  // ─── LEFT HUD ─────────────────────────────────────────────────────

  void _drawLeftHUD(Canvas canvas, GameState state) {
    final panelX = _boardOriginX - _leftPanelWidth - 4;
    var curY = _boardOriginY;

    // HOLD piece
    _drawHUDCard(canvas, panelX, curY, _leftPanelWidth, 72, 'HOLD',
        _purple.withValues(alpha: 0.8));
    if (state.holdPiece != null) {
      _drawPiecePreview(
          canvas, panelX + _leftPanelWidth / 2, curY + 38, state.holdPiece!);
    }
    curY += 80;

    // SCORE
    _drawHUDCard(
        canvas, panelX, curY, _leftPanelWidth, 56, 'SCORE', _cyan);
    _drawText(
      canvas,
      _formatScore(state.scoring.score),
      Offset(panelX + _leftPanelWidth / 2, curY + 30),
      fontSize: 16,
      color: _cyan,
      fontWeight: FontWeight.w900,
      align: TextAlign.center,
    );
    curY += 64;

    // LEVEL
    _drawHUDCard(
        canvas, panelX, curY, _leftPanelWidth, 50, 'LEVEL', _green);
    _drawText(
      canvas,
      '${state.scoring.level}',
      Offset(panelX + _leftPanelWidth / 2, curY + 28),
      fontSize: 16,
      color: _green,
      fontWeight: FontWeight.w900,
      align: TextAlign.center,
    );
    curY += 58;

    // LINES
    _drawHUDCard(
        canvas, panelX, curY, _leftPanelWidth, 50, 'LINES', _yellow);
    _drawText(
      canvas,
      '${state.scoring.totalLines}',
      Offset(panelX + _leftPanelWidth / 2, curY + 28),
      fontSize: 16,
      color: _yellow,
      fontWeight: FontWeight.w900,
      align: TextAlign.center,
    );
    curY += 58;

    // COMBO (only if > 1)
    if (state.scoring.combo > 1) {
      _drawHUDCard(
          canvas, panelX, curY, _leftPanelWidth, 44, 'COMBO', _orange);
      _drawText(
        canvas,
        '×${state.scoring.combo}',
        Offset(panelX + _leftPanelWidth / 2, curY + 24),
        fontSize: 16,
        color: _orange,
        fontWeight: FontWeight.w900,
        align: TextAlign.center,
      );
      curY += 52;
    }

    // NEXT queue (3 pieces)
    _drawHUDCard(canvas, panelX, curY, _leftPanelWidth, 200, 'NEXT', _cyan);
    final preview = state.previewQueue;
    for (var i = 0; i < min(3, preview.length); i++) {
      _drawPiecePreview(
        canvas,
        panelX + _leftPanelWidth / 2,
        curY + 38 + i * 54.0,
        preview[i],
        scale: i == 0 ? 1.0 : 0.85,
        alpha: i == 0 ? 1.0 : 0.6,
      );
    }
  }

  void _drawHUDCard(Canvas canvas, double x, double y, double w, double h,
      String label, Color accentColor) {
    // Card background
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.black.withValues(alpha: 0.5));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Label
    _drawText(
      canvas,
      label,
      Offset(x + w / 2, y + 6),
      fontSize: 9,
      color: accentColor.withValues(alpha: 0.7),
      fontWeight: FontWeight.w700,
      align: TextAlign.center,
    );
  }

  void _drawPiecePreview(
    Canvas canvas,
    double centerX,
    double centerY,
    TetrominoType type, {
    double scale = 1.0,
    double alpha = 1.0,
  }) {
    final shape = type.shapes[0]; // rotation 0
    final color = type.color.withValues(alpha: alpha);
    final previewCellSize = 12.0 * scale;

    // Calculate bounding box for centering
    double minX = 999, maxX = -999, minY = 999, maxY = -999;
    for (final p in shape) {
      if (p.x < minX) minX = p.x.toDouble();
      if (p.x > maxX) maxX = p.x.toDouble();
      if (p.y < minY) minY = p.y.toDouble();
      if (p.y > maxY) maxY = p.y.toDouble();
    }
    final shapeW = (maxX - minX + 1) * previewCellSize;
    final shapeH = (maxY - minY + 1) * previewCellSize;
    final offsetX = centerX - shapeW / 2;
    final offsetY = centerY - shapeH / 2;

    for (final p in shape) {
      final bx = offsetX + (p.x - minX) * previewCellSize;
      final by = offsetY + (p.y - minY) * previewCellSize;
      final s = previewCellSize - 1;
      canvas.drawRect(Rect.fromLTWH(bx, by, s, s), Paint()..color = color);

      // Mini bevel
      if (alpha > 0.5) {
        final hi = Color.fromARGB(
          60,
          (color.r * 255 + 60).clamp(0, 255).toInt(),
          (color.g * 255 + 60).clamp(0, 255).toInt(),
          (color.b * 255 + 60).clamp(0, 255).toInt(),
        );
        canvas.drawRect(Rect.fromLTWH(bx, by, s, 2), Paint()..color = hi);
        canvas.drawRect(Rect.fromLTWH(bx, by, 2, s), Paint()..color = hi);
      }
    }
  }

  // ─── RIGHT PANEL (OPPONENT) ───────────────────────────────────────

  void _drawRightPanel(
      Canvas canvas, GameState opponentState, ReplayData replay) {
    final panelX = _boardOriginX + _boardWidth + 4;
    var curY = _boardOriginY;

    // Opponent name
    _drawText(
      canvas,
      replay.opponentName.length > 8
          ? '${replay.opponentName.substring(0, 8)}..'
          : replay.opponentName,
      Offset(panelX + _rightPanelWidth / 2, curY),
      fontSize: 9,
      color: _purple.withValues(alpha: 0.8),
      fontWeight: FontWeight.w700,
      align: TextAlign.center,
    );
    curY += 16;

    // Alive/Dead indicator
    final isAlive = opponentState.phase != GamePhase.gameOver;
    final statusColor = isAlive
        ? _purple.withValues(alpha: 0.7)
        : _red.withValues(alpha: 0.7);
    canvas.drawCircle(
      Offset(panelX + 8, curY + 5),
      4,
      Paint()..color = statusColor,
    );
    _drawText(
      canvas,
      isAlive ? 'ALIVE' : 'K.O.',
      Offset(panelX + 18, curY),
      fontSize: 9,
      color: statusColor,
      fontWeight: FontWeight.w700,
    );
    curY += 18;

    // Mini board
    _drawMiniBoard(canvas, panelX + (_rightPanelWidth - _miniBoardWidth) / 2,
        curY, opponentState);
    curY += _miniBoardHeight + 8;

    // Opponent stats
    _drawMiniStat(canvas, panelX, curY, 'SCORE',
        _formatScore(opponentState.scoring.score), _purple);
    curY += 32;
    _drawMiniStat(canvas, panelX, curY, 'LV',
        '${opponentState.scoring.level}', const Color(0xFF8B6FE8));
    curY += 32;
    _drawMiniStat(canvas, panelX, curY, 'LINES',
        '${opponentState.scoring.totalLines}', const Color(0xFF6B4FD6));
    curY += 32;

    if (opponentState.scoring.combo > 1) {
      _drawMiniStat(canvas, panelX, curY, 'CMB',
          '×${opponentState.scoring.combo}', _orange);
    }
  }

  void _drawMiniBoard(
      Canvas canvas, double x, double y, GameState state) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(x, y, _miniBoardWidth, _miniBoardHeight),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );

    // Cells
    for (var row = 0; row < 20; row++) {
      for (var col = 0; col < 10; col++) {
        final cell = state.board.getCell(col, 19 - row);
        if (cell.filled && cell.color != null) {
          canvas.drawRect(
            Rect.fromLTWH(
              x + col * _miniCellSize,
              y + row * _miniCellSize,
              _miniCellSize - 0.5,
              _miniCellSize - 0.5,
            ),
            Paint()..color = cell.color!.withValues(alpha: 0.5),
          );
        }
      }
    }

    // Current piece on mini board
    final piece = state.currentPiece;
    if (piece != null) {
      for (final pos in piece.absolutePositions) {
        final screenY = 19 - pos.y;
        if (screenY >= 0 && screenY < 20 && pos.x >= 0 && pos.x < 10) {
          canvas.drawRect(
            Rect.fromLTWH(
              x + pos.x * _miniCellSize,
              y + screenY * _miniCellSize,
              _miniCellSize - 0.5,
              _miniCellSize - 0.5,
            ),
            Paint()..color = piece.type.color.withValues(alpha: 0.5),
          );
        }
      }
    }

    // Border
    canvas.drawRect(
      Rect.fromLTWH(x, y, _miniBoardWidth, _miniBoardHeight),
      Paint()
        ..color = _purple.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawMiniStat(
      Canvas canvas, double x, double y, String label, String value, Color color) {
    _drawText(canvas, label, Offset(x + _rightPanelWidth / 2, y),
        fontSize: 8, color: color.withValues(alpha: 0.6), align: TextAlign.center);
    _drawText(canvas, value, Offset(x + _rightPanelWidth / 2, y + 12),
        fontSize: 12,
        color: color,
        fontWeight: FontWeight.w900,
        align: TextAlign.center);
  }

  // ─── PROGRESS BAR ────────────────────────────────────────────────

  void _drawProgressBar(Canvas canvas, double progress) {
    final barY = _boardOriginY + _boardRows * _cellSize + 16;
    final barX = _boardOriginX;
    final barW = _boardWidth;

    // Track
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW, 4),
        const Radius.circular(2),
      ),
      Paint()..color = _surfaceColor,
    );

    // Fill
    if (progress > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barW * progress, 4),
          const Radius.circular(2),
        ),
        Paint()..color = _cyan.withValues(alpha: 0.8),
      );
    }
  }

  // ─── TEXT DRAWING ─────────────────────────────────────────────────

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    double fontSize = 14,
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.bold,
    TextAlign align = TextAlign.left,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          fontFamily: 'monospace',
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    double dx = position.dx;
    if (align == TextAlign.center) {
      dx -= textPainter.width / 2;
    } else if (align == TextAlign.right) {
      dx -= textPainter.width;
    }

    textPainter.paint(canvas, Offset(dx, position.dy));
  }

  // ─── HELPERS ──────────────────────────────────────────────────────

  String _formatScore(int score) {
    if (score < 1000) return '$score';
    final s = score.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
