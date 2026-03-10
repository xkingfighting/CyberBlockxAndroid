/// Render-only data for the opponent ghost board.
///
/// This is a lightweight projection of the opponent's board state,
/// optimized for rendering. It does NOT contain full game state -
/// only what's needed to draw the ghost overlay.
class OpponentProjection {
  /// 10x20 grid, true = filled cell.
  final List<List<bool>> boardGrid;

  /// Opponent's current stats.
  final int score;
  final int level;
  final int lines;
  final bool isAlive;

  /// Rendering configuration.
  final double opacity;
  final String colorPalette; // "ghost", "danger", "lead"

  /// Recent line clear animation (rows that were just cleared).
  final List<int> recentClearRows;
  final double recentClearDecay; // 0.0-1.0, fades over 0.5s

  const OpponentProjection({
    required this.boardGrid,
    this.score = 0,
    this.level = 1,
    this.lines = 0,
    this.isAlive = true,
    this.opacity = 0.28,
    this.colorPalette = 'ghost',
    this.recentClearRows = const [],
    this.recentClearDecay = 0.0,
  });

  /// Create an empty projection (no blocks).
  factory OpponentProjection.empty() => OpponentProjection(
        boardGrid: List.generate(20, (_) => List.filled(10, false)),
      );
}
