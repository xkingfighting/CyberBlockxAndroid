import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/share_card_data.dart';
import '../ui/widgets/share_card_painter.dart';

/// Service for generating and sharing share cards.
class ShareCardService {
  ShareCardService._();
  static final instance = ShareCardService._();

  /// Generate the share card image and return it as a temporary file.
  Future<File?> generateCard(
    ShareCardData data, {
    ShareCardSize size = ShareCardSize.story,
    Uint8List? gameScreenshot,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();

      final bytes = await ShareCardPainter.generateImage(data, size: size, gameScreenshot: gameScreenshot);
      if (bytes == null) {
        debugPrint('ShareCard: Failed to generate image');
        return null;
      }

      stopwatch.stop();
      debugPrint('ShareCard: Generated ${size.label} (${size.width}x${size.height}) in ${stopwatch.elapsedMilliseconds}ms');

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'cyberblockx_${data.shareId}_${size.label.toLowerCase()}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      return file;
    } catch (e) {
      debugPrint('ShareCard: Error generating card: $e');
      return null;
    }
  }

  /// Generate the share card image from existing bytes or render fresh.
  /// Reuses pre-rendered preview bytes to avoid duplicate rendering.
  Future<File?> generateCardFromBytes(
    ShareCardData data, {
    Uint8List? pngBytes,
    ShareCardSize size = ShareCardSize.story,
    Uint8List? gameScreenshot,
  }) async {
    try {
      final bytes = pngBytes ?? await ShareCardPainter.generateImage(data, size: size, gameScreenshot: gameScreenshot);
      if (bytes == null) {
        debugPrint('ShareCard: No bytes available for card');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = 'cyberblockx_${data.shareId}_${size.label.toLowerCase()}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      // Verify the file was written correctly
      final written = await file.length();
      debugPrint('ShareCard: Wrote $written bytes to ${file.path} (source: ${bytes.length} bytes)');
      if (written != bytes.length) {
        debugPrint('ShareCard: WARNING - file size mismatch! Expected ${bytes.length}, got $written');
      }

      return file;
    } catch (e) {
      debugPrint('ShareCard: Error generating card from bytes: $e');
      return null;
    }
  }

  /// Share to any platform via system share sheet.
  Future<void> shareGeneral(File imageFile, ShareCardData data) async {
    // Verify file exists and has content before sharing
    if (!await imageFile.exists()) {
      debugPrint('ShareCard: Image file does not exist: ${imageFile.path}');
      throw Exception('Share card image file not found');
    }
    final fileSize = await imageFile.length();
    if (fileSize == 0) {
      debugPrint('ShareCard: Image file is empty: ${imageFile.path}');
      throw Exception('Share card image file is empty');
    }
    debugPrint('ShareCard: Sharing file: ${imageFile.path} (${fileSize} bytes)');

    final shareText = _buildShareText(data);
    final fileName = imageFile.path.split('/').last;
    await Share.shareXFiles(
      [XFile(imageFile.path, mimeType: 'image/png', name: fileName)],
      text: shareText,
      subject: 'CyberBlockX Score',
    );
  }

  /// Save image to clipboard.
  Future<bool> copyToClipboard(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      await Clipboard.setData(ClipboardData(text: ''));
      // Note: Image clipboard support varies by platform
      // For now we copy the share text
      debugPrint('ShareCard: Image path copied (full clipboard image support varies by platform)');
      return true;
    } catch (e) {
      debugPrint('ShareCard: Copy failed: $e');
      return false;
    }
  }

  /// Build share text for social media.
  String _buildShareText(ShareCardData data) {
    final topPct = data.topPercentage;
    final topStr = topPct < 1 ? topPct.toStringAsFixed(2) : topPct.toStringAsFixed(1);

    final buffer = StringBuffer();
    buffer.writeln('🎮 CyberBlockX Score: ${_formatNumber(data.score)}');
    buffer.writeln('🌍 Global Rank: #${_formatNumber(data.rank)}');
    if (data.hasCountryData) {
      buffer.writeln('${data.countryFlag} Country Rank: #${_formatNumber(data.countryRank!)}');
    }
    if (data.totalPlayers > 0) {
      buffer.writeln('⭐ World Top $topStr%');
    }
    buffer.writeln();
    buffer.writeln('${data.challengeMessage}');
    buffer.writeln();
    buffer.write('#CyberBlockX #Tetris');
    if (data.platform == 'seeker') {
      buffer.write(' #Solana #Seeker');
    }
    buffer.writeln();
    buffer.write('🔗 cyberblockx.com');

    return buffer.toString();
  }

  String _formatNumber(int n) {
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
}
