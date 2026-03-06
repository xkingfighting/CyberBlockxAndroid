import '../utils/country_flags.dart';
import '../services/api_service.dart';

/// Data model for the share card, built from ScoreSubmitResponse + local game data.
class ShareCardData {
  final int score;
  final int lines;
  final int level;
  final int rank;
  final int? countryRank;
  final String countryCode;
  final int countryTotal;
  final int totalPlayers;
  final String shareId;
  final String username;
  final bool isNewRecord;
  final String platform; // 'android' | 'ios' | 'seeker'
  final Duration? playTime;

  ShareCardData({
    required this.score,
    required this.lines,
    required this.level,
    required this.rank,
    this.countryRank,
    this.countryCode = '',
    this.countryTotal = 0,
    this.totalPlayers = 0,
    this.shareId = '',
    this.username = '',
    this.isNewRecord = false,
    this.platform = 'android',
    this.playTime,
  });

  /// World top percentage (lower is better)
  double get topPercentage {
    if (totalPlayers <= 0 || rank <= 0) return 100.0;
    return (rank / totalPlayers * 100).clamp(0.01, 100.0);
  }

  /// Emoji flag for user's country
  String get countryFlag => countryCodeToEmoji(countryCode);

  /// Country name
  String get countryName => countryCodeToName(countryCode);

  /// Whether we have country data
  bool get hasCountryData => countryCode.isNotEmpty && countryRank != null;

  /// Challenge message
  String get challengeMessage {
    switch (platform) {
      case 'seeker':
        return 'Powered by Solana Seeker';
      default:
        return 'Can you beat my score?';
    }
  }

  /// Call-to-action message
  String get ctaMessage => 'Join the Cyber Arena';

  /// Platform identity badge
  String get platformBadge {
    switch (platform) {
      case 'seeker':
        return '// SEEKER VERIFIED PLAYER';
      case 'ios':
        return '// PLAYED ON IOS';
      default:
        return '// PLAYED ON ANDROID';
    }
  }

  /// Build from ScoreSubmitResponse + local game data
  /// Uses scoreRank/scoreCountryRank (current game's rank) instead of rank/countryRank (best score's rank)
  factory ShareCardData.fromSubmitResponse({
    required ScoreSubmitResponse response,
    required int level,
    required String platform,
    Duration? playTime,
  }) {
    return ShareCardData(
      score: response.score,
      lines: response.lines,
      level: level,
      rank: response.scoreRank,
      countryRank: response.scoreCountryRank ?? response.countryRank,
      countryCode: response.countryCode,
      countryTotal: response.countryTotal,
      totalPlayers: response.totalPlayers,
      shareId: response.shareId,
      username: response.username,
      isNewRecord: response.isNewRecord,
      platform: platform,
      playTime: playTime,
    );
  }
}

/// Share card size presets — only Story (1080×1920) is supported.
enum ShareCardSize {
  story(1080, 1920, 'Story'); // 9:16 vertical, optimized for mobile sharing

  final int width;
  final int height;
  final String label;

  const ShareCardSize(this.width, this.height, this.label);
}
