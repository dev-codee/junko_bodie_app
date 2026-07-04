class RankingEntry {
  final String playerId;
  final String username;
  final int points;
  final int rank;
  final int tournamentsPlayed;
  final int tournamentsWon;
  final String? avatarUrl;
  final Map<String, dynamic>? badges;

  RankingEntry({
    required this.playerId,
    required this.username,
    required this.points,
    required this.rank,
    required this.tournamentsPlayed,
    required this.tournamentsWon,
    this.avatarUrl,
    this.badges,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) => RankingEntry(
        playerId: json['player_id']?.toString() ?? '',
        username: json['username'] ?? '',
        points: json['points'] ?? 0,
        rank: json['rank'] ?? 0,
        tournamentsPlayed: json['tournaments_played'] ?? 0,
        tournamentsWon: json['tournaments_won'] ?? 0,
        avatarUrl: json['avatar_url'],
        badges: json['badges'],
      );

  Map<String, dynamic> toJson() => {
        'player_id': playerId,
        'username': username,
        'points': points,
        'rank': rank,
        'tournaments_played': tournamentsPlayed,
        'tournaments_won': tournamentsWon,
        'avatar_url': avatarUrl,
        'badges': badges,
      };
}

class SeasonRanking {
  final String? id;
  final int year;
  final List<RankingEntry> rankings;
  final DateTime updatedAt;

  SeasonRanking({
    this.id,
    required this.year,
    required this.rankings,
    required this.updatedAt,
  });

  factory SeasonRanking.fromJson(Map<String, dynamic> json) => SeasonRanking(
        id: json['_id']?.toString(),
        year: json['year'] ?? DateTime.now().year,
        rankings: (json['rankings'] as List<dynamic>?)
                ?.map((e) => RankingEntry.fromJson(e))
                .toList() ??
            [],
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'year': year,
        'rankings': rankings.map((e) => e.toJson()).toList(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
