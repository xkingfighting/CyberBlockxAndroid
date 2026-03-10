/// Deterministic random bag using xorshift64 PRNG.
///
/// Given the same seed, produces identical piece sequences across
/// Flutter and iOS platforms. This is the foundation of match fairness
/// in Challenge Mode.
///
/// Algorithm: xorshift64 → Fisher-Yates shuffle → 7-bag system
/// Must produce byte-identical output to SeededRandomBag.swift.
import '../../core/game_state.dart' show PieceBag;
import '../../core/tetromino.dart';

class SeededRandomBag implements PieceBag {
  int _state;
  final List<TetrominoType> _currentBag = [];
  final List<TetrominoType> _previewQueue = [];
  final int previewCount;

  /// Canonical piece order: must match iOS exactly.
  static const List<TetrominoType> canonicalOrder = [
    TetrominoType.I,
    TetrominoType.O,
    TetrominoType.T,
    TetrominoType.S,
    TetrominoType.Z,
    TetrominoType.J,
    TetrominoType.L,
  ];

  SeededRandomBag(int seed, {this.previewCount = 5})
      : _state = seed == 0 ? 1 : seed {
    // Seed of 0 would break xorshift, use 1 instead
    reset();
  }

  /// Reset the bag and refill the preview queue.
  void reset() {
    _currentBag.clear();
    _previewQueue.clear();
    // Re-initialize state is NOT done here - reset() is called once during init.
    // For a fresh start with same seed, create a new instance.
    while (_previewQueue.length < previewCount) {
      _previewQueue.add(_drawFromBag());
    }
  }

  /// Get the next piece (consumes from preview queue, refills from bag).
  TetrominoType next() {
    final piece = _previewQueue.removeAt(0);
    _previewQueue.add(_drawFromBag());
    return piece;
  }

  /// Peek at the preview queue without consuming.
  List<TetrominoType> get preview => List.unmodifiable(_previewQueue);

  /// Peek at the next piece without consuming.
  TetrominoType peek() {
    if (_previewQueue.isEmpty) return TetrominoType.I;
    return _previewQueue.first;
  }

  // -- Private --

  TetrominoType _drawFromBag() {
    if (_currentBag.isEmpty) {
      _refillBag();
    }
    return _currentBag.removeAt(0);
  }

  void _refillBag() {
    _currentBag.addAll(List.from(canonicalOrder));
    _fisherYatesShuffle(_currentBag);
  }

  /// Fisher-Yates shuffle using the seeded PRNG.
  void _fisherYatesShuffle(List<TetrominoType> list) {
    for (int i = list.length - 1; i > 0; i--) {
      final j = _nextRandom() % (i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
  }

  /// xorshift64 PRNG - deterministic, platform-independent.
  ///
  /// Uses unsigned 64-bit arithmetic. Dart's int is 64-bit on VM,
  /// but we mask to ensure consistent behavior.
  int _nextRandom() {
    // xorshift64 algorithm
    _state ^= (_state << 13) & 0xFFFFFFFFFFFFFFFF;
    _state ^= _state >>> 7; // Logical right shift (Dart 2.14+)
    _state ^= (_state << 17) & 0xFFFFFFFFFFFFFFFF;
    _state &= 0xFFFFFFFFFFFFFFFF; // Ensure 64-bit unsigned
    return _state.abs(); // Return positive value for modulo
  }

  /// Generate a sequence of N pieces for testing/verification.
  /// Creates a fresh instance with the given seed.
  static List<TetrominoType> generateSequence(int seed, int count) {
    final bag = SeededRandomBag(seed, previewCount: 5);
    final result = <TetrominoType>[];
    for (int i = 0; i < count; i++) {
      result.add(bag.next());
    }
    return result;
  }

  /// Convert a piece sequence to a string of indices for cross-platform comparison.
  /// I=0, O=1, T=2, S=3, Z=4, J=5, L=6
  static String sequenceToString(List<TetrominoType> sequence) {
    return sequence.map((t) => canonicalOrder.indexOf(t).toString()).join(',');
  }
}
