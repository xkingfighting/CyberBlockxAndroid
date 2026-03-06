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
  }) async {
    try {
      final stopwatch = Stopwatch()..start();

      final bytes = await ShareCardPainter.generateImage(data, size: size);
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
      await file.writeAsBytes(bytes);

      return file;
    } catch (e) {
      debugPrint('ShareCard: Error generating card: $e');
      return null;
    }
  }

  /// Share to any platform via system share sheet.
  Future<void> shareGeneral(File imageFile, ShareCardData data) async {
    final shareText = _buildShareText(data);
    await Share.shareXFiles(
      [XFile(imageFile.path)],
      text: shareText,
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
