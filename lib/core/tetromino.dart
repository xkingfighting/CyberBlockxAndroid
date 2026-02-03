import 'dart:math';
import 'dart:ui';

/// Tetromino types
enum TetrominoType {
  I, O, T, S, Z, J, L;

  /// Get the color for this tetromino type (matching iOS exactly)
  Color get color {
    switch (this) {
      case TetrominoType.I:
        return const Color(0xFF00FFFF); // Cyan (r:0, g:1, b:1)
      case TetrominoType.O:
        return const Color(0xFFFFFF00); // Yellow (r:1, g:1, b:0)
      case TetrominoType.T:
        return const Color(0xFFCC00FF); // Purple (r:0.8, g:0, b:1)
      case TetrominoType.S:
        return const Color(0xFF00FF00); // Green (r:0, g:1, b:0)
      case TetrominoType.Z:
        return const Color(0xFFFF004D); // Red-Pink (r:1, g:0, b:0.3)
      case TetrominoType.J:
        return const Color(0xFF0066FF); // Blue (r:0, g:0.4, b:1)
      case TetrominoType.L:
        return const Color(0xFFFF8000); // Orange (r:1, g:0.5, b:0)
    }
  }

  /// Get the shape patterns for all rotations (4 states)
  List<List<Point<int>>> get shapes {
    switch (this) {
      case TetrominoType.I:
        return [
          [Point(0, 1), Point(1, 1), Point(2, 1), Point(3, 1)],
          [Point(2, 0), Point(2, 1), Point(2, 2), Point(2, 3)],
          [Point(0, 2), Point(1, 2), Point(2, 2), Point(3, 2)],
          [Point(1, 0), Point(1, 1), Point(1, 2), Point(1, 3)],
        ];
      case TetrominoType.O:
        return [
          [Point(0, 0), Point(1, 0), Point(0, 1), Point(1, 1)],
          [Point(0, 0), Point(1, 0), Point(0, 1), Point(1, 1)],
          [Point(0, 0), Point(1, 0), Point(0, 1), Point(1, 1)],
          [Point(0, 0), Point(1, 0), Point(0, 1), Point(1, 1)],
        ];
      case TetrominoType.T:
        return [
          [Point(1, 0), Point(0, 1), Point(1, 1), Point(2, 1)],
          [Point(1, 0), Point(1, 1), Point(2, 1), Point(1, 2)],
          [Point(0, 1), Point(1, 1), Point(2, 1), Point(1, 2)],
          [Point(1, 0), Point(0, 1), Point(1, 1), Point(1, 2)],
        ];
      case TetrominoType.S:
        return [
          [Point(1, 0), Point(2, 0), Point(0, 1), Point(1, 1)],
          [Point(1, 0), Point(1, 1), Point(2, 1), Point(2, 2)],
          [Point(1, 1), Point(2, 1), Point(0, 2), Point(1, 2)],
          [Point(0, 0), Point(0, 1), Point(1, 1), Point(1, 2)],
        ];
      case TetrominoType.Z:
        return [
          [Point(0, 0), Point(1, 0), Point(1, 1), Point(2, 1)],
          [Point(2, 0), Point(1, 1), Point(2, 1), Point(1, 2)],
          [Point(0, 1), Point(1, 1), Point(1, 2), Point(2, 2)],
          [Point(1, 0), Point(0, 1), Point(1, 1), Point(0, 2)],
        ];
      case TetrominoType.J:
        return [
          [Point(0, 0), Point(0, 1), Point(1, 1), Point(2, 1)],
          [Point(1, 0), Point(2, 0), Point(1, 1), Point(1, 2)],
          [Point(0, 1), Point(1, 1), Point(2, 1), Point(2, 2)],
          [Point(1, 0), Point(1, 1), Point(0, 2), Point(1, 2)],
        ];
      case TetrominoType.L:
        return [
          [Point(2, 0), Point(0, 1), Point(1, 1), Point(2, 1)],
          [Point(1, 0), Point(1, 1), Point(1, 2), Point(2, 2)],
          [Point(0, 1), Point(1, 1), Point(2, 1), Point(0, 2)],
          [Point(0, 0), Point(1, 0), Point(1, 1), Point(1, 2)],
        ];
    }
  }

  /// Spawn position offset for centering the piece
  int get spawnOffset {
    switch (this) {
      case TetrominoType.I:
        return 3;
      case TetrominoType.O:
        return 4;
      default:
        return 3;
    }
  }
}

/// Represents a tetromino piece in the game
class Tetromino {
  TetrominoType type;
  int x; // Column position
  int y; // Row position (0 = bottom)
  int rotation; // 0-3

  Tetromino({
    required this.type,
    required this.x,
    required this.y,
    this.rotation = 0,
  });

  /// Get the current shape based on rotation
  List<Point<int>> get currentShape => type.shapes[rotation];

  /// Get absolute positions of all blocks
  List<Point<int>> get absolutePositions {
    return currentShape.map((p) => Point(x + p.x, y - p.y)).toList();
  }

  /// Create a copy of this tetromino
  Tetromino copy() {
    return Tetromino(
      type: type,
      x: x,
      y: y,
      rotation: rotation,
    );
  }

  /// Rotate clockwise
  void rotateClockwise() {
    rotation = (rotation + 1) % 4;
  }

  /// Rotate counter-clockwise
  void rotateCounterClockwise() {
    rotation = (rotation + 3) % 4;
  }
}

/// SRS (Super Rotation System) wall kick data
class WallKickData {
  static const List<List<Point<int>>> jlstzKicks = [
    // 0->1
    [Point(0, 0), Point(-1, 0), Point(-1, 1), Point(0, -2), Point(-1, -2)],
    // 1->2
    [Point(0, 0), Point(1, 0), Point(1, -1), Point(0, 2), Point(1, 2)],
    // 2->3
    [Point(0, 0), Point(1, 0), Point(1, 1), Point(0, -2), Point(1, -2)],
    // 3->0
    [Point(0, 0), Point(-1, 0), Point(-1, -1), Point(0, 2), Point(-1, 2)],
  ];

  static const List<List<Point<int>>> iKicks = [
    // 0->1
    [Point(0, 0), Point(-2, 0), Point(1, 0), Point(-2, -1), Point(1, 2)],
    // 1->2
    [Point(0, 0), Point(-1, 0), Point(2, 0), Point(-1, 2), Point(2, -1)],
    // 2->3
    [Point(0, 0), Point(2, 0), Point(-1, 0), Point(2, 1), Point(-1, -2)],
    // 3->0
    [Point(0, 0), Point(1, 0), Point(-2, 0), Point(1, -2), Point(-2, 1)],
  ];

  /// Get wall kick offsets for a rotation
  static List<Point<int>> getKicks(TetrominoType type, int fromRotation, bool clockwise) {
    if (type == TetrominoType.O) {
      return [const Point(0, 0)];
    }

    final kicks = type == TetrominoType.I ? iKicks : jlstzKicks;
    final index = clockwise ? fromRotation : (fromRotation + 3) % 4;

    if (clockwise) {
      return kicks[index];
    } else {
      // Reverse the kicks for counter-clockwise
      return kicks[index].map((p) => Point(-p.x, -p.y)).toList();
    }
  }
}
