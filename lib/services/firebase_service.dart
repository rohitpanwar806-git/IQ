import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Firebase Service for IQ Games
/// Handles authentication, score tracking, leaderboards, and analytics
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;
  late final FirebaseAnalytics _analytics;

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  /// Initialize Firebase services
  Future<void> initialize() async {
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    _analytics = FirebaseAnalytics.instance;

    // Enable offline persistence (Firestore)
    await _firestore.enableNetwork();
  }

  // ============================================
  // Authentication Methods
  // ============================================

  /// Sign in anonymously
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      print('Error signing in anonymously: $e');
      return null;
    }
  }

  /// Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print('Error signing in with email: $e');
      return null;
    }
  }

  /// Create user account with email and password
  Future<User?> createUserWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print('Error creating user: $e');
      return null;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Stream of authentication state changes
  Stream<User?> authStateStream() {
    return _auth.authStateChanges();
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
      await _firestore.collection('users').doc(userId).set({
        'displayName': displayName,
        'photoUrl': photoUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'totalScore': 0,
        'gamesPlayed': 0,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error creating user profile: $e');
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Stream of user profile
  Stream<DocumentSnapshot> getUserProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // ============================================
  // Game Score Methods
  // ============================================

  /// Submit a game score to Firestore
  Future<void> submitGameScore({
    required String userId,
    required String gameId,
    required int score,
    required int duration, // in seconds
    String difficulty = 'normal',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final gameScore = {
        'userId': userId,
        'gameId': gameId,
        'score': score,
        'duration': duration,
        'difficulty': difficulty,
        'timestamp': FieldValue.serverTimestamp(),
        ...?metadata,
      };

      // Save to user's scores subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('scores')
          .doc(gameId)
          .set(gameScore, SetOptions(merge: true));

      // Also save to global scores collection (for analytics)
      await _firestore
          .collection('scores')
          .doc(userId)
          .collection('games')
          .add(gameScore);

      // Update user's total score
      await _firestore.collection('users').doc(userId).update({
        'totalScore': FieldValue.increment(score),
        'gamesPlayed': FieldValue.increment(1),
      });

      // Log analytics event
      await _analytics.logEvent(
        name: 'game_completed',
        parameters: {
          'game_id': gameId,
          'score': score,
          'difficulty': difficulty,
          'duration': duration,
        },
      );
    } catch (e) {
      print('Error submitting game score: $e');
    }
  }

  /// Get user's score for a specific game
  Future<Map<String, dynamic>?> getUserGameScore(
    String userId,
    String gameId,
  ) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('scores')
          .doc(gameId)
          .get();
      return doc.data();
    } catch (e) {
      print('Error fetching user game score: $e');
      return null;
    }
  }

  /// Get all scores for a user
  Future<List<Map<String, dynamic>>> getUserAllScores(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('scores')
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching user all scores: $e');
      return [];
    }
  }

  /// Stream of user's game scores
  Stream<QuerySnapshot> getUserScoresStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('scores')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ============================================
  // Leaderboard Methods
  // ============================================

  /// Get top scores for a game (leaderboard)
  Future<List<Map<String, dynamic>>> getGameLeaderboard(
    String gameId, {
    int limit = 100,
    String difficulty = 'all',
  }) async {
    try {
      Query query = _firestore
          .collection('leaderboards')
          .doc(gameId)
          .collection('entries')
          .orderBy('score', descending: true)
          .limit(limit);

      if (difficulty != 'all') {
        query = query.where('difficulty', isEqualTo: difficulty);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return [];
    }
  }

  /// Stream of leaderboard for real-time updates
  Stream<QuerySnapshot> getLeaderboardStream(
    String gameId, {
    int limit = 100,
  }) {
    return _firestore
        .collection('leaderboards')
        .doc(gameId)
        .collection('entries')
        .orderBy('score', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Get user's rank in a game leaderboard
  Future<int> getUserLeaderboardRank(String userId, String gameId) async {
    try {
      final userScore = await getUserGameScore(userId, gameId);
      if (userScore == null) return -1;

      final snapshot = await _firestore
          .collection('leaderboards')
          .doc(gameId)
          .collection('entries')
          .where('score', isGreaterThan: userScore['score'])
          .count()
          .get();

      return snapshot.count + 1; // Rank is 1-indexed
    } catch (e) {
      print('Error fetching user rank: $e');
      return -1;
    }
  }

  // ============================================
  // Analytics Methods
  // ============================================

  /// Log game started event
  Future<void> logGameStarted(String gameId, String difficulty) async {
    try {
      await _analytics.logEvent(
        name: 'game_started',
        parameters: {
          'game_id': gameId,
          'difficulty': difficulty,
        },
      );
    } catch (e) {
      print('Error logging game started: $e');
    }
  }

  /// Log game ended event
  Future<void> logGameEnded(String gameId, int score) async {
    try {
      await _analytics.logEvent(
        name: 'game_ended',
        parameters: {
          'game_id': gameId,
          'score': score,
        },
      );
    } catch (e) {
      print('Error logging game ended: $e');
    }
  }

  /// Log custom event
  Future<void> logCustomEvent(String eventName, Map<String, dynamic> parameters) async {
    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters,
      );
    } catch (e) {
      print('Error logging custom event: $e');
    }
  }

  // ============================================
  // Push Notification Methods
  // ============================================

  /// Save push notification token for user
  Future<void> saveNotificationToken(String userId, String token) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notificationTokens')
          .doc(token)
          .set({
            'token': token,
            'createdAt': FieldValue.serverTimestamp(),
            'platform': defaultTargetPlatform.toString(),
          });
    } catch (e) {
      print('Error saving notification token: $e');
    }
  }

  /// Delete push notification token
  Future<void> deleteNotificationToken(String userId, String token) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notificationTokens')
          .doc(token)
          .delete();
    } catch (e) {
      print('Error deleting notification token: $e');
    }
  }

  // ============================================
  // Utility Methods
  // ============================================

  /// Get Firestore instance
  FirebaseFirestore get firestore => _firestore;

  /// Get Firebase Auth instance
  FirebaseAuth get auth => _auth;

  /// Get Firebase Analytics instance
  FirebaseAnalytics get analytics => _analytics;
}
