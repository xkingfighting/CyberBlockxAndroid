import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../models/match_config.dart';

/// REST API client for challenge match operations.
class MatchService {
  static final MatchService instance = MatchService._();
  MatchService._();

  static const String _baseUrl = 'https://api.cyberblockx.com';

  static const _botNames = [
    'NovaBit', 'Pixel-7', 'ByteStorm', 'GlitchFox', 'NeonPulse',
    'DataDrift', 'VoxelKid', 'CyberMite', 'HexWave', 'ZeroPing',
  ];

  /// Search for a match. Tries the API first; on failure, generates a local bot match.
  Future<MatchConfig?> searchMatch({String modeType = 'score_race', int entryFee = 0}) async {
    // Try API first
    final apiResult = await _searchMatchAPI(modeType: modeType, entryFee: entryFee);
    if (apiResult != null) return apiResult;

    // Fallback: generate local bot match
    return _generateLocalBotMatch(modeType: modeType);
  }

  Future<MatchConfig?> _searchMatchAPI({required String modeType, required int entryFee}) async {
    try {
      final token = await AuthService.instance.getValidAccessToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('$_baseUrl/?_controller=Api&_function=Match&__function=Search'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'modeType': modeType,
          'entryFee': '$entryFee',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['ret'] == 1 && data['data'] != null) {
        return MatchConfig.fromJson(data['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Generate a fully local bot match (offline capable).
  MatchConfig _generateLocalBotMatch({required String modeType}) {
    final rng = Random();
    final seed = rng.nextInt(0xFFFFFFFF);
    final botName = _botNames[rng.nextInt(_botNames.length)];
    final difficulty = ['easy', 'easy', 'medium'][rng.nextInt(3)];

    return MatchConfig(
      matchId: 'local_${DateTime.now().millisecondsSinceEpoch}',
      modeType: modeType,
      seed: seed,
      duration: modeType == 'survival' ? 0 : 120,
      opponent: OpponentInfo(
        playerId: 'bot_local',
        displayName: botName,
        isBot: true,
        botProfile: BotProfileConfig.fromDifficulty(difficulty),
      ),
    );
  }

  /// Submit match result to server for validation and rewards.
  ///
  /// For local bot matches (matchId starting with "local_"), the server will
  /// auto-create a match record using the extra metadata fields ([modeType],
  /// [seed], [configDuration], [opponentName]).
  Future<Map<String, dynamic>?> submitResult({
    required String matchId,
    required int score,
    required int lines,
    required int level,
    required int piecesPlaced,
    required double duration,
    required String gameToken,
    required int opponentFinalScore,
    required int opponentFinalLines,
    required bool isOpponentBot,
    // Extra fields for local match record creation on server
    String? modeType,
    int? seed,
    int? configDuration,
    String? opponentName,
    // Match history enrichment fields
    int? opponentLevel,
    String? opponentDifficulty,
    String? opponentBotProfileId,
    String rulesetVersion = '1.0',
    // Extended stats
    int? playerMaxCombo,
    int? playerTetrisCount,
    int? playerPerfectClears,
    int? opponentPiecesPlaced,
    String clientPlatform = 'flutter_android',
    String matchSource = '',
  }) async {
    try {
      final token = await AuthService.instance.getValidAccessToken();
      if (token == null) return null;

      final body = <String, String>{
        'matchId': matchId,
        'score': '$score',
        'lines': '$lines',
        'level': '$level',
        'piecesPlaced': '$piecesPlaced',
        'duration': '$duration',
        'gameToken': gameToken,
        'opponentFinalScore': '$opponentFinalScore',
        'opponentFinalLines': '$opponentFinalLines',
        'isOpponentBot': isOpponentBot ? '1' : '0',
      };

      // Include local match metadata so server can create the match record
      if (modeType != null) body['modeType'] = modeType;
      if (seed != null) body['seed'] = '$seed';
      if (configDuration != null) body['configDuration'] = '$configDuration';
      if (opponentName != null) body['opponentName'] = opponentName;

      // Match history enrichment
      if (opponentLevel != null) body['opponentLevel'] = '$opponentLevel';
      if (opponentDifficulty != null) body['opponentDifficulty'] = opponentDifficulty;
      if (opponentBotProfileId != null) body['opponentBotProfileId'] = opponentBotProfileId;
      body['rulesetVersion'] = rulesetVersion;

      // Extended stats
      if (playerMaxCombo != null) body['playerMaxCombo'] = '$playerMaxCombo';
      if (playerTetrisCount != null) body['playerTetrisCount'] = '$playerTetrisCount';
      if (playerPerfectClears != null) body['playerPerfectClears'] = '$playerPerfectClears';
      if (opponentPiecesPlaced != null) body['opponentPiecesPlaced'] = '$opponentPiecesPlaced';
      body['clientPlatform'] = clientPlatform;
      if (matchSource.isNotEmpty) body['matchSource'] = matchSource;

      final response = await http.post(
        Uri.parse('$_baseUrl/?_controller=Api&_function=Match&__function=Submit'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['ret'] == 1) {
        return data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Stub for WebSocket sync service (Phase 2).
  /// Currently unused - bot matches are fully local.
  Future<void> connectWebSocket(String matchId) async {
    // Phase 2: Implement WebSocket connection for real-time multiplayer
  }
}
