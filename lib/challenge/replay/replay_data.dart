import 'dart:math';

/// A single recorded action with timestamp.
class ReplayAction {
  final int timestampMs; // ms since match start
  final int actionCode; // 0-6

  const ReplayAction(this.timestampMs, this.actionCode);

  List<int> toJson() => [timestampMs, actionCode];

  factory ReplayAction.fromJson(List<dynamic> json) =>
      ReplayAction(json[0] as int, json[1] as int);

  // Action code constants
  static const int left = 0;
  static const int right = 1;
  static const int rotateCW = 2;
  static const int rotateCCW = 3;
  static const int hardDrop = 4;
  static const int softDrop = 5;
  static const int hold = 6;

  /// Map bot action string to action code.
  static int fromActionString(String action) {
    return switch (action) {
      'left' => left,
      'right' => right,
      'rotate_cw' => rotateCW,
      'rotate_ccw' => rotateCCW,
      'hard_drop' => hardDrop,
      'soft_drop' => softDrop,
      'hold' => hold,
      _ => -1,
    };
  }
}

/// Complete replay data for a challenge match.
class ReplayData {
  final int version;
  final String matchId;
  final int seed;
  final int duration;
  final String modeType;
  final String opponentName;
  final String outcome;
  final List<ReplayAction> playerActions;
  final List<ReplayAction> opponentActions;

  const ReplayData({
    this.version = 1,
    required this.matchId,
    required this.seed,
    required this.duration,
    required this.modeType,
    required this.opponentName,
    required this.outcome,
    required this.playerActions,
    required this.opponentActions,
  });

  /// Total match duration based on the latest action timestamp.
  int get totalDurationMs {
    int last = 0;
    if (playerActions.isNotEmpty) {
      last = max(last, playerActions.last.timestampMs);
    }
    if (opponentActions.isNotEmpty) {
      last = max(last, opponentActions.last.timestampMs);
    }
    return last;
  }

  Map<String, dynamic> toJson() => {
        'v': version,
        'mid': matchId,
        'seed': seed,
        'dur': duration,
        'mode': modeType,
        'opp': opponentName,
        'out': outcome,
        'pa': playerActions.map((a) => a.toJson()).toList(),
        'oa': opponentActions.map((a) => a.toJson()).toList(),
      };

  factory ReplayData.fromJson(Map<String, dynamic> json) => ReplayData(
        version: json['v'] as int? ?? 1,
        matchId: json['mid'] as String? ?? '',
        seed: json['seed'] as int? ?? 0,
        duration: json['dur'] as int? ?? 0,
        modeType: json['mode'] as String? ?? 'score_race',
        opponentName: json['opp'] as String? ?? 'Opponent',
        outcome: json['out'] as String? ?? '',
        playerActions: (json['pa'] as List? ?? [])
            .map((e) => ReplayAction.fromJson(e as List))
            .toList(),
        opponentActions: (json['oa'] as List? ?? [])
            .map((e) => ReplayAction.fromJson(e as List))
            .toList(),
      );
}
