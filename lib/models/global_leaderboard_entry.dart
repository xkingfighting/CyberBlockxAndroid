/// Global Leaderboard Entry from server
class GlobalLeaderboardEntry {
  final int rank;
  final String walletAddress;
  final String? username;
  final String? userId;
  final int bestLines;    // Best lines cleared (ranking criteria)
  final int bestScore;    // Best score
  final int level;
  final int playCount;

  GlobalLeaderboardEntry({
    required this.rank,
    required this.walletAddress,
    this.username,
    this.userId,
    required this.bestLines,
    required this.bestScore,
    required this.level,
    this.playCount = 0,
  });

  /// Display name - prefers username, falls back to short wallet address
  String get name {
    if (username != null && username!.isNotEmpty) {
      return username!;
    }
    return shortAddress;
  }

  /// Short wallet address (e.g., "Abc1...xyz9")
  String get shortAddress {
    if (walletAddress.length > 10) {
      return '${walletAddress.substring(0, 4)}...${walletAddress.substring(walletAddress.length - 4)}';
    }
    return walletAddress;
  }

  factory GlobalLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return GlobalLeaderboardEntry(
      rank: _parseInt(json['rank']),
      walletAddress: json['walletAddress'] as String? ?? json['wallet_address'] as String? ?? '',
      username: json['username'] as String?,
      userId: json['userId']?.toString(),
      bestLines: _parseInt(json['bestLines']),
      bestScore: _parseInt(json['bestScore']),
      level: _parseInt(json['level']),
      playCount: _parseInt(json['playCount']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'walletAddress': walletAddress,
      'username': username,
      'userId': userId,
      'bestLines': bestLines,
      'bestScore': bestScore,
      'level': level,
      'playCount': playCount,
    };
  }
}
