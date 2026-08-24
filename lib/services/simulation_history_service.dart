/// Local persistence for simulation run history.
///
/// Mirrors the web app's `localStorage` key `sim_history_<strategyId>` — keeps
/// the last 3 [SimulationResult] runs per strategy so the Test Results History
/// screen can list and re-open them.
library;

import 'dart:convert';

import 'package:junko_bodie/logic/simulation_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SimulationHistoryService {
  static const int _maxRuns = 3;

  String _key(String strategyId) => 'sim_history_$strategyId';

  Future<List<SimulationResult>> getHistory(String strategyId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(strategyId));
    if (raw == null) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => SimulationResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Prepend [result] to this strategy's history (newest first), capped at 3.
  Future<void> addRun(SimulationResult result) async {
    if (result.strategyId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = await getHistory(result.strategyId);
    final updated = [result, ...existing];
    if (updated.length > _maxRuns) updated.removeRange(_maxRuns, updated.length);
    await prefs.setString(
      _key(result.strategyId),
      jsonEncode(updated.map((r) => r.toJson()).toList()),
    );
  }
}
