import 'package:junko_bodie/services/api_service.dart';

/// A single recorded play session (solo or tournament).
class GameSession {
  final String id;
  final String sessionType; // 'solo' | 'tournament'
  final DateTime startTime;
  final DateTime? endTime;
  final double startingBankroll;
  final double? endingBankroll;
  final double? currentBankroll;
  final int totalSpins;
  final int totalWins;
  final double? profitLoss;
  final double? winPercentage;
  final double highestBankroll;
  final double lowestBankroll;
  final double largestDrawdown;
  final double biggestSingleWin;
  final String? strategyName;

  GameSession({
    required this.id,
    required this.sessionType,
    required this.startTime,
    this.endTime,
    required this.startingBankroll,
    this.endingBankroll,
    this.currentBankroll,
    required this.totalSpins,
    required this.totalWins,
    this.profitLoss,
    this.winPercentage,
    required this.highestBankroll,
    required this.lowestBankroll,
    required this.largestDrawdown,
    required this.biggestSingleWin,
    this.strategyName,
  });

  /// Profit/loss, falling back to current_bankroll − starting when no end yet.
  double? get computedProfit {
    if (profitLoss != null) return profitLoss;
    if (currentBankroll != null) return currentBankroll! - startingBankroll;
    return null;
  }

  static double _d(dynamic v) => (v ?? 0).toDouble();
  static DateTime? _date(dynamic v) =>
      v != null ? DateTime.tryParse(v.toString()) : null;

  factory GameSession.fromJson(Map<String, dynamic> j) => GameSession(
        id: j['_id']?.toString() ?? '',
        sessionType: j['session_type'] == 'tournament' ? 'tournament' : 'solo',
        startTime: _date(j['start_time']) ?? DateTime.now(),
        endTime: _date(j['end_time']),
        startingBankroll: _d(j['starting_bankroll']),
        endingBankroll: j['ending_bankroll'] != null ? _d(j['ending_bankroll']) : null,
        currentBankroll: j['current_bankroll'] != null ? _d(j['current_bankroll']) : null,
        totalSpins: (j['total_spins'] ?? 0) as int,
        totalWins: (j['total_wins'] ?? 0) as int,
        profitLoss: j['profit_loss'] != null ? _d(j['profit_loss']) : null,
        winPercentage: j['win_percentage'] != null ? _d(j['win_percentage']) : null,
        highestBankroll: _d(j['highest_bankroll']),
        lowestBankroll: _d(j['lowest_bankroll']),
        largestDrawdown: _d(j['largest_drawdown']),
        biggestSingleWin: _d(j['biggest_single_win']),
        strategyName: j['strategy_name']?.toString(),
      );
}

/// Aggregated lifetime statistics for the player.
class LifetimeStats {
  final int totalSessions;
  final int totalSpins;
  final int totalWins;
  final double totalProfitLoss;
  final double bestSessionProfit;
  final double worstSessionLoss;
  final double biggestSingleWin;
  final double avgWinPercentage;
  final double bestBankroll;
  final double avgNetPerSpin;
  final double totalVolumeWagered;

  LifetimeStats({
    required this.totalSessions,
    required this.totalSpins,
    required this.totalWins,
    required this.totalProfitLoss,
    required this.bestSessionProfit,
    required this.worstSessionLoss,
    required this.biggestSingleWin,
    required this.avgWinPercentage,
    required this.bestBankroll,
    required this.avgNetPerSpin,
    required this.totalVolumeWagered,
  });

  static double _d(dynamic v) => (v ?? 0).toDouble();

  factory LifetimeStats.fromJson(Map<String, dynamic> j) => LifetimeStats(
        totalSessions: (j['total_sessions'] ?? 0) as int,
        totalSpins: (j['total_spins'] ?? 0) as int,
        totalWins: (j['total_wins'] ?? 0) as int,
        totalProfitLoss: _d(j['total_profit_loss']),
        bestSessionProfit: _d(j['best_session_profit']),
        worstSessionLoss: _d(j['worst_session_loss']),
        biggestSingleWin: _d(j['biggest_single_win']),
        avgWinPercentage: _d(j['avg_win_percentage']),
        bestBankroll: _d(j['best_bankroll']),
        avgNetPerSpin: _d(j['avg_net_per_spin']),
        totalVolumeWagered: _d(j['total_volume_wagered']),
      );
}

/// Service for the Session History feature — wraps /api/sessions/* endpoints.
class SessionHistoryService {
  final ApiService _api = ApiService();

  /// Recent sessions (limit 10 or 30).
  Future<List<GameSession>> getSessions({int limit = 10}) async {
    final json = await _api.get('/api/sessions?limit=$limit');
    final list = (json['sessions'] as List<dynamic>?) ?? [];
    return list
        .map((e) => GameSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Aggregated lifetime stats (null when no completed sessions).
  Future<LifetimeStats?> getLifetime() async {
    final json = await _api.get('/api/sessions/lifetime');
    final data = json['lifetime'];
    if (data == null) return null;
    return LifetimeStats.fromJson(data as Map<String, dynamic>);
  }

  /// Delete a single session and its spins.
  Future<bool> deleteSession(String id) async {
    final json = await _api.delete('/api/sessions/$id');
    return json['ok'] == true;
  }

  /// Clear ALL sessions for the user.
  Future<bool> clearAll() async {
    final json = await _api.delete('/api/sessions');
    return json['ok'] == true;
  }

  // ── Recording (mirrors the web's useSessionTracking) ──────────────────────

  /// Start a new session. Returns the new session id (or null on failure).
  Future<String?> createSession({
    required String sessionType, // 'solo' | 'tournament'
    required double startingBankroll,
  }) async {
    final json = await _api.post('/api/sessions', body: {
      'session_type': sessionType,
      'starting_bankroll': startingBankroll,
    });
    return json['id']?.toString();
  }

  /// Log a single resolved spin.
  Future<void> logSpin(
    String sessionId, {
    required double betTotal,
    required double netResult,
    required double bankrollAfter,
  }) async {
    await _api.post('/api/sessions/$sessionId/spins', body: {
      'bet_total': betTotal,
      'net_result': netResult,
      'bankroll_after': bankrollAfter,
    });
  }

  /// End the session (finalizes end_time + profit_loss).
  Future<void> endSession(String sessionId, {required double endingBankroll}) async {
    await _api.patch('/api/sessions/$sessionId', body: {
      'ending': true,
      'ending_bankroll': endingBankroll,
    });
  }
}
