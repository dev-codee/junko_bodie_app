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
  final DateTime? forfeitedAt;
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
    this.forfeitedAt,
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
        forfeitedAt: DateTime.tryParse(json['forfeited_at']?.toString() ?? ''),
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
    'forfeited_at': forfeitedAt?.toIso8601String(),
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
  final String kind;
  final String? hostId;
  final String? joinCode;
  final bool lobbyClosed;
  final int minPlayers;
  final int maxPlayers;
  final int totalRounds;
  final String? completionReason;
  bool get isPrivate => kind == 'private';

  Tournament({
    this.id,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.currentRound,
    this.winnerId,
    required this.players,
    this.wheelType,
    this.kind = 'public',
    this.hostId,
    this.joinCode,
    this.lobbyClosed = false,
    this.minPlayers = 6,
    this.maxPlayers = 6,
    this.totalRounds = 5,
    this.completionReason,
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
    players:
        (json['players'] as List<dynamic>?)
            ?.map((e) => TournamentPlayer.fromJson(e))
            .toList() ??
        [],
    wheelType: json['wheel_type'],
    kind: json['kind'] ?? 'public',
    hostId: json['host_id']?.toString(),
    joinCode: json['join_code'] as String?,
    lobbyClosed: json['lobby_closed'] == true || json['status'] == 'cancelled',
    minPlayers:
        json['rules']?['min_players'] ?? (json['kind'] == 'private' ? 2 : 6),
    maxPlayers: json['rules']?['max_players'] ?? 6,
    totalRounds: json['total_rounds'] ?? 5,
    completionReason: json['completion_reason'],
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
    'kind': kind,
    'host_id': hostId,
    'join_code': joinCode,
    'lobby_closed': lobbyClosed,
    'total_rounds': totalRounds,
    'completion_reason': completionReason,
    'rules': {'min_players': minPlayers, 'max_players': maxPlayers},
  };
}
