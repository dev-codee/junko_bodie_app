import 'package:junko_bodie/models/tournament.dart';
import 'package:junko_bodie/models/round.dart';
import 'package:junko_bodie/models/spin.dart';
import 'package:junko_bodie/services/api_service.dart';

/// Wraps tournament details including live status, round, spin, history, and timings.
class TournamentDetails {
  final Tournament tournament;
  final Round? activeRound;
  final Spin? latestSpin;
  final List<dynamic> history;
  final int serverTime;
  final String calculatedPhase;
  final int bettingDeadline;

  TournamentDetails({
    required this.tournament,
    this.activeRound,
    this.latestSpin,
    required this.history,
    required this.serverTime,
    required this.calculatedPhase,
    required this.bettingDeadline,
  });

  factory TournamentDetails.fromJson(Map<String, dynamic> json) =>
      TournamentDetails(
        tournament: Tournament.fromJson(json),
        activeRound: json['active_round'] != null
            ? Round.fromJson(json['active_round'])
            : null,
        latestSpin: json['latest_spin'] != null
            ? Spin.fromJson(json['latest_spin'])
            : null,
        history: json['history'] ?? [],
        serverTime:
            json['server_time'] ?? DateTime.now().millisecondsSinceEpoch,
        calculatedPhase: json['calculated_phase'] ?? 'waiting',
        bettingDeadline: json['betting_deadline'] ?? 0,
      );
}

/// Represents information of a player who has been eliminated from the tournament.
class EliminatedPlayerInfo {
  final String playerId;
  final String username;
  final bool isBot;
  final double finalChips;
  final int position;

  EliminatedPlayerInfo({
    required this.playerId,
    required this.username,
    required this.isBot,
    required this.finalChips,
    required this.position,
  });

  factory EliminatedPlayerInfo.fromJson(Map<String, dynamic> json) =>
      EliminatedPlayerInfo(
        playerId: json['player_id']?.toString() ?? '',
        username: json['username'] ?? '',
        isBot: json['is_bot'] ?? false,
        finalChips: (json['final_chips'] ?? 0).toDouble(),
        position: json['position'] ?? 0,
      );
}

/// Result of an elimination operation.
class EliminationResult {
  final bool success;
  final EliminatedPlayerInfo? eliminatedPlayer;
  final int nextRound;

  EliminationResult({
    required this.success,
    this.eliminatedPlayer,
    required this.nextRound,
  });

  factory EliminationResult.fromJson(Map<String, dynamic> json) =>
      EliminationResult(
        success: json['success'] ?? false,
        eliminatedPlayer: json['eliminatedPlayer'] != null
            ? EliminatedPlayerInfo.fromJson(json['eliminatedPlayer'])
            : null,
        nextRound: json['nextRound'] ?? 1,
      );
}

/// Service for managing tournament execution, lobby, rounds, and bets.
class TournamentService {
  final ApiService _api = ApiService();

  /// Create a new tournament or join an existing queue.
  ///
  /// [wheelType] can be 'american' or 'european'.
  Future<Tournament> createOrJoinTournament(String wheelType) async {
    assert(
      wheelType == 'american' || wheelType == 'european',
      'Invalid wheel type',
    );
    final json = await _api.post(
      '/api/tournament/create',
      body: {'wheel_type': wheelType},
    );
    return Tournament.fromJson(json);
  }

  /// Fetch full status, rounds, history, and timers for a tournament.
  Future<TournamentDetails> getTournamentDetails(String id) async {
    final json = await _api.get('/api/tournament/$id');
    return TournamentDetails.fromJson(json);
  }

  /// Change the wheel type of the tournament (before it starts).
  Future<bool> updateWheelType(String id, String wheelType) async {
    assert(
      wheelType == 'american' || wheelType == 'european',
      'Invalid wheel type',
    );
    final json = await _api.patch(
      '/api/tournament/$id',
      body: {'wheel_type': wheelType},
    );
    return json['success'] == true;
  }

  /// Synchronize intermediate pending bets during the betting window.
  Future<bool> syncBets(
    String tournamentId,
    String playerId,
    List<dynamic> bets,
  ) async {
    final json = await _api.post(
      '/api/tournament/$tournamentId/bets/sync',
      body: {'player_id': playerId, 'bets': bets},
    );
    return json['success'] == true;
  }

  /// Submit and lock bets, completing the betting window for this player.
  Future<bool> lockBets(
    String tournamentId,
    String playerId,
    List<dynamic> bets,
    String roundId,
  ) async {
    final json = await _api.post(
      '/api/tournament/$tournamentId/bets/lock',
      body: {'player_id': playerId, 'bets': bets, 'round_id': roundId},
    );
    return json['success'] == true;
  }

  /// Start a new round of the tournament.
  Future<Round> startRound(String tournamentId) async {
    final json = await _api.post('/api/tournament/$tournamentId/round/start');
    return Round.fromJson(json);
  }

  /// Trigger elimination resolution for the round.
  Future<EliminationResult> eliminatePlayer(
    String tournamentId,
    String roundId,
  ) async {
    final json = await _api.post(
      '/api/tournament/$tournamentId/round/$roundId/eliminate',
    );
    return EliminationResult.fromJson(json);
  }
}
