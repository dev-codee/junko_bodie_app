class SpinResult {
  final int number;
  final String color;
  final String parity;
  final String dozen;
  final String column;
  final String half;

  SpinResult({
    required this.number,
    required this.color,
    required this.parity,
    required this.dozen,
    required this.column,
    required this.half,
  });

  factory SpinResult.fromJson(Map<String, dynamic> json) => SpinResult(
        number: json['number'] ?? 0,
        color: json['color'] ?? '',
        parity: json['parity'] ?? '',
        dozen: json['dozen'] ?? '',
        column: json['column'] ?? '',
        half: json['half'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'color': color,
        'parity': parity,
        'dozen': dozen,
        'column': column,
        'half': half,
      };
}

class PlayerResult {
  final String playerId;
  final List<dynamic> betsPlaced;
  final double chipsBefore;
  final double chipsAfter;
  final double netChange;

  PlayerResult({
    required this.playerId,
    required this.betsPlaced,
    required this.chipsBefore,
    required this.chipsAfter,
    required this.netChange,
  });

  factory PlayerResult.fromJson(Map<String, dynamic> json) => PlayerResult(
        playerId: json['player_id']?.toString() ?? '',
        betsPlaced: json['bets_placed'] ?? [],
        chipsBefore: (json['chips_before'] ?? 0).toDouble(),
        chipsAfter: (json['chips_after'] ?? 0).toDouble(),
        netChange: (json['net_change'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'player_id': playerId,
        'bets_placed': betsPlaced,
        'chips_before': chipsBefore,
        'chips_after': chipsAfter,
        'net_change': netChange,
      };
}

class Spin {
  final String? id;
  final String tournamentId;
  final String roundId;
  final int spinNumber;
  final SpinResult result;
  final List<PlayerResult> playerResults;
  final DateTime createdAt;

  Spin({
    this.id,
    required this.tournamentId,
    required this.roundId,
    required this.spinNumber,
    required this.result,
    required this.playerResults,
    required this.createdAt,
  });

  factory Spin.fromJson(Map<String, dynamic> json) => Spin(
        id: json['_id']?.toString(),
        tournamentId: json['tournament_id']?.toString() ?? '',
        roundId: json['round_id']?.toString() ?? '',
        spinNumber: json['spin_number'] ?? 0,
        result: SpinResult.fromJson(json['result'] ?? {}),
        playerResults: (json['player_results'] as List<dynamic>?)
                ?.map((e) => PlayerResult.fromJson(e))
                .toList() ??
            [],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'tournament_id': tournamentId,
        'round_id': roundId,
        'spin_number': spinNumber,
        'result': result.toJson(),
        'player_results': playerResults.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}
