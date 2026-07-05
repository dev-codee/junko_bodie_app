/// Strategy API service — talks to the Next.js backend strategy endpoints.
///
/// Endpoints used:
///   GET    /api/strategies       → list all strategies for the current user
///   DELETE /api/strategies/:id   → delete a specific strategy
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

  /// Delete a strategy by its MongoDB ObjectId string.
  Future<void> deleteStrategy(String id) async {
    await _api.delete('/api/strategies/$id');
  }
}
