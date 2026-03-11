/// A single match history record from the server.
class MatchHistoryEntry {
  final String matchId;
  final String modeType;
  final String outcome;
  final String playedAt;
  final int durationSeconds;
  final String rulesetVersion;
  // Player stats
  final int playerScore;
  final int playerLines;
  final int playerLevel;
  final int playerPiecesPlaced;
  final int playerMaxCombo;
  final int playerTetrisCount;
  final int playerPerfectClears;
  // Opponent info
  final String opponentType;
  final String opponentName;
  final int opponentScore;
  final int opponentLines;
  final int opponentLevel;
  final int opponentPiecesPlaced;
  final String? opponentDifficulty;
  final String? opponentBotProfileId;
  final String? opponentPlayerId;
  final String? opponentAvatarId;
  // Match metadata
  final int reward;
  final String rewardType;
  final int? ratingChange;
  final int? newRating;
  final bool isNewRecord;
  final int seed;
  final int configDuration;
  final int entryFee;
  // Extensibility
  final String clientPlatform;
  final String matchSource;
  final bool replayAvailable;
  final String? seasonId;

  bool get isBot => opponentType == 'bot';
  int get scoreDelta => playerScore - opponentScore;

  /// Mode display label.
  String get modeLabel {
    switch (modeType) {
      case 'survival':
        return 'SURVIVAL';
      default:
        return 'SCORE RACE';
    }
  }

  const MatchHistoryEntry({
    required this.matchId,
    required this.modeType,
    required this.outcome,
    required this.playedAt,
    required this.durationSeconds,
    this.rulesetVersion = '1.0',
    required this.playerScore,
    required this.playerLines,
    required this.playerLevel,
    this.playerPiecesPlaced = 0,
    this.playerMaxCombo = 0,
    this.playerTetrisCount = 0,
    this.playerPerfectClears = 0,
    required this.opponentType,
    required this.opponentName,
    required this.opponentScore,
    this.opponentLines = 0,
    this.opponentLevel = 0,
    this.opponentPiecesPlaced = 0,
    this.opponentDifficulty,
    this.opponentBotProfileId,
    this.opponentPlayerId,
    this.opponentAvatarId,
    this.reward = 0,
    this.rewardType = 'none',
    this.ratingChange,
    this.newRating,
    this.isNewRecord = false,
    this.seed = 0,
    this.configDuration = 0,
    this.entryFee = 0,
    this.clientPlatform = '',
    this.matchSource = '',
    this.replayAvailable = false,
    this.seasonId,
  });

  factory MatchHistoryEntry.fromJson(Map<String, dynamic> json) {
    // Derive opponentType from opponentIsBot (legacy) if opponentType not present
    String opponentType = json['opponentType'] as String?
        ?? json['opponent_type'] as String?
        ?? '';
    if (opponentType.isEmpty) {
      final isBot = json['opponentIsBot'];
      if (isBot != null) {
        opponentType = (isBot == 1 || isBot == true) ? 'bot' : 'player';
      } else {
        opponentType = 'bot';
      }
    }

    return MatchHistoryEntry(
      matchId: json['matchId'] as String? ?? json['match_id'] as String? ?? '',
      modeType: json['modeType'] as String? ?? json['mode_type'] as String? ?? 'score_race',
      outcome: json['outcome'] as String? ?? json['result'] as String? ?? 'lose',
      playedAt: json['playedAt'] as String?
          ?? json['played_at'] as String?
          ?? json['finishedAt'] as String?
          ?? json['finished_at'] as String? ?? '',
      durationSeconds: json['durationSeconds'] as int?
          ?? json['duration_seconds'] as int?
          ?? json['duration'] as int? ?? 0,
      rulesetVersion: json['rulesetVersion'] as String? ?? json['ruleset_version'] as String? ?? '1.0',
      playerScore: json['playerScore'] as int?
          ?? json['player_score'] as int?
          ?? json['myScore'] as int?
          ?? json['score'] as int? ?? 0,
      playerLines: json['playerLines'] as int?
          ?? json['player_lines'] as int?
          ?? json['myLines'] as int?
          ?? json['lines'] as int? ?? 0,
      playerLevel: json['playerLevel'] as int?
          ?? json['player_level'] as int?
          ?? json['level'] as int? ?? 0,
      playerPiecesPlaced: json['playerPiecesPlaced'] as int?
          ?? json['player_pieces_placed'] as int?
          ?? json['piecesPlaced'] as int? ?? 0,
      playerMaxCombo: json['playerMaxCombo'] as int? ?? json['player_max_combo'] as int? ?? 0,
      playerTetrisCount: json['playerTetrisCount'] as int? ?? json['player_tetris_count'] as int? ?? 0,
      playerPerfectClears: json['playerPerfectClears'] as int? ?? json['player_perfect_clears'] as int? ?? 0,
      opponentType: opponentType,
      opponentName: json['opponentName'] as String? ?? json['opponent_name'] as String? ?? 'Opponent',
      opponentScore: json['opponentScore'] as int? ?? json['opponent_score'] as int? ?? 0,
      opponentLines: json['opponentLines'] as int? ?? json['opponent_lines'] as int? ?? 0,
      opponentLevel: json['opponentLevel'] as int? ?? json['opponent_level'] as int? ?? 0,
      opponentPiecesPlaced: json['opponentPiecesPlaced'] as int? ?? json['opponent_pieces_placed'] as int? ?? 0,
      opponentDifficulty: json['opponentDifficulty'] as String? ?? json['opponent_difficulty'] as String?,
      opponentBotProfileId: json['opponentBotProfileId'] as String? ?? json['opponent_bot_profile_id'] as String?,
      opponentPlayerId: json['opponentPlayerId'] as String? ?? json['opponent_player_id'] as String?,
      opponentAvatarId: json['opponentAvatarId'] as String? ?? json['opponent_avatar_id'] as String?,
      reward: json['reward'] as int? ?? json['prizePool'] as int? ?? 0,
      rewardType: json['rewardType'] as String? ?? json['reward_type'] as String? ?? 'none',
      ratingChange: json['ratingChange'] as int? ?? json['rating_change'] as int?,
      newRating: json['newRating'] as int? ?? json['new_rating'] as int?,
      isNewRecord: json['isNewRecord'] as bool? ?? json['is_new_record'] as bool? ?? false,
      seed: json['seed'] as int? ?? 0,
      configDuration: json['configDuration'] as int? ?? json['config_duration'] as int? ?? 0,
      entryFee: json['entryFee'] as int? ?? json['entry_fee'] as int? ?? 0,
      clientPlatform: json['clientPlatform'] as String? ?? json['client_platform'] as String? ?? '',
      matchSource: json['matchSource'] as String? ?? json['match_source'] as String? ?? '',
      replayAvailable: json['replayAvailable'] as bool? ?? json['replay_available'] as bool? ?? false,
      seasonId: json['seasonId'] as String? ?? json['season_id'] as String?,
    );
  }

  /// Human-readable difficulty label for bot opponents.
  String? get difficultyLabel {
    if (!isBot || opponentDifficulty == null) return null;
    switch (opponentDifficulty) {
      case 'easy':
        return 'Easy';
      case 'medium':
        return 'Medium';
      case 'hard':
        return 'Hard';
      default:
        return opponentDifficulty;
    }
  }

  /// Format duration as "M:SS".
  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Format date for display.
  String get formattedDate {
    try {
      final dt = DateTime.parse(playedAt);
      final now = DateTime.now();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      if (dt.year == now.year) {
        return '${months[dt.month - 1]} ${dt.day}';
      }
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  /// Format full date+time for detail page.
  String get formattedDateTime {
    try {
      final dt = DateTime.parse(playedAt);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} $h:$m';
    } catch (_) {
      return '';
    }
  }
}
