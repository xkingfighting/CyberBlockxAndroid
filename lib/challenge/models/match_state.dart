/// Match lifecycle state and player state tracking.

/// Match lifecycle phases.
enum MatchPhase {
  idle,
  searching,
  matched,
  countdown,
  playing,
  finishing,
  result,
}

/// Per-player state during a match.
class PlayerMatchState {
  final String playerId;
  final String displayName;
  final bool isBot;
  int score;
  int level;
  int lines;
  int combo;
  bool isAlive;

  PlayerMatchState({
    required this.playerId,
    required this.displayName,
    this.isBot = false,
    this.score = 0,
    this.level = 1,
    this.lines = 0,
    this.combo = 0,
    this.isAlive = true,
  });

  PlayerMatchState copyWith({
    int? score,
    int? level,
    int? lines,
    int? combo,
    bool? isAlive,
  }) =>
      PlayerMatchState(
        playerId: playerId,
        displayName: displayName,
        isBot: isBot,
        score: score ?? this.score,
        level: level ?? this.level,
        lines: lines ?? this.lines,
        combo: combo ?? this.combo,
        isAlive: isAlive ?? this.isAlive,
      );
}
