import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';
import '../models/auth_state.dart';
import '../models/global_leaderboard_entry.dart';

/// API Service - handles all HTTP requests to the CyberBlockx backend
class ApiService {
  static final ApiService _instance = ApiService._internal();
  static ApiService get instance => _instance;
  ApiService._internal();

  // API Configuration
  static const String _baseUrl = 'https://api.cyberblockx.com';
  static const String _clientId = 'cyberblockx_game';
  static const Duration _timeout = Duration(seconds: 30);

  /// Get bind nonce for wallet signature
  /// POST /Api/Wallet/GetBindNonce
  Future<ApiResponse<NonceResponse>> getBindNonce(String walletAddress) async {
    debugPrint('API: Getting bind nonce for $walletAddress');
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/Api/Wallet/GetBindNonce'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'wallet_address': walletAddress,
        },
      ).timeout(_timeout);

      debugPrint('API: GetBindNonce response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('API: GetBindNonce body: $json');
        // API returns ret=1 for success
        if ((json['ret'] == 1 || json['success'] == true) && json['data'] != null) {
          return ApiResponse.success(
            NonceResponse.fromJson(json['data'], walletAddress: walletAddress),
          );
        }
        return ApiResponse.failure(
          json['msg'] ?? json['message'] ?? 'Failed to get nonce',
          errorCode: json['error'],
        );
      }

      debugPrint('API: GetBindNonce error response: ${response.body}');
      return ApiResponse.failure(
        'Server error',
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('GetBindNonce error: $e');
      return ApiResponse.failure('Network error: ${e.toString()}');
    }
  }

  /// Get token using wallet signature
  /// POST /oauth/token (grant_type=wallet_signature)
  Future<ApiResponse<TokenResponse>> getTokenByWalletSignature({
    required String walletAddress,
    required String message,
    required String signature,
    required String nonce,
    String scope = 'wallet:read wallet:write',
    String walletProvider = 'Phantom',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/oauth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'wallet_signature',
          'client_id': _clientId,
          'wallet_address': walletAddress,
          'message': message,
          'signature': signature,
          'nonce': nonce,
          'scope': scope,
          'wallet_provider': walletProvider,
        },
      ).timeout(_timeout);

      debugPrint('API: GetToken response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('API: GetToken body: $json');

        // Handle both standard OAuth format and custom API format (ret: 1, data: {...})
        if (json['ret'] == 1 && json['data'] != null) {
          return ApiResponse.success(TokenResponse.fromJson(json['data']));
        } else if (json['access_token'] != null) {
          return ApiResponse.success(TokenResponse.fromJson(json));
        }

        return ApiResponse.failure(
          json['msg'] ?? json['message'] ?? 'Token request failed',
          errorCode: json['error'],
        );
      }

      final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('API: GetToken error: $errorJson');
      return ApiResponse.failure(
        errorJson['msg'] ?? errorJson['message'] ?? errorJson['error_description'] ?? 'Authentication failed',
        errorCode: errorJson['error'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('GetToken error: $e');
      return ApiResponse.failure('Network error: ${e.toString()}');
    }
  }

  /// Refresh access token
  /// POST /oauth/token (grant_type=refresh_token)
  Future<ApiResponse<TokenResponse>> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/oauth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'client_id': _clientId,
          'refresh_token': refreshToken,
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(TokenResponse.fromJson(json));
      }

      final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse.failure(
        errorJson['message'] ?? 'Token refresh failed',
        errorCode: errorJson['error'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('RefreshToken error: $e');
      return ApiResponse.failure('Network error: ${e.toString()}');
    }
  }

  /// Get global leaderboard
  /// GET /Api/Leaderboard/Global
  Future<ApiResponse<List<GlobalLeaderboardEntry>>> getGlobalLeaderboard({
    required String accessToken,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/Api/Leaderboard/Global')
          .replace(queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      debugPrint('API: GetLeaderboard response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('API: GetLeaderboard body: $json');

        // Handle API format: {ret: 1, data: {leaderboard: [...]}}
        if ((json['ret'] == 1 || json['success'] == true) && json['data'] != null) {
          final data = json['data'] as Map<String, dynamic>;
          final leaderboardData = data['leaderboard'] ?? data;

          if (leaderboardData is List) {
            final list = leaderboardData
                .map((e) => GlobalLeaderboardEntry.fromJson(e as Map<String, dynamic>))
                .toList();
            return ApiResponse.success(list);
          }
        }
        return ApiResponse.failure(json['msg'] ?? json['message'] ?? 'Failed to get leaderboard');
      }

      if (response.statusCode == 401) {
        return ApiResponse.failure('Token expired', errorCode: 'expired_token', statusCode: 401);
      }

      return ApiResponse.failure('Server error', statusCode: response.statusCode);
    } catch (e) {
      debugPrint('GetGlobalLeaderboard error: $e');
      return ApiResponse.failure('Network error: ${e.toString()}');
    }
  }

  /// Upload score to global leaderboard
  /// POST /Api/Leaderboard/Upload
  Future<ApiResponse<void>> uploadScore({
    required String accessToken,
    required int score,
    required int level,
    required int lines,
    DateTime? playedAt,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/Api/Leaderboard/Upload'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'score': score,
          'level': level,
          'lines': lines,
          'played_at': (playedAt ?? DateTime.now()).toIso8601String(),
        }),
      ).timeout(_timeout);

      debugPrint('API: UploadScore response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('API: UploadScore body: $json');
        // Handle both formats: {ret: 1} and {success: true}
        if (json['ret'] == 1 || json['success'] == true) {
          return ApiResponse.success(null);
        }
        return ApiResponse.failure(json['msg'] ?? json['message'] ?? 'Upload failed');
      }

      if (response.statusCode == 401) {
        return ApiResponse.failure('Token expired', errorCode: 'expired_token', statusCode: 401);
      }

      final errorBody = response.body;
      debugPrint('API: UploadScore error: $errorBody');
      return ApiResponse.failure('Server error', statusCode: response.statusCode);
    } catch (e) {
      debugPrint('UploadScore error: $e');
      return ApiResponse.failure('Network error: ${e.toString()}');
    }
  }

  /// Submit score to user's account
  /// POST /Api/Score/Submit
  /// Scope: challenges:write
  Future<ApiResponse<ScoreSubmitResponse>> submitScore({
    required String accessToken,
    required int score,
    required int lines,
    String source = 'game',
    String lan = 'en',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/Api/Score/Submit'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'score': score.toString(),
          'lines': lines.toString(),
          'source': source,
          'lan': lan,
        },
      ).timeout(_timeout);

      debugPrint('API: SubmitScore response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('API: SubmitScore body: $json');
        if (json['ret'] == 1 && json['data'] != null) {
          return ApiResponse.success(
            ScoreSubmitResponse.fromJson(json['data']),
          );
        }
        return ApiResponse.failure(json['msg'] ?? json['message'] ?? 'Submit failed');
      }

      if (response.statusCode == 401) {
        return ApiResponse.failure('Token expired', errorCode: 'expired_token', statusCode: 401);
      }

      final errorBody = response.body;
      debugPrint('API: SubmitScore error: $errorBody');
      return ApiResponse.failure('Server error', statusCode: response.statusCode);
    } catch (e) {
      debugPrint('SubmitScore error: $e');
      return ApiResponse.failure('Network error: ${e.toString()}');
    }
  }

  /// Get user score statistics
  /// GET /Api/Score/Stats
  /// Scope: challenges:read
  Future<ApiResponse<ScoreStatsResponse>> getScoreStats({
    required String accessToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/Api/Score/Stats'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      debugPrint('API: GetScoreStats response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('API: GetScoreStats body: $json');
        if (json['ret'] == 1 && json['data'] != null) {
          return ApiResponse.success(
            ScoreStatsResponse.fromJson(json['data']),
          );
        }
        return ApiResponse.failure(json['msg'] ?? json['message'] ?? 'Failed to get stats');
      }

      if (response.statusCode == 401) {
        return ApiResponse.failure('Token expired', errorCode: 'expired_token', statusCode: 401);
      }

      return ApiResponse.failure('Server error', statusCode: response.statusCode);
    } catch (e) {
      debugPrint('GetScoreStats error: $e');
      return ApiResponse.failure('Network error: ${e.toString()}');
    }
  }
}

/// Response from Score Submit API
class ScoreSubmitResponse {
  final int score;
  final int lines;
  final int bestLines;
  final bool isNewRecord;
  final int rank;

  ScoreSubmitResponse({
    required this.score,
    required this.lines,
    required this.bestLines,
    required this.isNewRecord,
    required this.rank,
  });

  factory ScoreSubmitResponse.fromJson(Map<String, dynamic> json) {
    return ScoreSubmitResponse(
      score: _parseInt(json['score']),
      lines: _parseInt(json['lines']),
      bestLines: _parseInt(json['bestLines']),
      isNewRecord: json['isNewRecord'] == true,
      rank: _parseInt(json['rank']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Response from Score Stats API
class ScoreStatsResponse {
  final String userId;
  final int totalPoints;
  final int level;
  final int totalGames;
  final int rank;

  ScoreStatsResponse({
    required this.userId,
    required this.totalPoints,
    required this.level,
    required this.totalGames,
    required this.rank,
  });

  factory ScoreStatsResponse.fromJson(Map<String, dynamic> json) {
    return ScoreStatsResponse(
      userId: json['userId']?.toString() ?? '',
      totalPoints: _parseInt(json['totalPoints']),
      level: _parseInt(json['level']),
      totalGames: _parseInt(json['totalGames']),
      rank: _parseInt(json['rank']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
