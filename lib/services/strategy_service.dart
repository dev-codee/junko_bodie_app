/// Strategy API service — talks to the Next.js backend strategy endpoints.
///
/// Endpoints used:
///   GET    /api/strategies          → list all strategies for the current user
///   POST   /api/strategies          → create a strategy
///   PUT    /api/strategies/:id       → update a strategy
///   DELETE /api/strategies/:id       → delete a specific strategy
///   POST   /api/user/hide-strategy   → hide / unhide a strategy for this user
///   GET    /api/user/profile         → read hidden_strategies for this user
library;

import 'package:junko_bodie/models/strategy.dart';
import 'package:junko_bodie/services/api_service.dart';

class StrategyService {
  final ApiService _api = ApiService();

  /// Fetch all strategies belonging to the authenticated user.
  Future<List<BettingStrategy>> fetchStrategies() async {
    final data = await _api.get('/api/strategies');
    final List<dynamic> list = data['strategies'] ?? [];
    return list
        .map((j) => BettingStrategy.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single strategy by id (fetches the list and filters, mirroring
  /// the web builder which has no dedicated GET-by-id route).
  Future<BettingStrategy?> fetchStrategyById(String id) async {
    final all = await fetchStrategies();
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Create (POST) a new strategy or update (PUT) an existing one.
  /// Returns the strategy id (new id on create, same id on update).
  Future<String?> saveStrategy(BettingStrategy strategy) async {
    final body = strategy.toJson()..remove('_id');
    if (strategy.id == null || strategy.id!.isEmpty) {
      final data = await _api.post('/api/strategies', body: body);
      return data['id']?.toString() ?? data['_id']?.toString();
    } else {
      await _api.put('/api/strategies/${strategy.id}', body: body);
      return strategy.id;
    }
  }

  /// Import a strategy from a raw JSON map (from a shared / exported file).
  /// Strips export metadata and posts a fresh strategy. Returns the new id.
  Future<String?> importStrategy(Map<String, dynamic> data) async {
    final stages = data['stages'];
    final payload = {
      'name': data['name'],
      'wheel_type': data['wheel_type'],
      'description': data['description'] ?? '',
      'strategy_notes': data['strategy_notes'] ?? '',
      'max_stages': data['max_stages'] ??
          (stages is List ? stages.length : 10),
      'default_mode': data['default_mode'] ?? 'Manual',
      'stages': stages,
      if (data['endgame_recovery'] != null)
        'endgame_recovery': data['endgame_recovery'],
    };
    final res = await _api.post('/api/strategies', body: payload);
    return res['id']?.toString() ?? res['_id']?.toString();
  }

  /// Delete a strategy by its MongoDB ObjectId string.
  Future<void> deleteStrategy(String id) async {
    await _api.delete('/api/strategies/$id');
  }

  /// Update only the strategy notes (partial PUT), mirroring the web Debugger.
  Future<void> updateStrategyNotes(String id, String notes) async {
    await _api.put('/api/strategies/$id', body: {'strategy_notes': notes});
  }

  /// Fetch the list of strategy ids this user has hidden.
  Future<List<String>> fetchHiddenStrategyIds() async {
    try {
      final profile = await _api.get('/api/user/profile');
      final List<dynamic> hidden = profile['hidden_strategies'] ?? [];
      return hidden.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Hide or unhide a strategy for the current user.
  Future<void> setStrategyHidden(String id, bool hide) async {
    await _api.post('/api/user/hide-strategy',
        body: {'strategyId': id, 'action': hide ? 'hide' : 'unhide'});
  }
}
