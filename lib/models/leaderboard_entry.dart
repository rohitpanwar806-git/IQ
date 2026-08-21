/// A single row in a game leaderboard, returned by the backend API.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.score,
    required this.timestamp,
  });

  final int rank;
  final String userId;
  final String displayName;
  final int score;
  final int timestamp;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Anonymous',
      score: (json['score'] as num?)?.toInt() ?? 0,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}
