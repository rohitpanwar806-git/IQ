import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/leaderboard_entry.dart';

/// Thin, secure client for the IQ Games backend.
///
/// It only talks to the public API Gateway endpoint over HTTPS. No AWS
/// credentials are ever embedded in the app.
class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 20);

  /// Fetches the top scores for a game, ordered highest-first.
  Future<List<LeaderboardEntry>> getLeaderboard(
    String gameId, {
    int limit = 100,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/leaderboard/$gameId'
      '?gameId=$gameId&limit=$limit',
    );

    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to load leaderboard (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = (decoded['leaderboard'] as List<dynamic>? ?? [])
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return entries;
  }

  /// Submits a score for the current user.
  ///
  /// Requires the backend POST route to be deployed (see infrastructure).
  Future<void> submitScore({
    required String userId,
    required String gameId,
    required int score,
    required String displayName,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/leaderboard/$gameId');

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': userId,
            'gameId': gameId,
            'score': score,
            'displayName': displayName,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        'Failed to submit score (${response.statusCode})',
      );
    }
  }

  void dispose() => _client.close();
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
