/// Lightweight persistence for the "last active / last created" strategy id,
/// mirroring the web app's `localStorage` keys `last_created_strategy_id` and
/// `junko_last_active_strategy_id`. Used to pre-select a strategy when the
/// Navigator or Simulation screens are opened without an explicit query id.
library;

import 'package:shared_preferences/shared_preferences.dart';

class StrategyPrefs {
  static const _kLastCreated = 'last_created_strategy_id';
  static const _kLastActive = 'junko_last_active_strategy_id';

  /// Records a freshly created/saved strategy as both last-created and
  /// last-active (matches the web save flow).
  static Future<void> setLastCreated(String id) async {
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastCreated, id);
    await prefs.setString(_kLastActive, id);
  }

  /// Records the strategy the user is currently working with.
  static Future<void> setLastActive(String id) async {
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastActive, id);
  }

  /// Returns the preferred pre-selection id: last-created wins, then
  /// last-active. Null when neither has been stored yet.
  static Future<String?> preferredId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastCreated) ?? prefs.getString(_kLastActive);
  }
}
