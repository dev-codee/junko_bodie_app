import 'package:junko_bodie/services/api_service.dart';

/// Represents a user entry on the global leaderboard.
class LeaderboardEntry {
  final int rank;
  final String id;
  final String name;
  final double balance;
  final String? avatar;
  final int tournamentsWon;
  final Map<String, dynamic>? badges;
  final bool isPro;

  LeaderboardEntry({
    required this.rank,
    required this.id,
    required this.name,
    required this.balance,
    this.avatar,
    required this.tournamentsWon,
    this.badges,
    required this.isPro,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: json['rank'] ?? 0,
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? '',
        balance: (json['balance'] ?? 0).toDouble(),
        avatar: json['avatar'],
        tournamentsWon: json['tournaments_won'] ?? 0,
        badges: json['badges'] as Map<String, dynamic>?,
        isPro: json['is_pro'] ?? false,
      );
}

/// Service for retrieving top players from the leaderboard.
class LeaderboardService {
  final ApiService _api = ApiService();

  /// Fetch top 100 players sorted by balance.
  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final json = await _api.get('/api/leaderboard');
    final list = json['leaderboard'] as List<dynamic>?;
    if (list == null) return [];
    return list.map((e) => LeaderboardEntry.fromJson(e)).toList();
  }
}
