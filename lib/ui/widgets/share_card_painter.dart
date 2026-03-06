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
    Uint8List? gameScreenshot,
  }) async {
    const ssaa = 3.0;
    final w = size.width.toDouble();
    final h = size.height.toDouble();

    // Decode game screenshot if provided
    ui.Image? bgImage;
    if (gameScreenshot != null) {
      debugPrint('ShareCard: Decoding screenshot, ${gameScreenshot.length} bytes');
      try {
        final codec = await ui.instantiateImageCodec(gameScreenshot);
        final frame = await codec.getNextFrame();
        bgImage = frame.image;
        debugPrint('ShareCard: Decoded bg image ${bgImage.width}x${bgImage.height}');
      } catch (e) {
        debugPrint('ShareCard: Failed to decode screenshot: $e');
      }
    } else {
      debugPrint('ShareCard: [v5-phase] No gameScreenshot provided, using solid background');
    }

    // Pass 1 — render at 3× resolution for sharp edges
    try {
      final hiRec = ui.PictureRecorder();
      final hiCanvas = Canvas(hiRec);
      hiCanvas.scale(ssaa);
      _drawCard(hiCanvas, data, w, h, size, backgroundImage: bgImage);
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
    } finally {
      bgImage?.dispose(); // Always release decoded screenshot
    }
  }

  static void _drawCard(
    Canvas canvas,
    ShareCardData data,
    double w,
    double h,
    ShareCardSize size, {
    ui.Image? backgroundImage,
  }) {
    _drawBackground(canvas, w, h, backgroundImage);
    // Always use vertical Story layout (1080×1920)
    _drawVerticalLayout(canvas, data, w, h);
  }

  // ============================================================
  // BACKGROUND — dark cyberpunk with grid, scanlines, HUD bars
  // ============================================================

  static void _drawBackground(Canvas canvas, double w, double h, [ui.Image? backgroundImage]) {
    if (backgroundImage != null) {
      // Draw game screenshot as background (center-crop to fill)
      final imgW = backgroundImage.width.toDouble();
      final imgH = backgroundImage.height.toDouble();
      final imgAspect = imgW / imgH;
      final cardAspect = w / h;

      Rect srcRect;
      if (imgAspect > cardAspect) {
        final cropW = imgH * cardAspect;
        srcRect = Rect.fromLTWH((imgW - cropW) / 2, 0, cropW, imgH);
      } else {
        final cropH = imgW / cardAspect;
        srcRect = Rect.fromLTWH(0, (imgH - cropH) / 2, imgW, cropH);
      }

      canvas.drawImageRect(
        backgroundImage,
        srcRect,
        Rect.fromLTWH(0, 0, w, h),
        Paint()..filterQuality = FilterQuality.high,
      );

      // Dark overlay gradient for text readability
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, h),
            [
              const Color(0xD0000000), // top 81%
              const Color(0x99000000), // middle 60%
              const Color(0xD0000000), // bottom 81%
            ],
            [0.0, 0.45, 1.0],
          ),
      );
    } else {
      // Fallback: solid dark background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF08080D),
      );

      // Subtle gradient overlay
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
    }

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
  ) {
    final s = w / 1080.0;
    double y = 70 * s;

    // 1. Brand header
    y = _drawBrandHeader(canvas, data, w, y, s);
    y += 20 * s;

    // 2. Player section (name + country + badge)
    y = _drawPlayerSection(canvas, data, w, y, s);
    y += 30 * s;

    // 3. SCORE HERO — dominant center (~26% of card height)
    y = _drawScoreHero(canvas, data, w, y, s, h);
    y += 35 * s;

    // 4. Rank panel
    y = _drawRankPanel(canvas, data, w, y, s);
    y += 15 * s;

    // 5. Mini stats
    y = _drawMiniStats(canvas, data, w, y, s);

    // 6. Push CTA to ~70% with filler decorations in the gap
    final ctaTarget = h * 0.70;
    if (y + 40 * s < ctaTarget) {
      _drawFillerDecorations(canvas, w, y + 20 * s, ctaTarget - 15 * s, s);
      y = ctaTarget;
    } else {
      y += 40 * s;
    }

    // 7. Bottom section (CTA + challenge + branding)
    y = _drawBottomSection(canvas, data, w, y, s);
    y += 20 * s;

    // 8. Tetromino decorations in remaining space
    _drawTetrominoDecoration(canvas, w, h, y, s);

    // 9. Footer ID (anchored to bottom)
    _drawFooterID(canvas, data, w, h, s);
  }

  // ============================================================
  // COMPONENTS
  // ============================================================

  /// Brand header — CYBERBLOCKX with gradient matching home page + neon divider
  static double _drawBrandHeader(
    Canvas canvas,
    ShareCardData data,
    double w,
    double y,
    double s,
  ) {
    // First, build a plain paragraph to measure size
    final measureP = _buildParagraph(
      'CYBERBLOCKX',
      fontSize: 80 * s,
      color: Colors.white,
      fontWeight: FontWeight.w900,
      letterSpacing: 16 * s,
      maxWidth: w - 80 * s,
      textAlign: TextAlign.center,
    );
    final textX = (w - measureP.width) / 2;

    // Build gradient paragraph: CYBER(cyan→blue→purple) BLOCK(magenta→purple→blue) X(red)
    final gradientShader = ui.Gradient.linear(
      Offset(textX, 0),
      Offset(textX + measureP.width, 0),
      [
        const Color(0xFF00FFFF), // cyan — start of CYBER
        const Color(0xFF00AAFF), // blue — mid CYBER
        const Color(0xFF8844FF), // purple — end CYBER
        const Color(0xFFFF00FF), // magenta — start BLOCK
        const Color(0xFFAA44FF), // purple — mid BLOCK
        const Color(0xFF6666FF), // blue-purple — end BLOCK
        const Color(0xFFFF4444), // red — X
        const Color(0xFFFF4444), // red — X end
      ],
      [0.0, 0.22, 0.44, 0.46, 0.65, 0.88, 0.91, 1.0],
    );

    final gradientStyle = ui.TextStyle(
      foreground: Paint()..shader = gradientShader,
      fontSize: 80 * s,
      fontWeight: FontWeight.w900,
      letterSpacing: 16 * s,
      fontFamily: 'monospace',
    );
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center, maxLines: 1),
    )
      ..pushStyle(gradientStyle)
      ..addText('CYBERBLOCKX');
    final p = builder.build();
    p.layout(ui.ParagraphConstraints(width: w - 80 * s));

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
  ) {
    // Username
    final name = data.username.isNotEmpty ? data.username : 'PLAYER';
    final np = _buildParagraph(
      name.toUpperCase(),
      fontSize: 72 * s,
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
        '// ${data.countryCode.toUpperCase()} \u2014 ${data.countryName.toUpperCase()}',
        fontSize: 44 * s,
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
      fontSize: 32 * s,
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
    double h,
  ) {
    final scoreSize = 200 * s;
    final labelSize = 48 * s;
    final recordSize = 44 * s;
    final margin = 55 * s;

    // Panel height: proportional to card
    final panelH = h * 0.22;
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
        ..color = const Color(0x1800FFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22 * s
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * s),
    );
    canvas.restore();

    // Soft radial glow behind score number
    final glowCenter = Offset(w / 2, y + panelH * 0.38);
    canvas.drawCircle(
      glowCenter,
      140 * s,
      Paint()
        ..shader = ui.Gradient.radial(
          glowCenter,
          140 * s,
          [const Color(0x1200FFFF), const Color(0x00000000)],
          [0.0, 1.0],
        ),
    );

    // Corner accents
    _drawPanelCorners(canvas, panelRect, s);

    // Score number — MASSIVE
    double sy = y + 40 * s;
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
    sy += sp.height + 6 * s;

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
      sy += 14 * s;
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
  ) {
    final fontSize = 56 * s;
    final lineGap = 32 * s;
    final panelW = w - 120 * s;
    final panelX = (w - panelW) / 2;

    // Build items — HUD-style with // prefix
    final items = <(String, String)>[];
    items.add(('// GLOBAL RANK', '#${_formatNumber(data.rank)}'));
    if (data.hasCountryData) {
      items.add((
        '// ${data.countryCode.toUpperCase()} RANK',
        '#${_formatNumber(data.countryRank!)}',
      ));
    }
    if (data.totalPlayers > 0) {
      final pct = data.topPercentage;
      final pctStr =
          pct < 1 ? pct.toStringAsFixed(1) : pct.toStringAsFixed(0);
      items.add(('// WORLD TOP', '$pctStr%'));
    }

    // Panel frame
    final itemH = fontSize + lineGap;
    final panelH = items.length * itemH + 48 * s;
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
    double iy = y + 24 * s;
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
  ) {
    final stats = <String>['LN ${data.lines}', 'LV ${data.level}'];
    if (data.playTime != null) {
      stats.add(_formatDuration(data.playTime!));
    }

    final text = stats.join('  ·  ');
    final p = _buildParagraph(
      text,
      fontSize: 40 * s,
      color: const Color(0xFF555555),
      letterSpacing: 4 * s,
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
  ) {
    // Top neon divider
    _drawNeonLine(canvas, 80 * s, y, w - 80 * s, y, s);
    y += 40 * s;

    // Challenge message
    final cp = _buildParagraph(
      data.challengeMessage,
      fontSize: 68 * s,
      color: _magenta,
      fontWeight: FontWeight.w600,
      letterSpacing: 2 * s,
      maxWidth: w - 100 * s,
      textAlign: TextAlign.center,
    );
    canvas.drawParagraph(cp, Offset((w - cp.width) / 2, y));
    y += cp.height + 22 * s;

    // CTA
    final ctap = _buildParagraph(
      data.ctaMessage,
      fontSize: 48 * s,
      color: const Color(0xFFB0B0B0),
      letterSpacing: 2 * s,
      maxWidth: w - 100 * s,
      textAlign: TextAlign.center,
    );
    canvas.drawParagraph(ctap, Offset((w - ctap.width) / 2, y));
    y += ctap.height + 18 * s;

    // URL
    final up = _buildParagraph(
      'cyberblockx.com',
      fontSize: 34 * s,
      color: const Color(0x9900FFFF),
      letterSpacing: 3 * s,
      maxWidth: w,
      textAlign: TextAlign.center,
    );
    canvas.drawParagraph(up, Offset((w - up.width) / 2, y));
    y += up.height + 30 * s;

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
      fontSize: 28 * s,
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
    final hudTexts = ['// DATA_VERIFIED', 'SYS.ACTIVE', 'LINK//READY', '▸ SIGNAL_OK'];
    for (int i = 0; i < hudTexts.length; i++) {
      final ty = startY + zone * (0.15 + 0.30 * i);
      if (ty > endY - 15 * s) break;
      final tx = (i % 2 == 0) ? 80 * s : w - 260 * s;
      final p = _buildParagraph(
        hudTexts[i],
        fontSize: 20 * s,
        color: Color(i % 2 == 0 ? 0x1500FFFF : 0x12FF00FF),
        letterSpacing: 4 * s,
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
      // Additional L-piece
      (
        Offset(w * 0.55, startY + zone * 0.15),
        [
          [0, 0],
          [0, 1],
          [0, 2],
          [1, 2],
        ],
        const Color(0x0AFF00FF),
      ),
      // Additional S-piece
      (
        Offset(w * 0.85, startY + zone * 0.60),
        [
          [1, 0],
          [2, 0],
          [0, 1],
          [1, 1],
        ],
        const Color(0x0C00FFFF),
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

    // 2b. Small grid overlay patches (3×3 at 6% opacity)
    final gridPaint = Paint()
      ..color = const Color(0x0F00FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 * s;
    final gridSize = 10 * s;
    for (final (gx, gy) in [
      (w * 0.15, startY + zone * 0.50),
      (w * 0.75, startY + zone * 0.30),
    ]) {
      if (gy + gridSize * 3 > endY) continue;
      for (int gi = 0; gi < 3; gi++) {
        for (int gj = 0; gj < 3; gj++) {
          canvas.drawRect(
            Rect.fromLTWH(gx + gi * gridSize, gy + gj * gridSize, gridSize, gridSize),
            gridPaint,
          );
        }
      }
    }

    // 3. Faint scan lines
    for (final frac in [0.20, 0.40, 0.60, 0.80]) {
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

    // 4. Mini brackets — HUD corner elements
    if (zone > 100 * s) {
      _drawMiniBracket(canvas, Offset(w * 0.48, startY + zone * 0.40), s);
      _drawMiniBracket(canvas, Offset(w * 0.20, startY + zone * 0.65), s);
      _drawMiniBracket(canvas, Offset(w * 0.80, startY + zone * 0.50), s);
    }
  }

  /// Tetromino outlines + accent lines for the bottom zone
  static void _drawTetrominoDecoration(
    Canvas canvas,
    double w,
    double h,
    double startY,
    double s,
  ) {
    final footerY = h - 60 * s;
    if (startY + 40 * s > footerY) return;

    final blockSize = 24 * s;
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
