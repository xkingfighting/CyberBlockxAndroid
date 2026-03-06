import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/share_card_data.dart';

/// Generates esports-style achievement poster images using offscreen Canvas.
/// Renders at 2× then downscales (SSAA) for crisp text and glow edges.
class ShareCardPainter {
  // Neon palette
  static const _cyan = Color(0xFF00FFFF);
  static const _magenta = Color(0xFFFF00FF);
  static const _yellow = Color(0xFFFFFF00);

  /// Generate a share card image as PNG bytes.
  /// Internally renders at 2× resolution and downscales for sharpness.
  static Future<Uint8List?> generateImage(
    ShareCardData data, {
    ShareCardSize size = ShareCardSize.story,
  }) async {
    const ssaa = 2.0;
    final w = size.width.toDouble();
    final h = size.height.toDouble();

    // Pass 1 — render at 2× resolution for sharp edges
    final hiRec = ui.PictureRecorder();
    final hiCanvas = Canvas(hiRec);
    hiCanvas.scale(ssaa);
    _drawCard(hiCanvas, data, w, h, size);
    final hiPic = hiRec.endRecording();
    final hiImg = await hiPic.toImage(
      (w * ssaa).toInt(),
      (h * ssaa).toInt(),
    );
    hiPic.dispose();

    // Pass 2 — downscale to target resolution (high-quality filter)
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawImageRect(
      hiImg,
      Rect.fromLTWH(0, 0, w * ssaa, h * ssaa),
      Rect.fromLTWH(0, 0, w, h),
      Paint()..filterQuality = FilterQuality.high,
    );
    hiImg.dispose();

    final pic = rec.endRecording();
    final img = await pic.toImage(size.width, size.height);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    pic.dispose();
    return bytes?.buffer.asUint8List();
  }

  static void _drawCard(
    Canvas canvas,
    ShareCardData data,
    double w,
    double h,
    ShareCardSize size,
  ) {
    _drawBackground(canvas, w, h);
    if (size == ShareCardSize.twitter) {
      _drawHorizontalLayout(canvas, data, w, h);
    } else {
      _drawVerticalLayout(canvas, data, w, h, size == ShareCardSize.social);
    }
  }

  // ============================================================
  // BACKGROUND — dark cyberpunk with grid, scanlines, HUD bars
  // ============================================================

  static void _drawBackground(Canvas canvas, double w, double h) {
    // Base dark
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF08080D),
    );

    // Subtle gradient overlay (reduced from 0x12 to 0x0E)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(w, h),
          [
            const Color(0x0E00FFFF),
            const Color(0x06AA00FF),
            const Color(0x0EFF00FF),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    // Radial warmth centered at score zone
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w / 2, h * 0.32),
          w * 0.6,
          [const Color(0x0800FFFF), const Color(0x00000000)],
          [0.0, 1.0],
        ),
    );

    _drawGrid(canvas, w, h);
    _drawScanlines(canvas, w, h);
    _drawHudScanBars(canvas, w, h);
    _drawBorderGlow(canvas, w, h);
    _drawCornerFrames(canvas, w, h);
  }

  static void _drawGrid(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = const Color(0x0500FFFF)
      ..strokeWidth = 1;
    final spacing = w / 20;
    for (double x = 0; x < w; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
    }
    for (double y = 0; y < h; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(w, y), paint);
    }
  }

  static void _drawScanlines(Canvas canvas, double w, double h) {
    final paint = Paint()..color = const Color(0x05000000);
    for (double y = 0; y < h; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, w, 2), paint);
    }
  }

  /// Faint HUD-style horizontal bars at fixed positions
  static void _drawHudScanBars(Canvas canvas, double w, double h) {
    final paint = Paint()..color = const Color(0x0600FFFF);
    for (final frac in [0.12, 0.48, 0.72]) {
      canvas.drawRect(Rect.fromLTWH(0, h * frac, w, 1), paint);
    }
  }

  static void _drawBorderGlow(Canvas canvas, double w, double h) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, 10, w - 20, h - 20),
      const Radius.circular(16),
    );
    // Clean thin border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0x3500FFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Soft outer glow (reduced intensity)
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0x1000FFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8),
    );
  }

  /// Double-bracket corner frames for HUD feel
  static void _drawCornerFrames(Canvas canvas, double w, double h) {
    final outer = Paint()
      ..color = const Color(0x5000FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final inner = Paint()
      ..color = const Color(0x2800FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    void drawBracket(Offset o, double dx, double dy) {
      canvas.drawLine(o, Offset(o.dx + dx * 50, o.dy), outer);
      canvas.drawLine(o, Offset(o.dx, o.dy + dy * 50), outer);
      final io = Offset(o.dx + dx * 8, o.dy + dy * 8);
      canvas.drawLine(io, Offset(io.dx + dx * 35, io.dy), inner);
      canvas.drawLine(io, Offset(io.dx, io.dy + dy * 35), inner);
    }

    drawBracket(const Offset(22, 22), 1, 1);
    drawBracket(Offset(w - 22, 22), -1, 1);
    drawBracket(Offset(22, h - 22), 1, -1);
    drawBracket(Offset(w - 22, h - 22), -1, -1);
  }

  // ============================================================
  // VERTICAL LAYOUT (Story 9:16 / Social 1:1)
  //
  // Target proportions for Story:
  //   Header + user info  ~12%
  //   Score area           ~26%
  //   Ranking stats        ~14%
  //   Decorative gap       ~10%
  //   Call-to-action       ~12%
  //   Lower deco + footer  ~16%
  //   CTA positioned at ~70% of card height
  // ============================================================

  static void _drawVerticalLayout(
    Canvas canvas,
    ShareCardData data,
    double w,
    double h,
    bool isSquare,
  ) {
    final s = w / 1080.0;
    final c = isSquare;
    double y = (c ? 50 : 70) * s;

    // 1. Brand header
    y = _drawBrandHeader(canvas, data, w, y, s, c);
    y += (c ? 12 : 20) * s;

    // 2. Player section (name + country + badge)
    y = _drawPlayerSection(canvas, data, w, y, s, c);
    y += (c ? 15 : 30) * s;

    // 3. SCORE HERO — dominant center (~26% of card height)
    y = _drawScoreHero(canvas, data, w, y, s, c, h);
    y += (c ? 15 : 35) * s;

    // 4. Rank panel
    y = _drawRankPanel(canvas, data, w, y, s, c);
    y += (c ? 10 : 15) * s;

    // 5. Mini stats
    y = _drawMiniStats(canvas, data, w, y, s, c);

    // 6. For story: push CTA to ~70% with filler decorations in the gap
    if (!c) {
      final ctaTarget = h * 0.70;
      if (y + 40 * s < ctaTarget) {
        _drawFillerDecorations(canvas, w, y + 20 * s, ctaTarget - 15 * s, s);
        y = ctaTarget;
      } else {
        y += 40 * s;
      }
    } else {
      y += 20 * s;
    }

    // 7. Bottom section (CTA + challenge + branding)
    y = _drawBottomSection(canvas, data, w, y, s, c);
    y += (c ? 10 : 20) * s;

    // 8. Tetromino decorations in remaining space
    _drawTetrominoDecoration(canvas, w, h, y, s, c);

    // 9. Footer ID (anchored to bottom)
    _drawFooterID(canvas, data, w, h, s);
  }

  // ============================================================
  // HORIZONTAL LAYOUT (Twitter 16:9)
  // ============================================================

  static void _drawHorizontalLayout(
    Canvas canvas,
    ShareCardData data,
    double w,
    double h,
  ) {
    final s = w / 1600.0;
    final margin = 50.0 * s;

    // Left panel: Brand + Player + Score hero
    final leftW = w * 0.55;
    double ly = margin;

    ly = _drawBrandHeader(canvas, data, leftW, ly, s, true);
    ly += 12 * s;
    ly = _drawPlayerSection(canvas, data, leftW, ly, s, true);
    ly += 18 * s;
    _drawScoreHero(canvas, data, leftW, ly, s, true, h);

    // Right panel: Rankings + Stats + Challenge
    final rx = w * 0.58;
    final rw = w * 0.38;
    double ry = margin + 20 * s;

    // Rank items
    final rankLines = <String>[];
    rankLines.add('GLOBAL RANK  #${_formatNumber(data.rank)}');
    if (data.hasCountryData) {
      rankLines.add(
        '${data.countryCode.toUpperCase()} RANK  #${_formatNumber(data.countryRank!)} / ${_formatNumber(data.countryTotal)}',
      );
    }
    if (data.totalPlayers > 0) {
      final pct = data.topPercentage;
      final pctStr =
          pct < 1 ? pct.toStringAsFixed(1) : pct.toStringAsFixed(0);
      rankLines.add('TOP $pctStr% WORLDWIDE');
    }
    for (final line in rankLines) {
      final p = _buildParagraph(
        line,
        fontSize: 18 * s,
        color: Colors.white,
        fontWeight: FontWeight.w500,
        maxWidth: rw,
      );
      canvas.drawParagraph(p, Offset(rx, ry));
      ry += p.height + 10 * s;
    }

    ry += 20 * s;

    // Stats
    for (final (label, value) in [
      ('LINES', '${data.lines}'),
      ('LEVEL', '${data.level}'),
      if (data.playTime != null) ('TIME', _formatDuration(data.playTime!)),
    ]) {
      final lp = _buildParagraph(
        label,
        fontSize: 12 * s,
        color: _cyan,
        letterSpacing: 3 * s,
        maxWidth: rw,
      );
      canvas.drawParagraph(lp, Offset(rx, ry));
      ry += lp.height + 2 * s;
      final vp = _buildParagraph(
        value,
        fontSize: 28 * s,
        color: Colors.white,
        fontWeight: FontWeight.w700,
        maxWidth: rw,
      );
      canvas.drawParagraph(vp, Offset(rx, ry));
      ry += vp.height + 14 * s;
    }

    ry += 10 * s;

    // Challenge
    final cp = _buildParagraph(
      data.challengeMessage,
      fontSize: 18 * s,
      color: _magenta,
      fontWeight: FontWeight.w600,
      maxWidth: rw,
    );
    canvas.drawParagraph(cp, Offset(rx, ry));

    _drawFooterID(canvas, data, w, h, s);
  }

  // ============================================================
  // COMPONENTS
  // ============================================================

  /// Brand header — CYBERBLOCKX + neon divider
  static double _drawBrandHeader(
    Canvas canvas,
    ShareCardData data,
    double w,
    double y,
    double s,
    bool c,
  ) {
    final p = _buildParagraph(
      'CYBERBLOCKX',
      fontSize: (c ? 34 : 40) * s,
      color: _cyan,
      fontWeight: FontWeight.w900,
      letterSpacing: 8 * s,
      maxWidth: w - 80 * s,
      textAlign: TextAlign.center,
    );
    canvas.drawParagraph(p, Offset((w - p.width) / 2, y));
    y += p.height + 12 * s;

    _drawNeonLine(canvas, 60 * s, y, w - 60 * s, y, s);
    y += 4 * s;
    return y;
  }

  /// Player section — Username + Country + Platform badge
  static double _drawPlayerSection(
    Canvas canvas,
    ShareCardData data,
    double w,
    double y,
    double s,
    bool c,
  ) {
    // Username
    final name = data.username.isNotEmpty ? data.username : 'PLAYER';
    final np = _buildParagraph(
      name.toUpperCase(),
      fontSize: (c ? 26 : 32) * s,
      color: Colors.white,
      fontWeight: FontWeight.w700,
      letterSpacing: 3 * s,
      maxWidth: w,
      textAlign: TextAlign.center,
    );
    canvas.drawParagraph(np, Offset((w - np.width) / 2, y));
    y += np.height + 6 * s;

    // Country
    if (data.hasCountryData) {
      final cp = _buildParagraph(
        '${data.countryCode.toUpperCase()}  ${data.countryName}',
        fontSize: (c ? 18 : 22) * s,
        color: const Color(0xFFB0B0B0),
        maxWidth: w,
        textAlign: TextAlign.center,
      );
      canvas.drawParagraph(cp, Offset((w - cp.width) / 2, y));
      y += cp.height + 6 * s;
    }

    // Platform badge
    final bp = _buildParagraph(
      data.platformBadge,
      fontSize: (c ? 13 : 16) * s,
      color: const Color(0xFF777777),
      letterSpacing: 3 * s,
      maxWidth: w,
      textAlign: TextAlign.center,
    );
    canvas.drawParagraph(bp, Offset((w - bp.width) / 2, y));
    y += bp.height;
    return y;
  }

  /// SCORE HERO — the dominant visual element (~26% of card height).
  /// Uses inner glow, soft gradient bg, and large score number.
  static double _drawScoreHero(
    Canvas canvas,
    ShareCardData data,
    double w,
    double y,
    double s,
    bool c,
    double h,
  ) {
    final scoreSize = (c ? 100 : 200) * s;
    final labelSize = (c ? 16 : 24) * s;
    final recordSize = (c ? 16 : 22) * s;
    final margin = (c ? 40 : 55) * s;

    // Panel height: proportional to card for story, fixed for compact
    final panelH = c ? 175 * s : h * 0.26;
    final panelRect = Rect.fromLTWH(margin, y, w - margin * 2, panelH);
    final panelRRect =
        RRect.fromRectAndRadius(panelRect, Radius.circular(16 * s));

    // Subtle gradient background
    canvas.drawRRect(
      panelRRect,
      Paint()
        ..shader = ui.Gradient.linear(
          panelRect.topCenter,
          panelRect.bottomCenter,
          [
            const Color(0x141A1A2E),
            const Color(0x0A16213E),
            const Color(0x141A1A2E),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    // Thin border (cyan→magenta gradient, reduced alpha)
    canvas.drawRRect(
      panelRRect,
      Paint()
        ..shader = ui.Gradient.linear(
          panelRect.topLeft,
          panelRect.bottomRight,
          [const Color(0x4000FFFF), const Color(0x40FF00FF)],
          [0.0, 1.0],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s,
    );

    // Inner glow — clip to panel so glow stays inside the edges
    canvas.save();
    canvas.clipRRect(panelRRect);
    canvas.drawRRect(
      panelRRect,
      Paint()
        ..color = const Color(0x1400FFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18 * s
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * s),
    );
    canvas.restore();

    // Soft radial glow behind score number
    final glowCenter = Offset(w / 2, y + panelH * 0.38);
    canvas.drawCircle(
      glowCenter,
      (c ? 70 : 140) * s,
      Paint()
        ..shader = ui.Gradient.radial(
          glowCenter,
          (c ? 70 : 140) * s,
          [const Color(0x1200FFFF), const Color(0x00000000)],
          [0.0, 1.0],
        ),
    );

    // Corner accents (story only)
    if (!c) {
      _drawPanelCorners(canvas, panelRect, s);
    }

    // Score number — MASSIVE
    double sy = y + (c ? 20 : 40) * s;
    final scoreStr = _formatNumber(data.score);
    final sp = _buildParagraph(
      scoreStr,
      fontSize: scoreSize,
      color: Colors.white,
      fontWeight: FontWeight.w900,
      letterSpacing: 4 * s,
      maxWidth: w - margin * 2 - 20 * s,
      textAlign: TextAlign.center,
    );
    canvas.drawParagraph(sp, Offset((w - sp.width) / 2, sy));
    sy += sp.height + (c ? 2 : 6) * s;

    // "SCORE" label BELOW the number
    final lp = _buildParagraph(
      'S C O R E',
      fontSize: labelSize,
      color: _cyan,
      letterSpacing: 8 * s,
      maxWidth: w,
      textAlign: TextAlign.center,
    );
    canvas.drawParagraph(lp, Offset((w - lp.width) / 2, sy));
    sy += lp.height;

    // NEW RECORD badge
    if (data.isNewRecord) {
      sy += (c ? 6 : 14) * s;
      final rp = _buildParagraph(
        '// NEW RECORD!',
        fontSize: recordSize,
        color: _yellow,
        fontWeight: FontWeight.w700,
        letterSpacing: 3 * s,
        maxWidth: w,
        textAlign: TextAlign.center,
      );
      canvas.drawParagraph(rp, Offset((w - rp.width) / 2, sy));
    }

    return y + panelH;
  }

  /// Small corner accents inside the score panel
  static void _drawPanelCorners(Canvas canvas, Rect rect, double s) {
    final paint = Paint()
      ..color = const Color(0x3500FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s;
    final len = 20 * s;
    final m = 10 * s;

    // TL
    canvas.drawLine(Offset(rect.left + m, rect.top + m),
        Offset(rect.left + m + len, rect.top + m), paint);
    canvas.drawLine(Offset(rect.left + m, rect.top + m),
        Offset(rect.left + m, rect.top + m + len), paint);
    // TR
    canvas.drawLine(Offset(rect.right - m, rect.top + m),
        Offset(rect.right - m - len, rect.top + m), paint);
    canvas.drawLine(Offset(rect.right - m, rect.top + m),
        Offset(rect.right - m, rect.top + m + len), paint);
    // BL
    canvas.drawLine(Offset(rect.left + m, rect.bottom - m),
        Offset(rect.left + m + len, rect.bottom - m), paint);
    canvas.drawLine(Offset(rect.left + m, rect.bottom - m),
        Offset(rect.left + m, rect.bottom - m - len), paint);
    // BR
    canvas.drawLine(Offset(rect.right - m, rect.bottom - m),
        Offset(rect.right - m - len, rect.bottom - m), paint);
    canvas.drawLine(Offset(rect.right - m, rect.bottom - m),
        Offset(rect.right - m, rect.bottom - m - len), paint);
  }

  /// Rank panel — HUD data readout with label/value pairs.
  /// Cleaner format: integer % for ≥1, one decimal for <1.
  static double _drawRankPanel(
    Canvas canvas,
    ShareCardData data,
    double w,
    double y,
    double s,
    bool c,
  ) {
    final fontSize = (c ? 18 : 26) * s;
    final lineGap = (c ? 8 : 16) * s;
    final panelW = w - (c ? 100 : 120) * s;
    final panelX = (w - panelW) / 2;

    // Build items
    final items = <(String, String)>[];
    items.add(('GLOBAL RANK', '#${_formatNumber(data.rank)}'));
    if (data.hasCountryData) {
      items.add((
        '${data.countryCode.toUpperCase()} RANK',
        '#${_formatNumber(data.countryRank!)} / ${_formatNumber(data.countryTotal)}',
      ));
    }
    if (data.totalPlayers > 0) {
      final pct = data.topPercentage;
      final pctStr =
          pct < 1 ? pct.toStringAsFixed(1) : pct.toStringAsFixed(0);
      items.add(('TOP', '$pctStr% WORLDWIDE'));
    }

    // Panel frame
    final itemH = fontSize + lineGap;
    final panelH = items.length * itemH + (c ? 28 : 48) * s;
    final panelRect = Rect.fromLTWH(panelX, y, panelW, panelH);
    final panelRRect =
        RRect.fromRectAndRadius(panelRect, Radius.circular(8 * s));

    canvas.drawRRect(
      panelRRect,
      Paint()..color = const Color(0x100D0D1A),
    );
    canvas.drawRRect(
      panelRRect,
      Paint()
        ..color = const Color(0x2800FFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * s,
    );

    // Content rows
    double iy = y + (c ? 14 : 24) * s;
    final innerX = panelX + 20 * s;
    final innerW = panelW - 40 * s;

    for (int i = 0; i < items.length; i++) {
      final (label, value) = items[i];

      // Label (left)
      final lp = _buildParagraph(
        label,
        fontSize: fontSize,
        color: const Color(0xFFA0A0A0),
        maxWidth: innerW * 0.62,
      );
      canvas.drawParagraph(lp, Offset(innerX, iy));

      // Value (right)
      final vp = _buildParagraph(
        value,
        fontSize: fontSize,
        color: Colors.white,
        fontWeight: FontWeight.w700,
        maxWidth: innerW * 0.38,
        textAlign: TextAlign.right,
      );
      canvas.drawParagraph(vp, Offset(innerX + innerW - vp.width, iy));

      iy += itemH;

      // Separator
      if (i < items.length - 1) {
        canvas.drawLine(
          Offset(innerX, iy - lineGap / 2),
          Offset(innerX + innerW, iy - lineGap / 2),
          Paint()
            ..color = const Color(0x1200FFFF)
            ..strokeWidth = 1,
        );
      }
    }

    return y + panelH;
  }

  /// Mini stats — small, muted, reduced noise
  static double _drawMiniStats(
    Canvas canvas,
    ShareCardData data,
    double w,
    double y,
    double s,
    bool c,
  ) {
    final stats = <String>['LN ${data.lines}', 'LV ${data.level}'];
    if (data.playTime != null) {
      stats.add(_formatDuration(data.playTime!));
    }

    final text = stats.join('  ·  ');
    final p = _buildParagraph(
      text,
      fontSize: (c ? 14 : 17) * s,
      color: const Color(0xFF555555),
      letterSpacing: 2 * s,
      maxWidth: w - 80 * s,
      textAlign: TextAlign.center,
    );
    canvas.drawParagraph(p, Offset((w - p.width) / 2, y));
    return y + p.height;
  }

  /// Bottom section — CTA with neon framing and generous spacing
  static double _drawBottomSection(
    Canvas canvas,
    ShareCardData data,
    double w,
    double y,
    double s,
    bool c,
  ) {
    // Top neon divider
    _drawNeonLine(canvas, 80 * s, y, w - 80 * s, y, s);
    y += (c ? 22 : 40) * s;

    // Challenge message
    final cp = _buildParagraph(
      data.challengeMessage,
      fontSize: (c ? 20 : 30) * s,
      color: _magenta,
      fontWeight: FontWeight.w600,
      letterSpacing: 2 * s,
      maxWidth: w - 100 * s,
      textAlign: TextAlign.center,
    );
    canvas.drawParagraph(cp, Offset((w - cp.width) / 2, y));
    y += cp.height + (c ? 10 : 22) * s;

    // CTA
    final ctap = _buildParagraph(
      data.ctaMessage,
      fontSize: (c ? 14 : 20) * s,
      color: const Color(0xFFB0B0B0),
      letterSpacing: 2 * s,
      maxWidth: w - 100 * s,
      textAlign: TextAlign.center,
    );
    canvas.drawParagraph(ctap, Offset((w - ctap.width) / 2, y));
    y += ctap.height + (c ? 8 : 18) * s;

    // URL
    final up = _buildParagraph(
      'cyberblockx.com',
      fontSize: (c ? 13 : 17) * s,
      color: const Color(0x9900FFFF),
      letterSpacing: 3 * s,
      maxWidth: w,
      textAlign: TextAlign.center,
    );
    canvas.drawParagraph(up, Offset((w - up.width) / 2, y));
    y += up.height + (c ? 15 : 30) * s;

    // Bottom neon divider
    _drawNeonLine(canvas, 80 * s, y, w - 80 * s, y, s);
    y += 4 * s;

    return y;
  }

  /// Footer — Share ID anchored to bottom
  static void _drawFooterID(
    Canvas canvas,
    ShareCardData data,
    double w,
    double h,
    double s,
  ) {
    final p = _buildParagraph(
      data.shareId,
      fontSize: 14 * s,
      color: const Color(0xFF444444),
      letterSpacing: 3 * s,
      maxWidth: w,
      textAlign: TextAlign.center,
    );
    canvas.drawParagraph(p, Offset((w - p.width) / 2, h - 50 * s));
  }

  // ============================================================
  // DECORATIVE FILLS — subtle atmosphere (8–15% opacity)
  // ============================================================

  /// Fill empty zone between mini-stats and CTA with subtle HUD elements.
  static void _drawFillerDecorations(
    Canvas canvas,
    double w,
    double startY,
    double endY,
    double s,
  ) {
    final zone = endY - startY;
    if (zone < 40 * s) return;

    // 1. Faint HUD text readouts
    final hudTexts = ['// DATA_VERIFIED', 'SYS.ACTIVE', 'LINK//READY'];
    for (int i = 0; i < hudTexts.length; i++) {
      final ty = startY + zone * (0.15 + 0.30 * i);
      if (ty > endY - 15 * s) break;
      final tx = (i % 2 == 0) ? 80 * s : w - 260 * s;
      final p = _buildParagraph(
        hudTexts[i],
        fontSize: 10 * s,
        color: Color(i % 2 == 0 ? 0x1500FFFF : 0x12FF00FF),
        letterSpacing: 2 * s,
        maxWidth: 200 * s,
      );
      canvas.drawParagraph(p, Offset(tx, ty));
    }

    // 2. Floating tetromino outlines
    final blockSize = 16 * s;
    final shapes = [
      (
        Offset(w * 0.12, startY + zone * 0.25),
        [
          [0, 0],
          [1, 0],
          [0, 1],
        ],
        const Color(0x1200FFFF),
      ),
      (
        Offset(w * 0.72, startY + zone * 0.45),
        [
          [0, 0],
          [1, 0],
          [2, 0],
          [1, 1],
        ],
        const Color(0x10FF00FF),
      ),
      (
        Offset(w * 0.35, startY + zone * 0.70),
        [
          [0, 0],
          [0, 1],
          [1, 1],
          [1, 2],
        ],
        const Color(0x0E00FFFF),
      ),
    ];

    for (final (offset, blocks, color) in shapes) {
      if (offset.dy + blockSize * 3 > endY) continue;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * s;
      for (final block in blocks) {
        canvas.drawRect(
          Rect.fromLTWH(
            offset.dx + block[0] * blockSize,
            offset.dy + block[1] * blockSize,
            blockSize,
            blockSize,
          ),
          paint,
        );
      }
    }

    // 3. Faint scan lines
    for (final frac in [0.30, 0.60, 0.90]) {
      final ly = startY + zone * frac;
      if (ly > endY - 5 * s) break;
      canvas.drawLine(
        Offset(60 * s, ly),
        Offset(w - 60 * s, ly),
        Paint()
          ..color = const Color(0x0600FFFF)
          ..strokeWidth = 0.5 * s,
      );
    }

    // 4. Mini brackets
    if (zone > 100 * s) {
      _drawMiniBracket(canvas, Offset(w * 0.48, startY + zone * 0.40), s);
      _drawMiniBracket(canvas, Offset(w * 0.20, startY + zone * 0.65), s);
    }
  }

  /// Tetromino outlines + accent lines for the bottom zone
  static void _drawTetrominoDecoration(
    Canvas canvas,
    double w,
    double h,
    double startY,
    double s,
    bool c,
  ) {
    final footerY = h - 60 * s;
    if (startY + 40 * s > footerY) return;

    final blockSize = (c ? 18 : 24) * s;
    final midY = (startY + footerY) / 2;

    final shapes = [
      (
        Offset(w * 0.08, midY - 40 * s),
        [
          [0, 0],
          [1, 0],
          [2, 0],
          [1, 1],
        ],
        const Color(0x1400FFFF),
      ),
      (
        Offset(w * 0.78, midY - 15 * s),
        [
          [0, 0],
          [0, 1],
          [0, 2],
          [1, 2],
        ],
        const Color(0x12FF00FF),
      ),
      (
        Offset(w * 0.25, midY + 25 * s),
        [
          [1, 0],
          [2, 0],
          [0, 1],
          [1, 1],
        ],
        const Color(0x1000FFFF),
      ),
      (
        Offset(w * 0.58, midY + 45 * s),
        [
          [0, 0],
          [1, 0],
          [2, 0],
          [3, 0],
        ],
        const Color(0x0EFF00FF),
      ),
      (
        Offset(w * 0.72, midY + 60 * s),
        [
          [0, 0],
          [1, 0],
          [0, 1],
          [1, 1],
        ],
        const Color(0x0C00FFFF),
      ),
    ];

    for (final (offset, blocks, color) in shapes) {
      if (offset.dy + blockSize * 3 > footerY - 10 * s) continue;
      if (offset.dy < startY) continue;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s;

      for (final block in blocks) {
        canvas.drawRect(
          Rect.fromLTWH(
            offset.dx + block[0] * blockSize,
            offset.dy + block[1] * blockSize,
            blockSize,
            blockSize,
          ),
          paint,
        );
      }
    }

    // Accent neon lines
    if (midY - 55 * s > startY) {
      _drawNeonLine(
        canvas,
        w * 0.55,
        midY - 55 * s,
        w - 80 * s,
        midY - 55 * s,
        s,
      );
    }
    if (midY + 70 * s < footerY - 20 * s) {
      _drawNeonLine(
        canvas,
        80 * s,
        midY + 70 * s,
        w * 0.45,
        midY + 70 * s,
        s,
      );
    }

    // Small HUD bracket elements
    if (midY + 30 * s < footerY - 30 * s) {
      _drawMiniBracket(canvas, Offset(w * 0.45, midY + 30 * s), s);
    }
    if (midY - 30 * s > startY + 10 * s) {
      _drawMiniBracket(canvas, Offset(w * 0.18, midY - 30 * s), s);
    }
  }

  /// Small decorative bracket element
  static void _drawMiniBracket(Canvas canvas, Offset pos, double s) {
    final paint = Paint()
      ..color = const Color(0x1500FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * s;
    final len = 12 * s;
    // ┌ shape
    canvas.drawLine(pos, Offset(pos.dx + len, pos.dy), paint);
    canvas.drawLine(pos, Offset(pos.dx, pos.dy + len), paint);
    canvas.drawLine(
      Offset(pos.dx, pos.dy + len),
      Offset(pos.dx + len * 0.5, pos.dy + len),
      paint,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Neon line with subtle glow + crisp core (reduced intensity)
  static void _drawNeonLine(
    Canvas canvas,
    double x1,
    double y1,
    double x2,
    double y2,
    double s,
  ) {
    final colors = [
      const Color(0x0000FFFF),
      const Color(0x1800FFFF),
      const Color(0x18FF00FF),
      const Color(0x00FF00FF),
    ];
    const stops = [0.0, 0.3, 0.7, 1.0];

    // Soft glow pass (reduced width and blur)
    canvas.drawLine(
      Offset(x1, y1),
      Offset(x2, y2),
      Paint()
        ..shader =
            ui.Gradient.linear(Offset(x1, y1), Offset(x2, y2), colors, stops)
        ..strokeWidth = 3 * s
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Crisp core pass
    final coreColors = [
      const Color(0x0000FFFF),
      const Color(0x7000FFFF),
      const Color(0x70FF00FF),
      const Color(0x00FF00FF),
    ];
    canvas.drawLine(
      Offset(x1, y1),
      Offset(x2, y2),
      Paint()
        ..shader = ui.Gradient.linear(
            Offset(x1, y1), Offset(x2, y2), coreColors, stops)
        ..strokeWidth = 1.5 * s,
    );
  }

  static ui.Paragraph _buildParagraph(
    String text, {
    required double fontSize,
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w400,
    double letterSpacing = 0,
    required double maxWidth,
    TextAlign textAlign = TextAlign.left,
  }) {
    final style = ui.TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      fontFamily: 'monospace',
    );
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: textAlign, maxLines: 3, ellipsis: '...'),
    )
      ..pushStyle(style)
      ..addText(text);
    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
    return paragraph;
  }

  static String _formatNumber(int n) {
    if (n < 1000) return n.toString();
    final str = n.toString();
    final buffer = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
