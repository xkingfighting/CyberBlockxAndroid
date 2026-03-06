/// Global Leaderboard Entry from server
/// Privacy: username and walletAddress are masked at parse time — raw values never stored.
class GlobalLeaderboardEntry {
  final int rank;
  /// Already masked (first4...last4) — raw address never stored
  final String walletAddress;
  /// Already masked at parse time — raw value never stored
  final String? username;
  final String? userId;
  final int bestLines;    // Best lines cleared (ranking criteria)
  final int bestScore;    // Best score
  final int level;
  final int playCount;
  final String countryCode; // ISO 3166-1 Alpha-2, e.g. "US" (empty if unknown)

  GlobalLeaderboardEntry._({
    required this.rank,
    required this.walletAddress,
    this.username,
    this.userId,
    required this.bestLines,
    required this.bestScore,
    required this.level,
    this.playCount = 0,
    this.countryCode = '',
  });

  /// Display name: prefers username (already masked), falls back to CBX-000123
  String get name {
    if (username != null && username!.isNotEmpty) {
      return username!;
    }
    if (userId != null && userId!.isNotEmpty) {
      final numId = int.tryParse(userId!);
      if (numId != null) {
        return 'CBX-${numId.toString().padLeft(6, '0')}';
      }
      return 'CBX-$userId';
    }
    return '---';
  }

  /// Short wallet address (already masked at parse time)
  String get shortAddress => walletAddress;

  factory GlobalLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final rawName = json['username'] as String?;
    final rawWallet = json['walletAddress'] as String? ?? json['wallet_address'] as String? ?? '';

    return GlobalLeaderboardEntry._(
      rank: _parseInt(json['rank']),
      walletAddress: _maskWallet(rawWallet),
      username: (rawName != null && rawName.isNotEmpty) ? _maskName(rawName) : null,
      userId: json['userId']?.toString(),
      bestLines: _parseInt(json['bestLines']),
      bestScore: _parseInt(json['bestScore']),
      level: _parseInt(json['level']),
      playCount: _parseInt(json['playCount']),
      countryCode: json['countryCode'] as String? ?? '',
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // MARK: - Privacy masks (applied once at parse time)

  static String _maskName(String name) {
    if (name.startsWith('CBX-') || name.contains('...') || name == '---') {
      return name;
    }
    // Email
    final atIndex = name.indexOf('@');
    if (atIndex > 0) {
      final local = name.substring(0, atIndex);
      final domain = name.substring(atIndex + 1);
      final ml = local.length > 2
          ? '${local.substring(0, 2)}***'
          : '${local.substring(0, 1)}***';
      final md = domain.length > 3
          ? '${domain.substring(0, 3)}...'
          : domain;
      return '$ml@$md';
    }
    if (name.length <= 3) return '${name.substring(0, 1)}***';
    if (name.length <= 5) return '${name.substring(0, 1)}***${name.substring(name.length - 1)}';
    return '${name.substring(0, 2)}****${name.substring(name.length - 2)}';
  }

  static String _maskWallet(String addr) {
    if (addr.isEmpty) return '';
    if (addr.length > 10) {
      return '${addr.substring(0, 4)}...${addr.substring(addr.length - 4)}';
    }
    return addr;
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
      'countryCode': countryCode,
    };
  }
}
