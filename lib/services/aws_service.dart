import 'package:aws_dynamodb_api/dynamodb-2012-08-10.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:aws_cognito_idp_api/cognito-idp-2016-04-18.dart';
import 'package:aws_core/credentials.dart';
import 'package:uuid/uuid.dart';

/// AWS Service for IQ Games
/// Handles DynamoDB operations, Cognito authentication, S3 storage
class AWSService {
  static final AWSService _instance = AWSService._internal();

  late final DynamoDB _dynamodb;
  late final S3 _s3;
  late final CognitoIdentityProviderClient _cognito;
  
  late final String _usersTable;
  late final String _scoresTable;
  late final String _leaderboardsTable;
  late final String _assetsBucket;
  late final String _apiEndpoint;

  factory AWSService() {
    return _instance;
  }

  AWSService._internal();

  /// Initialize AWS services
  Future<void> initialize({
    required String region,
    required String accessKeyId,
    required String secretAccessKey,
    required String usersTable,
    required String scoresTable,
    required String leaderboardsTable,
    required String assetsBucket,
    required String apiEndpoint,
  }) async {
    final credentials = AwsClientCredentials(
      accessKey: accessKeyId,
      secretKey: secretAccessKey,
    );

    _dynamodb = DynamoDB(
      region: region,
      credentials: credentials,
    );

    _s3 = S3(
      region: region,
      credentials: credentials,
    );

    _cognito = CognitoIdentityProviderClient(
      region: region,
      credentials: credentials,
    );

    _usersTable = usersTable;
    _scoresTable = scoresTable;
    _leaderboardsTable = leaderboardsTable;
    _assetsBucket = assetsBucket;
    _apiEndpoint = apiEndpoint;
  }

  // ============================================
  // User Profile Methods
  // ============================================

  /// Create or update user profile
  Future<void> createUserProfile({
    required String userId,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      final item = {
        'userId': AttributeValue(s: userId),
        'displayName': AttributeValue(s: displayName),
        'photoUrl': AttributeValue(s: photoUrl ?? ''),
        'totalScore': AttributeValue(n: '0'),
        'gamesPlayed': AttributeValue(n: '0'),
        'createdAt': AttributeValue(n: DateTime.now().millisecondsSinceEpoch.toString()),
      };

      await _dynamodb.putItem(
        tableName: _usersTable,
        item: item,
      );
    } catch (e) {
      print('Error creating user profile: $e');
      rethrow;
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _dynamodb.getItem(
        tableName: _usersTable,
        key: {'userId': AttributeValue(s: userId)},
      );

      if (response.item == null) return null;

      return _convertDynamoDBItem(response.item!);
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile({
    required String userId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final updates = <String, AttributeValueUpdate>{};
      
      if (data != null) {
        data.forEach((key, value) {
          updates[key] = AttributeValueUpdate(
            value: _toAttributeValue(value),
            action: 'PUT',
          );
        });
      }

      await _dynamodb.updateItem(
        tableName: _usersTable,
        key: {'userId': AttributeValue(s: userId)},
        attributeUpdates: updates,
      );
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // ============================================
  // Game Score Methods
  // ============================================

  /// Submit a game score to DynamoDB
  Future<void> submitGameScore({
    required String userId,
    required String gameId,
    required int score,
    required int duration, // in seconds
    String difficulty = 'normal',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final scoreId = const Uuid().v4();

      // Save to scores table
      final scoreItem = {
        'userId': AttributeValue(s: userId),
        'timestamp': AttributeValue(n: timestamp.toString()),
        'scoreId': AttributeValue(s: scoreId),
        'gameId': AttributeValue(s: gameId),
        'score': AttributeValue(n: score.toString()),
        'duration': AttributeValue(n: duration.toString()),
        'difficulty': AttributeValue(s: difficulty),
      };

      // Add metadata if provided
      metadata?.forEach((key, value) {
        scoreItem[key] = _toAttributeValue(value);
      });

      await _dynamodb.putItem(
        tableName: _scoresTable,
        item: scoreItem,
      );

      // Update leaderboard
      await _updateLeaderboard(userId, gameId, score);

      // Update user stats
      await _updateUserStats(userId, score);

      print('Score submitted successfully: $score');
    } catch (e) {
      print('Error submitting game score: $e');
      rethrow;
    }
  }

  /// Get user's score for a specific game
  Future<Map<String, dynamic>?> getUserGameScore(
    String userId,
    String gameId,
  ) async {
    try {
      final response = await _dynamodb.query(
        tableName: _scoresTable,
        keyConditionExpression: 'userId = :uid AND gameId = :gid',
        expressionAttributeValues: {
          ':uid': AttributeValue(s: userId),
          ':gid': AttributeValue(s: gameId),
        },
        limit: 1,
        scanIndexForward: false,
      );

      if (response.items == null || response.items!.isEmpty) {
        return null;
      }

      return _convertDynamoDBItem(response.items!.first);
    } catch (e) {
      print('Error fetching user game score: $e');
      return null;
    }
  }

  /// Get all scores for a user
  Future<List<Map<String, dynamic>>> getUserAllScores(String userId) async {
    try {
      final response = await _dynamodb.query(
        tableName: _scoresTable,
        keyConditionExpression: 'userId = :uid',
        expressionAttributeValues: {
          ':uid': AttributeValue(s: userId),
        },
        scanIndexForward: false,
        limit: 100,
      );

      return response.items
          ?.map((item) => _convertDynamoDBItem(item))
          .toList() ?? [];
    } catch (e) {
      print('Error fetching user all scores: $e');
      return [];
    }
  }

  // ============================================
  // Leaderboard Methods
  // ============================================

  /// Get top scores for a game (leaderboard)
  Future<List<Map<String, dynamic>>> getGameLeaderboard(
    String gameId, {
    int limit = 100,
  }) async {
    try {
      final response = await _dynamodb.query(
        tableName: _leaderboardsTable,
        keyConditionExpression: 'gameId = :gid',
        expressionAttributeValues: {
          ':gid': AttributeValue(s: gameId),
        },
        scanIndexForward: false,
        limit: limit,
      );

      final leaderboard = <Map<String, dynamic>>[];
      
      response.items?.forEach((item) {
        leaderboard.add(_convertDynamoDBItem(item));
      });

      return leaderboard;
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return [];
    }
  }

  /// Get user's rank in a game leaderboard
  Future<int> getUserLeaderboardRank(String userId, String gameId) async {
    try {
      final leaderboard = await getGameLeaderboard(gameId, limit: 1000);
      
      for (int i = 0; i < leaderboard.length; i++) {
        if (leaderboard[i]['userId'] == userId) {
          return i + 1;
        }
      }

      return -1; // Not found
    } catch (e) {
      print('Error fetching user rank: $e');
      return -1;
    }
  }

  // ============================================
  // S3 Storage Methods
  // ============================================

  /// Upload file to S3
  Future<String> uploadFile({
    required String fileName,
    required List<int> fileBytes,
    String contentType = 'application/octet-stream',
  }) async {
    try {
      await _s3.putObject(
        bucket: _assetsBucket,
        key: fileName,
        body: fileBytes,
        contentType: contentType,
      );

      final fileUrl = 'https://$_assetsBucket.s3.amazonaws.com/$fileName';
      print('File uploaded: $fileUrl');
      return fileUrl;
    } catch (e) {
      print('Error uploading file: $e');
      rethrow;
    }
  }

  /// Download file from S3
  Future<List<int>?> downloadFile(String fileName) async {
    try {
      final response = await _s3.getObject(
        bucket: _assetsBucket,
        key: fileName,
      );

      return await response.body.toBytes();
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }

  // ============================================
  // Private Helper Methods
  // ============================================

  /// Update leaderboard entry
  Future<void> _updateLeaderboard(
    String userId,
    String gameId,
    int score,
  ) async {
    try {
      await _dynamodb.putItem(
        tableName: _leaderboardsTable,
        item: {
          'gameId': AttributeValue(s: gameId),
          'score': AttributeValue(n: score.toString()),
          'userId': AttributeValue(s: userId),
          'timestamp': AttributeValue(
            n: DateTime.now().millisecondsSinceEpoch.toString(),
          ),
        },
      );
    } catch (e) {
      print('Error updating leaderboard: $e');
    }
  }

  /// Update user statistics
  Future<void> _updateUserStats(String userId, int score) async {
    try {
      await _dynamodb.updateItem(
        tableName: _usersTable,
        key: {'userId': AttributeValue(s: userId)},
        attributeUpdates: {
          'totalScore': AttributeValueUpdate(
            value: AttributeValue(n: score.toString()),
            action: 'ADD',
          ),
          'gamesPlayed': AttributeValueUpdate(
            value: AttributeValue(n: '1'),
            action: 'ADD',
          ),
        },
      );
    } catch (e) {
      print('Error updating user stats: $e');
    }
  }

  /// Convert DynamoDB item to Map
  Map<String, dynamic> _convertDynamoDBItem(Map<String, AttributeValue> item) {
    final result = <String, dynamic>{};
    
    item.forEach((key, value) {
      if (value.s != null) {
        result[key] = value.s;
      } else if (value.n != null) {
        result[key] = int.tryParse(value.n!) ?? double.parse(value.n!);
      } else if (value.bool != null) {
        result[key] = value.bool;
      } else if (value.m != null) {
        result[key] = _convertDynamoDBItem(value.m!);
      } else if (value.l != null) {
        result[key] = value.l!.map((v) {
          if (v.s != null) return v.s;
          if (v.n != null) return int.tryParse(v.n!) ?? double.parse(v.n!);
          return null;
        }).toList();
      }
    });

    return result;
  }

  /// Convert Dart value to DynamoDB AttributeValue
  AttributeValue _toAttributeValue(dynamic value) {
    if (value is String) {
      return AttributeValue(s: value);
    } else if (value is int) {
      return AttributeValue(n: value.toString());
    } else if (value is double) {
      return AttributeValue(n: value.toString());
    } else if (value is bool) {
      return AttributeValue(bool: value);
    } else if (value is Map) {
      final map = <String, AttributeValue>{};
      value.forEach((k, v) => map[k] = _toAttributeValue(v));
      return AttributeValue(m: map);
    } else if (value is List) {
      return AttributeValue(
        l: value.map(_toAttributeValue).toList(),
      );
    }
    return AttributeValue(s: value.toString());
  }

  // ============================================
  // Getters
  // ============================================

  String get apiEndpoint => _apiEndpoint;
}
