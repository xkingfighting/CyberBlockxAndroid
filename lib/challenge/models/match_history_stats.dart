/// Aggregated match history statistics.
class MatchHistoryStats {
  final int totalMatches;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;
  final int currentStreak;
  final int bestStreak;
  final int bestScore;
  final String bestScoreMode;
  final String? bestScoreMatchId;
  final int longestSurvival;
  final String? longestSurvivalMatchId;
  final int totalRewards;
  final int? currentRating;
  final List<String> recentForm;
  final int avgScore;
  final int avgDuration;
  final double botWinRate;
  final double? playerWinRate;

  const MatchHistoryStats({
    this.totalMatches = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.winRate = 0.0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.bestScore = 0,
    this.bestScoreMode = 'score_race',
    this.bestScoreMatchId,
    this.longestSurvival = 0,
    this.longestSurvivalMatchId,
    this.totalRewards = 0,
    this.currentRating,
    this.recentForm = const [],
    this.avgScore = 0,
    this.avgDuration = 0,
    this.botWinRate = 0.0,
    this.playerWinRate,
  });

  factory MatchHistoryStats.fromJson(Map<String, dynamic> json) {
    final formList = json['recentForm'] as List?;
    return MatchHistoryStats(
      totalMatches: json['totalMatches'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      winRate: (json['winRate'] as num?)?.toDouble() ?? 0.0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      bestScore: json['bestScore'] as int? ?? 0,
      bestScoreMode: json['bestScoreMode'] as String? ?? 'score_race',
      bestScoreMatchId: json['bestScoreMatchId'] as String?,
      longestSurvival: json['longestSurvival'] as int? ?? 0,
      longestSurvivalMatchId: json['longestSurvivalMatchId'] as String?,
      totalRewards: json['totalRewards'] as int? ?? 0,
      currentRating: json['currentRating'] as int?,
      recentForm: formList?.map((e) => e.toString()).toList() ?? const [],
      avgScore: json['avgScore'] as int? ?? 0,
      avgDuration: json['avgDuration'] as int? ?? 0,
      botWinRate: (json['botWinRate'] as num?)?.toDouble() ?? 0.0,
      playerWinRate: (json['playerWinRate'] as num?)?.toDouble(),
    );
  }
}
