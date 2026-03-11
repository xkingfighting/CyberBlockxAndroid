import 'replay_data.dart';

/// Records player and opponent actions during a live challenge match.
///
/// Usage:
/// 1. Call [start] when the match begins (countdown ends)
/// 2. Call [recordPlayerAction] / [recordOpponentAction] during play
/// 3. Call [stop] when the match finishes
/// 4. Call [finalize] to produce a [ReplayData] object
class ReplayRecorder {
  final List<ReplayAction> _playerActions = [];
  final List<ReplayAction> _opponentActions = [];
  int _startTimeMs = 0;
  bool _recording = false;

  bool get isRecording => _recording;
  int get playerActionCount => _playerActions.length;
  int get opponentActionCount => _opponentActions.length;

  /// Begin recording. Clears any previous data.
  void start() {
    _startTimeMs = DateTime.now().millisecondsSinceEpoch;
    _playerActions.clear();
    _opponentActions.clear();
    _recording = true;
  }

  /// Stop recording.
  void stop() {
    _recording = false;
  }

  /// Record a player action with the current relative timestamp.
  void recordPlayerAction(int actionCode) {
    if (!_recording) return;
    final ts = DateTime.now().millisecondsSinceEpoch - _startTimeMs;
    _playerActions.add(ReplayAction(ts, actionCode));
  }

  /// Record an opponent (bot) action with the current relative timestamp.
  void recordOpponentAction(int actionCode) {
    if (!_recording) return;
    final ts = DateTime.now().millisecondsSinceEpoch - _startTimeMs;
    _opponentActions.add(ReplayAction(ts, actionCode));
  }

  /// Produce a finalized [ReplayData] from the recorded session.
  ReplayData finalize({
    required String matchId,
    required int seed,
    required int duration,
    required String modeType,
    required String opponentName,
    required String outcome,
  }) {
    return ReplayData(
      matchId: matchId,
      seed: seed,
      duration: duration,
      modeType: modeType,
      opponentName: opponentName,
      outcome: outcome,
      playerActions: List.unmodifiable(_playerActions),
      opponentActions: List.unmodifiable(_opponentActions),
    );
  }
}
