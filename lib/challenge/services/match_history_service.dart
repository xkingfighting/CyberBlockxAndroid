import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../models/match_history_entry.dart';
import '../models/match_history_stats.dart';

/// Service for fetching and caching challenge match history.
class MatchHistoryService extends ChangeNotifier {
  static final MatchHistoryService instance = MatchHistoryService._();
  MatchHistoryService._();

  static const String _baseUrl = 'https://api.cyberblockx.com';
  static const Duration _timeout = Duration(seconds: 30);
  static const int _pageSize = 20;

  List<MatchHistoryEntry> _entries = [];
  MatchHistoryStats? _stats;
  bool _isLoading = false;
  String? _error;
  int _total = 0;

  List<MatchHistoryEntry> get entries => List.unmodifiable(_entries);
  MatchHistoryStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _entries.length < _total;
  bool get hasData => _entries.isNotEmpty;

  /// Fetch first page + stats. Used on screen open and pull-to-refresh.
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await AuthService.instance.getValidAccessToken();
      if (token == null) {
        _error = 'Not logged in';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Fetch history and stats in parallel
      final results = await Future.wait([
        _fetchHistory(token: token, limit: _pageSize, offset: 0),
        _fetchStats(token: token),
      ]);

      final historyResult = results[0] as _HistoryPage?;
      final statsResult = results[1] as MatchHistoryStats?;

      if (historyResult != null) {
        _entries = historyResult.matches;
        _total = historyResult.total;
        _error = null;
      } else {
        _error = 'Failed to load history';
      }

      if (statsResult != null) {
        _stats = statsResult;
      }
    } catch (e) {
      debugPrint('[MatchHistoryService] refresh error: $e');
      _error = 'Network error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load next page (infinite scroll).
  Future<void> loadMore() async {
    if (_isLoading || !hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final token = await AuthService.instance.getValidAccessToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final result = await _fetchHistory(
        token: token,
        limit: _pageSize,
        offset: _entries.length,
      );

      if (result != null) {
        _entries = [..._entries, ...result.matches];
        _total = result.total;
      }
    } catch (e) {
      debugPrint('[MatchHistoryService] loadMore error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear cached data.
  void clear() {
    _entries = [];
    _stats = null;
    _total = 0;
    _error = null;
    notifyListeners();
  }

  Future<_HistoryPage?> _fetchHistory({
    required String token,
    required int limit,
    required int offset,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/?_controller=Api&_function=Match&__function=History'
        '&limit=$limit&offset=$offset',
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['ret'] == 1 && json['data'] != null) {
          final data = json['data'] as Map<String, dynamic>;
          final matchesList = data['matches'] as List? ?? [];
          final matches = matchesList
              .map((e) => MatchHistoryEntry.fromJson(e as Map<String, dynamic>))
              .toList();
          final total = data['total'] as int? ?? matches.length;
          return _HistoryPage(matches: matches, total: total);
        }
      }

      debugPrint('[MatchHistoryService] fetchHistory failed: HTTP ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[MatchHistoryService] fetchHistory error: $e');
      return null;
    }
  }

  Future<MatchHistoryStats?> _fetchStats({required String token}) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/?_controller=Api&_function=Match&__function=Stats',
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['ret'] == 1 && json['data'] != null) {
          return MatchHistoryStats.fromJson(json['data'] as Map<String, dynamic>);
        }
      }

      debugPrint('[MatchHistoryService] fetchStats failed: HTTP ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[MatchHistoryService] fetchStats error: $e');
      return null;
    }
  }
}

class _HistoryPage {
  final List<MatchHistoryEntry> matches;
  final int total;
  const _HistoryPage({required this.matches, required this.total});
}
