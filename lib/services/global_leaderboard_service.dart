import 'package:flutter/foundation.dart';
import '../models/global_leaderboard_entry.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Global Leaderboard Service - manages cloud-based leaderboard data
class GlobalLeaderboardService extends ChangeNotifier {
  static final GlobalLeaderboardService _instance = GlobalLeaderboardService._internal();
  static GlobalLeaderboardService get instance => _instance;
  GlobalLeaderboardService._internal();

  List<GlobalLeaderboardEntry> _entries = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetch;

  // Cache duration
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Getters
  List<GlobalLeaderboardEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasData => _entries.isNotEmpty;
  bool get hasError => _errorMessage != null;

  /// Fetch global leaderboard from server
  Future<void> fetchLeaderboard({bool forceRefresh = false}) async {
    // Check if bound
    if (!AuthService.instance.isBound) {
      _errorMessage = 'Please bind your wallet first';
      notifyListeners();
      return;
    }

    // Check cache
    if (!forceRefresh && _lastFetch != null && _entries.isNotEmpty) {
      final elapsed = DateTime.now().difference(_lastFetch!);
      if (elapsed < _cacheDuration) {
        return;
      }
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await AuthService.instance.getValidAccessToken();
      if (token == null) {
        _errorMessage = 'Unable to authenticate';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final result = await ApiService.instance.getGlobalLeaderboard(
        accessToken: token,
      );

      if (result.isSuccess && result.data != null) {
        _entries = result.data!;
        _lastFetch = DateTime.now();
        _errorMessage = null;
      } else {
        _errorMessage = result.errorMessage ?? 'Failed to load leaderboard';

        // Handle token expiry
        if (result.errorCode == 'expired_token') {
          final refreshed = await AuthService.instance.refreshAccessToken();
          if (refreshed) {
            // Retry once
            _isLoading = false;
            return fetchLeaderboard(forceRefresh: true);
          }
        }
      }
    } catch (e) {
      debugPrint('FetchLeaderboard error: $e');
      _errorMessage = 'Network error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Upload a score to the global leaderboard (legacy API)
  Future<bool> uploadScore({
    required int score,
    required int level,
    required int lines,
  }) async {
    if (!AuthService.instance.isBound) {
      debugPrint('Cannot upload score: not bound');
      return false;
    }

    try {
      final token = await AuthService.instance.getValidAccessToken();
      if (token == null) {
        debugPrint('Cannot upload score: no valid token');
        return false;
      }

      final result = await ApiService.instance.uploadScore(
        accessToken: token,
        score: score,
        level: level,
        lines: lines,
      );

      if (result.isSuccess) {
        // Refresh leaderboard after successful upload
        await fetchLeaderboard(forceRefresh: true);
        return true;
      } else {
        debugPrint('Upload score failed: ${result.errorMessage}');

        // Handle token expiry
        if (result.errorCode == 'expired_token') {
          final refreshed = await AuthService.instance.refreshAccessToken();
          if (refreshed) {
            // Retry once
            return uploadScore(score: score, level: level, lines: lines);
          }
        }
      }
    } catch (e) {
      debugPrint('UploadScore error: $e');
    }

    return false;
  }

  /// Submit score to user's account
  /// Returns ScoreSubmitResponse on success, null on failure
  Future<ScoreSubmitResponse?> submitScore({
    required int score,
    required int lines,
    String source = 'game',
    String lan = 'en',
  }) async {
    if (!AuthService.instance.isBound) {
      debugPrint('Cannot submit score: not bound');
      return null;
    }

    try {
      final token = await AuthService.instance.getValidAccessToken();
      if (token == null) {
        debugPrint('Cannot submit score: no valid token');
        return null;
      }

      final result = await ApiService.instance.submitScore(
        accessToken: token,
        score: score,
        lines: lines,
        source: source,
        lan: lan,
      );

      if (result.isSuccess && result.data != null) {
        debugPrint('Score submitted: lines=${result.data!.lines}, bestLines=${result.data!.bestLines}, isNewRecord=${result.data!.isNewRecord}, rank=${result.data!.rank}');
        // Refresh leaderboard after successful submit
        await fetchLeaderboard(forceRefresh: true);
        return result.data;
      } else {
        debugPrint('Submit score failed: ${result.errorMessage}');

        // Handle token expiry
        if (result.errorCode == 'expired_token') {
          final refreshed = await AuthService.instance.refreshAccessToken();
          if (refreshed) {
            // Retry once
            return submitScore(score: score, lines: lines, source: source, lan: lan);
          }
        }
      }
    } catch (e) {
      debugPrint('SubmitScore error: $e');
    }

    return null;
  }

  /// Get user's score statistics
  Future<ScoreStatsResponse?> getUserStats() async {
    if (!AuthService.instance.isBound) {
      return null;
    }

    try {
      final token = await AuthService.instance.getValidAccessToken();
      if (token == null) return null;

      final result = await ApiService.instance.getScoreStats(
        accessToken: token,
      );

      if (result.isSuccess && result.data != null) {
        return result.data;
      }
    } catch (e) {
      debugPrint('GetUserStats error: $e');
    }

    return null;
  }

  /// Get user's rank in global leaderboard
  int? getUserRank() {
    final walletAddress = AuthService.instance.walletAddress;
    if (walletAddress == null) return null;

    for (int i = 0; i < _entries.length; i++) {
      if (_entries[i].walletAddress == walletAddress) {
        return i + 1;
      }
    }
    return null;
  }

  /// Get user's best score
  GlobalLeaderboardEntry? getUserBestEntry() {
    final walletAddress = AuthService.instance.walletAddress;
    if (walletAddress == null) return null;

    for (final entry in _entries) {
      if (entry.walletAddress == walletAddress) {
        return entry;
      }
    }
    return null;
  }

  /// Clear cached data (call when unbinding)
  void clear() {
    _entries = [];
    _lastFetch = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
