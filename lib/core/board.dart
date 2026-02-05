import 'dart:ui';
import 'tetromino.dart';

/// Represents a cell on the game board
class Cell {
  final bool filled;
  final Color? color;

  const Cell({this.filled = false, this.color});

  static const empty = Cell();

  Cell copyWith({bool? filled, Color? color}) {
    return Cell(
      filled: filled ?? this.filled,
      color: color ?? this.color,
    );
  }
}

/// The game board
class Board {
  final int width;
  final int height;
  late List<List<Cell>> _grid;

  Board({this.width = 10, this.height = 20}) {
    _grid = List.generate(
      height,
      (_) => List.generate(width, (_) => Cell.empty),
    );
  }

  /// Get cell at position
  Cell getCell(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return const Cell(filled: true); // Out of bounds = filled
    }
    return _grid[y][x];
  }

  /// Set cell at position
  void setCell(int x, int y, Cell cell) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      _grid[y][x] = cell;
    }
  }

  /// Check if a position is valid (not filled and within bounds)
  bool isValidPosition(int x, int y) {
    if (x < 0 || x >= width || y < 0) {
      return false;
    }
    if (y >= height) {
      return true; // Above the board is OK
    }
    return !_grid[y][x].filled;
  }

  /// Check if a tetromino can be placed at its current position
  bool canPlace(Tetromino piece) {
    for (final pos in piece.absolutePositions) {
      if (!isValidPosition(pos.x, pos.y)) {
        return false;
      }
    }
    return true;
  }

  /// Lock a tetromino onto the board
  void lockPiece(Tetromino piece) {
    for (final pos in piece.absolutePositions) {
      if (pos.y < height && pos.y >= 0) {
        setCell(pos.x, pos.y, Cell(filled: true, color: piece.type.color));
      }
    }
  }

  /// Clear completed lines and return the number of lines cleared
  int clearLines() {
    // Collect all full lines first
    final fullLines = <int>[];
    for (int y = 0; y < height; y++) {
      if (_isLineFull(y)) {
        fullLines.add(y);
      }
    }

    if (fullLines.isEmpty) return 0;

    // Remove full lines by shifting rows down
    // Process from bottom to top to maintain correct indices
    int writeY = 0;
    int readY = 0;
    int fullLineIndex = 0;

    // Create new grid with cleared lines removed
    final newGrid = List.generate(
      height,
      (_) => List.generate(width, (_) => Cell.empty),
    );

    // Copy non-full lines to new grid
    for (int y = 0; y < height; y++) {
      if (fullLineIndex < fullLines.length && y == fullLines[fullLineIndex]) {
        // Skip this full line
        fullLineIndex++;
      } else {
        // Copy this line to new grid
        for (int x = 0; x < width; x++) {
          newGrid[writeY][x] = _grid[y][x];
        }
        writeY++;
      }
    }

    // Replace grid
    _grid = newGrid;

    return fullLines.length;
  }

  /// Get rows that are full (for animation)
  List<int> getFullLines() {
    final fullLines = <int>[];
    for (int y = 0; y < height; y++) {
      if (_isLineFull(y)) {
        fullLines.add(y);
      }
    }
    return fullLines;
  }

  /// Check if a line is full
  bool _isLineFull(int y) {
    for (int x = 0; x < width; x++) {
      if (!_grid[y][x].filled) {
        return false;
      }
    }
    return true;
  }

  /// Check if the board is empty (perfect clear)
  bool isEmpty() {
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (_grid[y][x].filled) {
          return false;
        }
      }
    }
    return true;
  }

  /// Get the highest filled row (for game over detection)
  int getHighestFilledRow() {
    for (int y = height - 1; y >= 0; y--) {
      for (int x = 0; x < width; x++) {
        if (_grid[y][x].filled) {
          return y;
        }
      }
    }
    return -1;
  }

  /// Clear the board
  void clear() {
    _grid = List.generate(
      height,
      (_) => List.generate(width, (_) => Cell.empty),
    );
  }

  /// Get the grid for rendering
  List<List<Cell>> get grid => _grid;
}
