/// Challenge Mode data models.
///
/// These mirror the backend API response structures and define
/// the complete match configuration, state, and result types.

/// Scoring rule configuration.
class ScoringRule {
  final String type; // "standard", future: "attack_bonus", "speed_bonus"
  final double multiplier;

  const ScoringRule({this.type = 'standard', this.multiplier = 1.0});

  factory ScoringRule.fromJson(Map<String, dynamic> json) => ScoringRule(
        type: json['type'] as String? ?? 'standard',
        multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toJson() => {'type': type, 'multiplier': multiplier};
}

/// Win condition configuration.
class WinCondition {
  final String type; // "highest_score", "first_to_target", "last_standing", "most_lines"
  final int? targetScore;

  const WinCondition({this.type = 'highest_score', this.targetScore});

  factory WinCondition.fromJson(Map<String, dynamic> json) => WinCondition(
        type: json['type'] as String? ?? 'highest_score',
        targetScore: json['targetScore'] as int?,
      );

  Map<String, dynamic> toJson() => {'type': type, if (targetScore != null) 'targetScore': targetScore};
}

/// Visibility rules for opponent ghost board.
class VisibilityRule {
  final bool showOpponentScore;
  final bool showOpponentBoard;
  final double ghostOpacity;

  const VisibilityRule({
    this.showOpponentScore = true,
    this.showOpponentBoard = true,
    this.ghostOpacity = 0.12,
  });

  factory VisibilityRule.fromJson(Map<String, dynamic> json) => VisibilityRule(
        showOpponentScore: json['showOpponentScore'] as bool? ?? true,
        showOpponentBoard: json['showOpponentBoard'] as bool? ?? true,
        ghostOpacity: (json['ghostOpacity'] as num?)?.toDouble() ?? 0.12,
      );
}

/// Bot profile configuration from server.
class BotProfileConfig {
  final String profileId;
  final List<int> moveDelayMs; // [min, max]
  final List<int> thinkDelayMs; // [min, max]
  final double mistakeRate;
  final double aggressiveness;
  final double stutterChance;
  final double speedVariance;
  final int evaluationDepth;

  const BotProfileConfig({
    required this.profileId,
    this.moveDelayMs = const [80, 180],
    this.thinkDelayMs = const [200, 400],
    this.mistakeRate = 0.10,
    this.aggressiveness = 0.5,
    this.stutterChance = 0.05,
    this.speedVariance = 0.15,
    this.evaluationDepth = 1,
  });

  factory BotProfileConfig.fromJson(Map<String, dynamic> json) => BotProfileConfig(
        profileId: json['profileId'] as String? ?? 'bot_${json['id'] ?? 'default'}',
        moveDelayMs: (json['moveDelayMs'] as List?)?.cast<int>() ?? [80, 180],
        thinkDelayMs: (json['thinkDelayMs'] as List?)?.cast<int>() ?? [200, 400],
        mistakeRate: (json['mistakeRate'] as num?)?.toDouble() ?? 0.10,
        aggressiveness: (json['aggressiveness'] as num?)?.toDouble() ?? 0.5,
        stutterChance: (json['stutterChance'] as num?)?.toDouble() ?? 0.05,
        speedVariance: (json['speedVariance'] as num?)?.toDouble() ?? 0.15,
        evaluationDepth: json['evaluationDepth'] as int? ?? 1,
      );

  /// Map a difficulty string ("easy"/"medium"/"hard") to a local preset.
  static BotProfileConfig fromDifficulty(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return const BotProfileConfig(
          profileId: 'beginner', moveDelayMs: [120, 300], thinkDelayMs: [300, 600],
          mistakeRate: 0.25, aggressiveness: 0.2, stutterChance: 0.08, speedVariance: 0.2,
        );
      case 'medium':
        return const BotProfileConfig(
          profileId: 'balanced', moveDelayMs: [80, 180], thinkDelayMs: [200, 400],
          mistakeRate: 0.10, aggressiveness: 0.5, stutterChance: 0.05, speedVariance: 0.15,
        );
      case 'hard':
        return const BotProfileConfig(
          profileId: 'aggressive', moveDelayMs: [50, 120], thinkDelayMs: [100, 250],
          mistakeRate: 0.05, aggressiveness: 0.9, stutterChance: 0.02, speedVariance: 0.1,
          evaluationDepth: 2,
        );
      default:
        return const BotProfileConfig(
          profileId: 'beginner', moveDelayMs: [120, 300], thinkDelayMs: [300, 600],
          mistakeRate: 0.25, aggressiveness: 0.2, stutterChance: 0.08, speedVariance: 0.2,
        );
    }
  }
}

/// Opponent info returned from match search.
class OpponentInfo {
  final String playerId;
  final String displayName;
  final bool isBot;
  final String avatarId;
  final BotProfileConfig? botProfile;

  const OpponentInfo({
    required this.playerId,
    required this.displayName,
    required this.isBot,
    this.avatarId = '',
    this.botProfile,
  });

  factory OpponentInfo.fromJson(Map<String, dynamic> json) {
    final isBot = json['isBot'] as bool? ?? false;
    final difficulty = json['difficulty'] as String? ?? 'easy';

    // Resolve bot profile: prefer detailed server params, fallback to difficulty preset
    BotProfileConfig? botProfile;
    if (isBot) {
      final botDict = json['botProfile'] as Map<String, dynamic>?;
      if (botDict != null && botDict.containsKey('moveDelayMs')) {
        botProfile = BotProfileConfig.fromJson(botDict);
      } else {
        botProfile = BotProfileConfig.fromDifficulty(difficulty);
      }
    }

    return OpponentInfo(
      playerId: json['playerId'] as String? ?? (isBot ? 'bot_${json['displayName'] ?? 'unknown'}' : 'unknown'),
      displayName: json['displayName'] as String? ?? 'Opponent',
      isBot: isBot,
      avatarId: json['avatarId'] as String? ?? json['avatar'] as String? ?? '',
      botProfile: botProfile,
    );
  }
}

/// Complete match configuration from server.
class MatchConfig {
  final String matchId;
  final String modeType; // "score_race", "speed_blitz", "survival"
  final int seed;
  final int duration; // seconds, 0 = unlimited
  final int entryFee;
  final int prizePool;
  final int startLevel;
  final ScoringRule scoringRule;
  final WinCondition winCondition;
  final VisibilityRule visibilityRule;
  final OpponentInfo opponent;

  const MatchConfig({
    required this.matchId,
    this.modeType = 'score_race',
    required this.seed,
    this.duration = 120,
    this.entryFee = 0,
    this.prizePool = 0,
    this.startLevel = 1,
    this.scoringRule = const ScoringRule(),
    this.winCondition = const WinCondition(),
    this.visibilityRule = const VisibilityRule(),
    required this.opponent,
  });

  factory MatchConfig.fromJson(Map<String, dynamic> json) {
    final config = json['config'] as Map<String, dynamic>? ?? json;
    final opponentJson = json['opponent'] as Map<String, dynamic>? ?? {};

    return MatchConfig(
      matchId: json['matchId'] as String? ?? config['matchId'] as String? ?? '',
      modeType: config['modeType'] as String? ?? 'score_race',
      seed: config['seed'] as int? ?? 0,
      duration: config['duration'] as int? ?? 120,
      entryFee: config['entryFee'] as int? ?? 0,
      prizePool: config['prizePool'] as int? ?? 0,
      startLevel: config['startLevel'] as int? ?? 1,
      scoringRule: config['scoringRule'] is Map<String, dynamic>
          ? ScoringRule.fromJson(config['scoringRule'] as Map<String, dynamic>)
          : ScoringRule(type: config['scoringRule'] as String? ?? 'standard'),
      winCondition: config['winCondition'] is Map<String, dynamic>
          ? WinCondition.fromJson(config['winCondition'] as Map<String, dynamic>)
          : WinCondition(type: config['winCondition'] as String? ?? 'highest_score'),
      visibilityRule: config['visibilityRule'] != null
          ? VisibilityRule.fromJson(config['visibilityRule'] as Map<String, dynamic>)
          : const VisibilityRule(),
      opponent: OpponentInfo.fromJson(opponentJson),
    );
  }
}
