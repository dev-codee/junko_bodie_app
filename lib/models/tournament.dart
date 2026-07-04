class TournamentPlayer {
  final String playerId;
  final String username;
  final String avatarUrl;
  final bool isBot;
  final double startingChips;
  final double currentChips;
  final String status;
  final int? eliminatedRound;
  final int? finalPosition;
  final int? pointsEarned;
  final bool? hasChampionBadge;
  final List<dynamic>? pendingBets;
  final int? bustSpin;
  final double? chipsBeforeBust;

  TournamentPlayer({
    required this.playerId,
    required this.username,
    required this.avatarUrl,
    required this.isBot,
    required this.startingChips,
    required this.currentChips,
    required this.status,
    this.eliminatedRound,
    this.finalPosition,
    this.pointsEarned,
    this.hasChampionBadge,
    this.pendingBets,
    this.bustSpin,
    this.chipsBeforeBust,
  });

  factory TournamentPlayer.fromJson(Map<String, dynamic> json) =>
      TournamentPlayer(
        playerId: json['player_id']?.toString() ?? '',
        username: json['username'] ?? '',
        avatarUrl: json['avatar_url'] ?? '',
        isBot: json['is_bot'] ?? false,
        startingChips: (json['starting_chips'] ?? 0).toDouble(),
        currentChips: (json['current_chips'] ?? 0).toDouble(),
        status: json['status'] ?? 'active',
        eliminatedRound: json['eliminated_round'],
        finalPosition: json['final_position'],
        pointsEarned: json['points_earned'],
        hasChampionBadge: json['has_champion_badge'],
        pendingBets: json['pending_bets'],
        bustSpin: json['bust_spin'],
        chipsBeforeBust: json['chips_before_bust'] != null
            ? (json['chips_before_bust']).toDouble()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'player_id': playerId,
        'username': username,
        'avatar_url': avatarUrl,
        'is_bot': isBot,
        'starting_chips': startingChips,
        'current_chips': currentChips,
        'status': status,
        'eliminated_round': eliminatedRound,
        'final_position': finalPosition,
        'points_earned': pointsEarned,
        'has_champion_badge': hasChampionBadge,
        'pending_bets': pendingBets,
        'bust_spin': bustSpin,
        'chips_before_bust': chipsBeforeBust,
      };
}

class Tournament {
  final String? id;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int currentRound;
  final String? winnerId;
  final List<TournamentPlayer> players;
  final String? wheelType;

  Tournament({
    this.id,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.currentRound,
    this.winnerId,
    required this.players,
    this.wheelType,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
        id: json['_id']?.toString(),
        status: json['status'] ?? 'waiting',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'])
            : null,
        currentRound: json['current_round'] ?? 1,
        winnerId: json['winner_id']?.toString(),
        players: (json['players'] as List<dynamic>?)
                ?.map((e) => TournamentPlayer.fromJson(e))
                .toList() ??
            [],
        wheelType: json['wheel_type'],
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'current_round': currentRound,
        'winner_id': winnerId,
        'players': players.map((e) => e.toJson()).toList(),
        'wheel_type': wheelType,
      };
}
