import '../models/match_config.dart';

/// Predefined bot difficulty profiles.
class BotProfiles {
  static const beginner = BotProfileConfig(
    profileId: 'beginner',
    moveDelayMs: [120, 300],
    thinkDelayMs: [300, 600],
    mistakeRate: 0.25,
    aggressiveness: 0.2,
    stutterChance: 0.08,
    speedVariance: 0.2,
    evaluationDepth: 1,
  );

  static const balanced = BotProfileConfig(
    profileId: 'balanced',
    moveDelayMs: [80, 180],
    thinkDelayMs: [200, 400],
    mistakeRate: 0.10,
    aggressiveness: 0.5,
    stutterChance: 0.05,
    speedVariance: 0.15,
    evaluationDepth: 1,
  );

  static const aggressive = BotProfileConfig(
    profileId: 'aggressive',
    moveDelayMs: [50, 120],
    thinkDelayMs: [100, 250],
    mistakeRate: 0.05,
    aggressiveness: 0.9,
    stutterChance: 0.02,
    speedVariance: 0.1,
    evaluationDepth: 2,
  );

  /// Bot display names (cyberpunk themed).
  static String displayName(String profileId) {
    switch (profileId) {
      case 'beginner':
        return 'SYSIM-01';
      case 'balanced':
        return 'NEXUS-7';
      case 'aggressive':
        return 'CIPHER-X';
      default:
        return 'BOT-${profileId.toUpperCase()}';
    }
  }
}
