import 'dart:math';
import '../../core/board.dart';
import '../../core/tetromino.dart';

/// Placement candidate: a specific position + rotation for a piece.
class Placement {
  final int x;
  final int rotation;
  final double score;

  const Placement({required this.x, required this.rotation, required this.score});
}

/// Evaluates board positions to find optimal piece placements.
///
/// Uses a weighted heuristic:
///   -0.51 * aggregateHeight
///   +0.76 * completedLines
///   -0.36 * holes
///   -0.18 * bumpiness
///   + aggressiveness * tetrisBonus
class BotEvaluator {
  final double aggressiveness;

  // Heuristic weights (tuned for balanced play)
  static const double _wHeight = -0.51;
  static const double _wLines = 0.76;
  static const double _wHoles = -0.36;
  static const double _wBumpiness = -0.18;
  static const double _wTetris = 0.8;

  const BotEvaluator({this.aggressiveness = 0.5});

  /// Find the best placement for a piece on the board.
  /// Returns null if no valid placement exists.
  Placement? findBestPlacement(Board board, TetrominoType pieceType, {double mistakeRate = 0.0}) {
    final placements = _getAllPlacements(board, pieceType);
    if (placements.isEmpty) return null;

    // Sort by score (best first)
    placements.sort((a, b) => b.score.compareTo(a.score));

    // Apply mistake model: chance of picking suboptimal placement
    if (mistakeRate > 0 && placements.length > 1) {
      final roll = Random().nextDouble();
      if (roll < mistakeRate) {
        // Pick 2nd or 3rd best
        final index = min(1 + Random().nextInt(min(2, placements.length - 1)), placements.length - 1);
        return placements[index];
      }
    }

    return placements.first;
  }

  /// Generate all valid placements and score them.
  List<Placement> _getAllPlacements(Board board, TetrominoType pieceType) {
    final placements = <Placement>[];

    for (int rotation = 0; rotation < 4; rotation++) {
      // O-piece only has 1 meaningful rotation
      if (pieceType == TetrominoType.O && rotation > 0) break;

      for (int x = -2; x < board.width + 2; x++) {
        final piece = Tetromino(
          type: pieceType,
          x: x,
          y: board.height - 1,
          rotation: rotation,
        );

        // Check if this starting position is at least partially valid
        if (!_isInBounds(piece, board)) continue;

        // Drop piece to bottom
        final landed = _dropPiece(piece, board);
        if (landed == null) continue;

        // Simulate placement and evaluate
        final score = _evaluatePlacement(board, landed);
        placements.add(Placement(x: x, rotation: rotation, score: score));
      }
    }

    return placements;
  }

  /// Drop a piece to its final resting position.
  Tetromino? _dropPiece(Tetromino piece, Board board) {
    final dropped = piece.copy();
    while (board.canPlace(dropped)) {
      dropped.y--;
    }
    dropped.y++;

    // Verify final position is valid
    if (!board.canPlace(dropped)) return null;
    return dropped;
  }

  /// Check if piece is at least partially in bounds (for wide search).
  bool _isInBounds(Tetromino piece, Board board) {
    for (final pos in piece.absolutePositions) {
      if (pos.x >= 0 && pos.x < board.width) return true;
    }
    return false;
  }

  /// Evaluate a board state after placing a piece.
  double _evaluatePlacement(Board board, Tetromino piece) {
    // Create a temporary board copy
    final tempBoard = _simulatePlacement(board, piece);
    if (tempBoard == null) return double.negativeInfinity;

    // Count lines that would be cleared
    int completedLines = 0;
    for (int y = 0; y < tempBoard.height; y++) {
      bool full = true;
      for (int x = 0; x < tempBoard.width; x++) {
        if (!tempBoard.getCell(x, y).filled) {
          full = false;
          break;
        }
      }
      if (full) completedLines++;
    }

    // Calculate board metrics (after clearing lines)
    final heights = _getColumnHeights(tempBoard);
    final aggregateHeight = heights.fold<int>(0, (a, b) => a + b);
    final holes = _countHoles(tempBoard);
    final bumpiness = _calculateBumpiness(heights);
    final tetrisBonus = completedLines == 4 ? 4.0 : 0.0;

    return _wHeight * aggregateHeight +
        _wLines * completedLines * 4.0 +
        _wHoles * holes +
        _wBumpiness * bumpiness +
        _wTetris * aggressiveness * tetrisBonus;
  }

  /// Simulate placing a piece on a copy of the board.
  Board? _simulatePlacement(Board board, Tetromino piece) {
    final temp = Board(width: board.width, height: board.height);
    // Copy grid
    for (int y = 0; y < board.height; y++) {
      for (int x = 0; x < board.width; x++) {
        final cell = board.getCell(x, y);
        if (cell.filled) {
          temp.setCell(x, y, cell);
        }
      }
    }
    // Place piece
    if (!temp.canPlace(piece)) return null;
    temp.lockPiece(piece);
    return temp;
  }

  /// Get the height of each column.
  List<int> _getColumnHeights(Board board) {
    final heights = List.filled(board.width, 0);
    for (int x = 0; x < board.width; x++) {
      for (int y = board.height - 1; y >= 0; y--) {
        if (board.getCell(x, y).filled) {
          heights[x] = y + 1;
          break;
        }
      }
    }
    return heights;
  }

  /// Count holes (empty cells with filled cells above them).
  int _countHoles(Board board) {
    int holes = 0;
    for (int x = 0; x < board.width; x++) {
      bool foundFilled = false;
      for (int y = board.height - 1; y >= 0; y--) {
        if (board.getCell(x, y).filled) {
          foundFilled = true;
        } else if (foundFilled) {
          holes++;
        }
      }
    }
    return holes;
  }

  /// Calculate bumpiness (sum of absolute height differences between adjacent columns).
  int _calculateBumpiness(List<int> heights) {
    int bumpiness = 0;
    for (int i = 0; i < heights.length - 1; i++) {
      bumpiness += (heights[i] - heights[i + 1]).abs();
    }
    return bumpiness;
  }
}
