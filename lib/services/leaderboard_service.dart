import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaderboardEntry {
  final String name;
  final int score;
  final int level;
  final int lines;
  final DateTime date;
  final bool isSynced; // Whether this score has been synced to cloud

  LeaderboardEntry({
    required this.name,
    required this.score,
    required this.level,
    required this.lines,
    required this.date,
    this.isSynced = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'score': score,
    'level': level,
    'lines': lines,
    'date': date.toIso8601String(),
    'isSynced': isSynced,
  };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      name: json['name'] as String,
      score: json['score'] as int,
      level: json['level'] as int,
      lines: json['lines'] as int,
      date: DateTime.parse(json['date'] as String),
      isSynced: json['isSynced'] as bool? ?? false,
    );
  }
}

class LeaderboardService extends ChangeNotifier {
  static final LeaderboardService _instance = LeaderboardService._internal();
  static LeaderboardService get instance => _instance;
  LeaderboardService._internal();

  static const _leaderboardKey = 'CyberBlockx_Leaderboard';
  static const _lastPlayerNameKey = 'CyberBlockx_LastPlayerName';
  static const int maxEntries = 20;

  List<LeaderboardEntry> _entries = [];
  List<LeaderboardEntry> get entries => List.unmodifiable(_entries);

  String _lastPlayerName = '';
  String get lastPlayerName => _lastPlayerName;

  int get highScore => _entries.isNotEmpty ? _entries.first.score : 0;

  Future<void> init() async {
    await _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_leaderboardKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _entries = jsonList
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _entries.sort((a, b) => b.score.compareTo(a.score));
      }
      // Load last player name
      _lastPlayerName = prefs.getString(_lastPlayerNameKey) ?? '';
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
      _entries = [];
    }
    notifyListeners();
  }

  Future<void> _saveEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(_entries.map((e) => e.toJson()).toList());
      await prefs.setString(_leaderboardKey, jsonString);
    } catch (e) {
      debugPrint('Error saving leaderboard: $e');
    }
  }

  Future<int?> addScore({
    required int score,
    required int level,
    required int lines,
    String? name,
    bool isSynced = false,
  }) async {
    // Use last player name if no name provided, default to 'Player'
    final playerName = (name?.trim().isNotEmpty == true)
        ? name!.trim()
        : (_lastPlayerName.isNotEmpty ? _lastPlayerName : 'Player');

    final entry = LeaderboardEntry(
      name: playerName,
      score: score,
      level: level,
      lines: lines,
      date: DateTime.now(),
      isSynced: isSynced,
    );

    _entries.add(entry);
    _entries.sort((a, b) => b.score.compareTo(a.score));

    // Keep only top entries
    if (_entries.length > maxEntries) {
      _entries = _entries.sublist(0, maxEntries);
    }

    // Save last player name
    _lastPlayerName = playerName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPlayerNameKey, _lastPlayerName);

    await _saveEntries();
    notifyListeners();

    // Return rank if in top entries, null otherwise
    final rank = _entries.indexWhere((e) =>
      e.score == score && e.date == entry.date);
    return rank >= 0 && rank < maxEntries ? rank + 1 : null;
  }

  bool isHighScore(int score) {
    if (_entries.length < maxEntries) return true;
    return score > _entries.last.score;
  }

  Future<void> clearLeaderboard() async {
    _entries = [];
    await _saveEntries();
    notifyListeners();
  }
}
