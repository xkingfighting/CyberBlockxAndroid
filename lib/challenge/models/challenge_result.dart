/// Challenge match result data.

/// Match outcome.
enum MatchOutcome { win, lose, draw }

/// Full result returned after a challenge match.
class ChallengeResult {
  final String matchId;
  final MatchOutcome outcome;
  final int playerScore;
  final int playerLines;
  final int playerLevel;
  final int opponentScore;
  final int opponentLines;
  final int opponentLevel;
  final String opponentName;
  final bool isOpponentBot;
  final int reward;
  final int? ratingChange;
  final int? newRating;
  final bool isNewRecord;
  final int? rank;
  final Duration matchDuration;

  const ChallengeResult({
    required this.matchId,
    required this.outcome,
    required this.playerScore,
    required this.playerLines,
    required this.playerLevel,
    required this.opponentScore,
    required this.opponentLines,
    required this.opponentLevel,
    required this.opponentName,
    this.isOpponentBot = false,
    this.reward = 0,
    this.ratingChange,
    this.newRating,
    this.isNewRecord = false,
    this.rank,
    required this.matchDuration,
  });

  /// Create from server API response.
  factory ChallengeResult.fromJson(Map<String, dynamic> json, {
    required int playerLines,
    required int playerLevel,
    required int opponentLines,
    required int opponentLevel,
    required String opponentName,
    required bool isOpponentBot,
    required Duration matchDuration,
  }) {
    final resultStr = json['result'] as String? ?? 'lose';
    final outcome = resultStr == 'win'
        ? MatchOutcome.win
        : resultStr == 'draw'
            ? MatchOutcome.draw
            : MatchOutcome.lose;

    return ChallengeResult(
      matchId: json['matchId'] as String? ?? '',
      outcome: outcome,
      playerScore: json['playerScore'] as int? ?? 0,
      playerLines: playerLines,
      playerLevel: playerLevel,
      opponentScore: json['opponentScore'] as int? ?? 0,
      opponentLines: opponentLines,
      opponentLevel: opponentLevel,
      opponentName: opponentName,
      isOpponentBot: isOpponentBot,
      reward: json['reward'] as int? ?? 0,
      ratingChange: json['ratingChange'] as int?,
      newRating: json['newRating'] as int?,
      isNewRecord: json['isNewRecord'] as bool? ?? false,
      rank: json['rank'] as int?,
      matchDuration: matchDuration,
    );
  }
}
