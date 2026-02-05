import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';
import '../models/auth_state.dart';
import '../models/global_leaderboard_entry.dart';
import 'localization_service.dart';

/// API Service - handles all HTTP requests to the CyberBlockx backend
class ApiService {
  static final ApiService _instance = ApiService._internal();
  static ApiService get instance => _instance;
  ApiService._internal();

  // API Configuration
  static const String _baseUrl = 'https://api.cyberblockx.com';
  static const String _clientId = 'cyberblockx_game';
  static const Duration _timeout = Duration(seconds: 30);

  /// Get current language code for API requests
  String get _lan => LocalizationService.instance.apiLanguageCode;

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
          'lan': _lan,
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
    String scope = 'wallet:read wallet:write badges:read badges:write',
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
        'lan': _lan,
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
          'lan': _lan,
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
    required int level,
    String source = 'game',
  }) async {
    try {
      final requestBody = {
        'score': score.toString(),
        'lines': lines.toString(),
        'level': level.toString(),
        'source': source,
        'lan': _lan,
      };
      debugPrint('API: SubmitScore request: $requestBody');

      final response = await http.post(
        Uri.parse('$_baseUrl/Api/Score/Submit'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: requestBody,
      ).timeout(_timeout);

      debugPrint('API: SubmitScore response: ${response.statusCode}, body: ${response.body}');
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
      final uri = Uri.parse('$_baseUrl/Api/Score/Stats')
          .replace(queryParameters: {'lan': _lan});
      final response = await http.get(
        uri,
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

  /// Get all badges
  /// GET /Api/Badges/All
  /// Scope: badges:read
  Future<ApiResponse<BadgesResponse>> getAllBadges({
    required String accessToken,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/Api/Badges/All')
          .replace(queryParameters: {'lan': _lan});
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      debugPrint('API: GetAllBadges response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('API: GetAllBadges body: $json');
        if (json['ret'] == 1 && json['data'] != null) {
          // API returns data as a list directly, not wrapped in {badges: [...]}
          final data = json['data'];
          return ApiResponse.success(
            BadgesResponse.fromJson(data is List ? {'badges': data} : data),
          );
        }
        return ApiResponse.failure(json['msg'] ?? json['message'] ?? 'Failed to get badges');
      }

      if (response.statusCode == 401) {
        return ApiResponse.failure('Token expired', errorCode: 'expired_token', statusCode: 401);
      }

      return ApiResponse.failure('Server error', statusCode: response.statusCode);
    } catch (e) {
      debugPrint('GetAllBadges error: $e');
      return ApiResponse.failure('Network error: ${e.toString()}');
    }
  }

  /// Get user's earned badges
  /// GET /Api/Badges/User
  /// Scope: badges:read
  Future<ApiResponse<BadgesResponse>> getUserBadges({
    required String accessToken,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/Api/Badges/User')
          .replace(queryParameters: {'lan': _lan});
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      debugPrint('API: GetUserBadges response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('API: GetUserBadges body: $json');
        if (json['ret'] == 1 && json['data'] != null) {
          final data = json['data'];
          return ApiResponse.success(
            BadgesResponse.fromJson(data is List ? {'badges': data} : data),
          );
        }
        return ApiResponse.failure(json['msg'] ?? json['message'] ?? 'Failed to get user badges');
      }

      if (response.statusCode == 401) {
        return ApiResponse.failure('Token expired', errorCode: 'expired_token', statusCode: 401);
      }

      return ApiResponse.failure('Server error', statusCode: response.statusCode);
    } catch (e) {
      debugPrint('GetUserBadges error: $e');
      return ApiResponse.failure('Network error: ${e.toString()}');
    }
  }

  /// Get user's claimable badges
  /// GET /Api/Badges/Claimable
  /// Scope: badges:read
  Future<ApiResponse<BadgesResponse>> getClaimableBadges({
    required String accessToken,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/Api/Badges/Claimable')
          .replace(queryParameters: {'lan': _lan});
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(_timeout);

      debugPrint('API: GetClaimableBadges response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('API: GetClaimableBadges body: $json');
        if (json['ret'] == 1 && json['data'] != null) {
          final data = json['data'];
          return ApiResponse.success(
            BadgesResponse.fromJson(data is List ? {'badges': data} : data),
          );
        }
        return ApiResponse.failure(json['msg'] ?? json['message'] ?? 'Failed to get claimable badges');
      }

      if (response.statusCode == 401) {
        return ApiResponse.failure('Token expired', errorCode: 'expired_token', statusCode: 401);
      }

      return ApiResponse.failure('Server error', statusCode: response.statusCode);
    } catch (e) {
      debugPrint('GetClaimableBadges error: $e');
      return ApiResponse.failure('Network error: ${e.toString()}');
    }
  }

  /// Claim a badge
  /// POST /Api/Badges/Claim
  /// Scope: badges:write
  Future<ApiResponse<BadgeClaimResponse>> claimBadge({
    required String accessToken,
    required String badgeId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/Api/Badges/Claim'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'badge_id': badgeId,
          'lan': _lan,
        },
      ).timeout(_timeout);

      debugPrint('API: ClaimBadge response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('API: ClaimBadge body: $json');
        if (json['ret'] == 1) {
          return ApiResponse.success(
            BadgeClaimResponse.fromJson(json['data'] ?? {}),
          );
        }
        return ApiResponse.failure(json['msg'] ?? json['message'] ?? 'Failed to claim badge');
      }

      if (response.statusCode == 401) {
        return ApiResponse.failure('Token expired', errorCode: 'expired_token', statusCode: 401);
      }

      return ApiResponse.failure('Server error', statusCode: response.statusCode);
    } catch (e) {
      debugPrint('ClaimBadge error: $e');
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

/// Response from Badges All API
class BadgesResponse {
  final List<BadgeData> badges;
  final int unlockedCount;
  final int totalCount;

  BadgesResponse({
    required this.badges,
    required this.unlockedCount,
    required this.totalCount,
  });

  factory BadgesResponse.fromJson(Map<String, dynamic> json) {
    final badgesList = json['badges'] as List<dynamic>? ?? [];
    final badges = badgesList
        .map((e) => BadgeData.fromJson(e as Map<String, dynamic>))
        .toList();

    return BadgesResponse(
      badges: badges,
      unlockedCount: badges.where((b) => b.unlocked).length,
      totalCount: badges.length,
    );
  }
}

/// Single badge data
class BadgeData {
  final String id;
  final String name;
  final String description;
  final String? icon;
  final String? imageUrl;
  final bool unlocked;
  final bool claimable;
  final DateTime? unlockedAt;
  final int? progress;
  final int? target;

  BadgeData({
    required this.id,
    required this.name,
    required this.description,
    this.icon,
    this.imageUrl,
    required this.unlocked,
    required this.claimable,
    this.unlockedAt,
    this.progress,
    this.target,
  });

  factory BadgeData.fromJson(Map<String, dynamic> json) {
    return BadgeData(
      id: (json['badgeId'] ?? json['id'])?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String?,
      imageUrl: json['icon'] as String? ?? json['imageUrl'] as String? ?? json['image_url'] as String?,
      unlocked: json['unlocked'] == true || json['is_unlocked'] == true,
      claimable: json['claimable'] == true || json['is_claimable'] == true,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'].toString())
          : null,
      progress: json['progress'] as int?,
      target: json['target'] as int?,
    );
  }
}

/// Response from Badge Claim API
class BadgeClaimResponse {
  final bool success;
  final String? message;
  final BadgeData? badge;

  BadgeClaimResponse({
    required this.success,
    this.message,
    this.badge,
  });

  factory BadgeClaimResponse.fromJson(Map<String, dynamic> json) {
    return BadgeClaimResponse(
      success: json['success'] == true || json['claimed'] == true,
      message: json['message'] as String?,
      badge: json['badge'] != null
          ? BadgeData.fromJson(json['badge'] as Map<String, dynamic>)
          : null,
    );
  }
}
