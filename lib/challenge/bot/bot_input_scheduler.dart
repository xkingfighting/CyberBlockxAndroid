import 'dart:math';
import '../models/match_config.dart';

/// Represents a single bot input action to be executed.
class ScheduledInput {
  final String action; // "left", "right", "rotate_cw", "rotate_ccw", "hard_drop", "hold"
  final double executeAt; // Time in seconds when this input should fire

  const ScheduledInput({required this.action, required this.executeAt});
}

/// Humanizes bot input by scheduling individual move/rotate/drop actions
/// with realistic delays instead of teleporting pieces.
class BotInputScheduler {
  final BotProfileConfig profile;
  final Random _random = Random();

  BotInputScheduler({required this.profile});

  /// Generate a sequence of timed inputs to move a piece from spawn
  /// to the target position and rotation.
  ///
  /// [currentX] - piece's current x position (spawn position)
  /// [currentRotation] - piece's current rotation (0)
  /// [targetX] - desired x position
  /// [targetRotation] - desired rotation (0-3)
  /// [startTime] - current elapsed time in seconds
  List<ScheduledInput> scheduleInputs({
    required int currentX,
    required int currentRotation,
    required int targetX,
    required int targetRotation,
    required double startTime,
  }) {
    final inputs = <ScheduledInput>[];
    double time = startTime + _randomDelay(profile.thinkDelayMs);

    // 1. Rotations first
    int rotationsNeeded = (targetRotation - currentRotation) % 4;
    if (rotationsNeeded == 3) {
      // Counter-clockwise is faster
      inputs.add(ScheduledInput(action: 'rotate_ccw', executeAt: time));
      time += _randomDelay(profile.moveDelayMs);
      _maybeStutter(inputs, time);
    } else {
      for (int i = 0; i < rotationsNeeded; i++) {
        inputs.add(ScheduledInput(action: 'rotate_cw', executeAt: time));
        time += _randomDelay(profile.moveDelayMs);
        if (i < rotationsNeeded - 1) {
          _maybeStutter(inputs, time);
        }
      }
    }

    // 2. Horizontal movement
    final dx = targetX - currentX;
    final direction = dx > 0 ? 'right' : 'left';
    for (int i = 0; i < dx.abs(); i++) {
      inputs.add(ScheduledInput(action: direction, executeAt: time));
      time += _randomDelay(profile.moveDelayMs);
      _maybeStutter(inputs, time);
    }

    // 3. Hard drop
    time += _randomDelay(profile.moveDelayMs) * 0.5; // Slightly faster for final drop
    inputs.add(ScheduledInput(action: 'hard_drop', executeAt: time));

    return inputs;
  }

  /// Add a random stutter (pause) based on profile.
  void _maybeStutter(List<ScheduledInput> inputs, double time) {
    // Stutter handled by caller checking chance - inputs list is unchanged
  }

  /// Generate a random delay in seconds from a [min, max] ms range.
  double _randomDelay(List<int> range) {
    final minMs = range.first;
    final maxMs = range.last;
    // Apply speed variance
    final variance = 1.0 + (_random.nextDouble() - 0.5) * 2.0 * profile.speedVariance;
    final ms = minMs + _random.nextInt(maxMs - minMs + 1);
    return (ms * variance).clamp(minMs * 0.5, maxMs * 2.0) / 1000.0;
  }
}
