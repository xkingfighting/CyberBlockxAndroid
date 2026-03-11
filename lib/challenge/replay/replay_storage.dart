import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../services/auth_service.dart';
import 'replay_data.dart';

/// Local file-based storage for match replays.
///
/// Stores replay JSON files in Documents/replays/replay_{matchId}.json.
/// Enforces a maximum of [maxReplays] files, deleting oldest when exceeded.
class ReplayStorage {
  static const int maxReplays = 50;
  static const String _subDir = 'replays';
  static const String _baseUrl = 'https://api.cyberblockx.com';
  static const Duration _timeout = Duration(seconds: 30);

  static Future<Directory> _replayDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_subDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _fileName(String matchId) => 'replay_$matchId.json';

  /// Save a replay to local storage.
  static Future<void> save(ReplayData replay) async {
    try {
      final dir = await _replayDir();
      final file = File('${dir.path}/${_fileName(replay.matchId)}');
      await file.writeAsString(jsonEncode(replay.toJson()));
      await _enforceCapacity(dir);
      print('[ReplayStorage] saved replay for ${replay.matchId} '
          '(${replay.playerActions.length}p + ${replay.opponentActions.length}o actions)');
    } catch (e) {
      print('[ReplayStorage] save error: $e');
    }
  }

  /// Load a replay by matchId. Returns null if not found.
  static Future<ReplayData?> load(String matchId) async {
    try {
      final dir = await _replayDir();
      final file = File('${dir.path}/${_fileName(matchId)}');
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return ReplayData.fromJson(json);
    } catch (e) {
      print('[ReplayStorage] load error: $e');
      return null;
    }
  }

  /// Check if a replay exists for a given matchId.
  static Future<bool> exists(String matchId) async {
    try {
      final dir = await _replayDir();
      final file = File('${dir.path}/${_fileName(matchId)}');
      return file.exists();
    } catch (_) {
      return false;
    }
  }

  /// Delete a replay.
  static Future<void> delete(String matchId) async {
    try {
      final dir = await _replayDir();
      final file = File('${dir.path}/${_fileName(matchId)}');
      if (await file.exists()) await file.delete();
    } catch (e) {
      print('[ReplayStorage] delete error: $e');
    }
  }

  /// Enforce max capacity by deleting oldest files.
  static Future<void> _enforceCapacity(Directory dir) async {
    try {
      final files = <File>[];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          files.add(entity);
        }
      }
      if (files.length <= maxReplays) return;

      // Sort by modification time, oldest first
      files.sort((a, b) =>
          a.statSync().modified.compareTo(b.statSync().modified));

      final toDelete = files.length - maxReplays;
      for (int i = 0; i < toDelete; i++) {
        await files[i].delete();
        debugPrint('[ReplayStorage] capacity cleanup: deleted ${files[i].path}');
      }
    } catch (e) {
      debugPrint('[ReplayStorage] capacity enforcement error: $e');
    }
  }

  // ─── Cloud Storage ───────────────────────────────────

  /// Upload replay to server. Fire-and-forget, failures are silent.
  static Future<void> uploadToServer(ReplayData replay) async {
    try {
      final token = await AuthService.instance.getValidAccessToken();
      if (token == null) return;

      final uri = Uri.parse(
        '$_baseUrl/?_controller=Api&_function=Match&__function=UploadReplay',
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'matchId': replay.matchId,
          'replayData': jsonEncode(replay.toJson()),
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['ret'] == 1) {
          debugPrint('[ReplayStorage] uploaded replay for ${replay.matchId}');
        } else {
          debugPrint('[ReplayStorage] upload response: ${json['msg']}');
        }
      }
    } catch (e) {
      debugPrint('[ReplayStorage] upload error: $e');
    }
  }

  /// Upload solo game replay to server. Fire-and-forget, failures are silent.
  static Future<void> uploadSoloReplay(ReplayData replay, {
    int score = 0,
    int lines = 0,
    int level = 0,
  }) async {
    try {
      final token = await AuthService.instance.getValidAccessToken();
      if (token == null) return;

      final uri = Uri.parse(
        '$_baseUrl/?_controller=Api&_function=Score&__function=UploadReplay',
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'game_token': replay.matchId,
          'replayData': jsonEncode(replay.toJson()),
          'score': score.toString(),
          'lines': lines.toString(),
          'level': level.toString(),
          'duration': replay.duration.toString(),
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['ret'] == 1) {
          debugPrint('[ReplayStorage] uploaded solo replay for ${replay.matchId}');
        } else {
          debugPrint('[ReplayStorage] solo upload response: ${json['msg']}');
        }
      }
    } catch (e) {
      debugPrint('[ReplayStorage] solo upload error: $e');
    }
  }

  /// Download replay from server and cache locally.
  /// Returns null if not available on server.
  static Future<ReplayData?> downloadFromServer(String matchId) async {
    try {
      final token = await AuthService.instance.getValidAccessToken();
      if (token == null) return null;

      final uri = Uri.parse(
        '$_baseUrl/?_controller=Api&_function=Match&__function=GetReplay'
        '&matchId=$matchId',
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['ret'] == 1 && json['data'] != null) {
          final data = json['data'] as Map<String, dynamic>;
          final replayJson = data['replay'] as Map<String, dynamic>?;
          if (replayJson != null) {
            final replay = ReplayData.fromJson(replayJson);
            // Cache locally
            await save(replay);
            debugPrint('[ReplayStorage] downloaded & cached replay for $matchId');
            return replay;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ReplayStorage] download error: $e');
      return null;
    }
  }
}
