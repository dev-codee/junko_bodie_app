class Round {
  final String? id;
  final String tournamentId;
  final int roundNumber;
  final String status;
  final int spinsCompleted;
  final List<String> playersRemaining;
  final String? eliminatedPlayerId;
  final DateTime createdAt;
  final DateTime? lastSpinCompletedAt;
  final DateTime bettingEndsAt;
  final DateTime? completedAt;
  final List<dynamic>? botBets;

  Round({
    this.id,
    required this.tournamentId,
    required this.roundNumber,
    required this.status,
    required this.spinsCompleted,
    required this.playersRemaining,
    this.eliminatedPlayerId,
    required this.createdAt,
    this.lastSpinCompletedAt,
    required this.bettingEndsAt,
    this.completedAt,
    this.botBets,
  });

  factory Round.fromJson(Map<String, dynamic> json) => Round(
        id: json['_id']?.toString(),
        tournamentId: json['tournament_id']?.toString() ?? '',
        roundNumber: json['round_number'] ?? 1,
        status: json['status'] ?? 'active',
        spinsCompleted: json['spins_completed'] ?? 0,
        playersRemaining: (json['players_remaining'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        eliminatedPlayerId: json['eliminated_player_id']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        lastSpinCompletedAt: json['last_spin_completed_at'] != null
            ? DateTime.parse(json['last_spin_completed_at'])
            : null,
        bettingEndsAt: json['betting_ends_at'] != null
            ? DateTime.parse(json['betting_ends_at'])
            : DateTime.now(),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'])
            : null,
        botBets: json['bot_bets'],
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'tournament_id': tournamentId,
        'round_number': roundNumber,
        'status': status,
        'spins_completed': spinsCompleted,
        'players_remaining': playersRemaining,
        'eliminated_player_id': eliminatedPlayerId,
        'created_at': createdAt.toIso8601String(),
        'last_spin_completed_at': lastSpinCompletedAt?.toIso8601String(),
        'betting_ends_at': bettingEndsAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'bot_bets': botBets,
      };
}
