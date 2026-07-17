import 'package:junko_bodie/models/player.dart';
import 'package:junko_bodie/services/api_service.dart';

/// Service for managing user profile and balance data.
class UserService {
  final ApiService _api = ApiService();

  /// Fetch the current authenticated user's player profile.
  Future<Player> getProfile() async {
    final json = await _api.get('/api/user/profile');
    return Player.fromJson(json);
  }

  /// Update individual profile settings.
  Future<bool> updateProfile({
    String? name,
    String? avatarUrl,
    bool? isSoundEnabled,
    bool? isTimerEnabled,
    bool? isPopupEnabled,
    double? startingBalance,
    bool? hasSeenWelcomeVideo,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (isSoundEnabled != null) body['is_sound_enabled'] = isSoundEnabled;
    if (isTimerEnabled != null) body['is_timer_enabled'] = isTimerEnabled;
    if (isPopupEnabled != null) body['is_popup_enabled'] = isPopupEnabled;
    if (startingBalance != null) body['starting_balance'] = startingBalance;
    if (hasSeenWelcomeVideo != null) {
      body['has_seen_welcome_video'] = hasSeenWelcomeVideo;
    }

    final json = await _api.patch('/api/user/profile', body: body);
    return json['success'] == true;
  }

  /// Delete the current user's account and all associated data.
  ///
  /// Calls the backend which removes the user from Supabase Auth,
  /// Stripe, and all related database tables.
  Future<bool> deleteAccount() async {
    final json = await _api.delete('/api/user/account');
    return json['success'] == true;
  }

  /// Update player play-money balance on the server.
  ///
  /// [action] must be 'increment', 'decrement', or 'set'.
  /// Returns the newly updated balance.
  Future<double> updateBalance({
    required double amount,
    required String action,
  }) async {
    assert(
      action == 'increment' || action == 'decrement' || action == 'set',
      'Invalid balance update action',
    );
    final json = await _api.patch(
      '/api/user/balance',
      body: {'amount': amount, 'action': action},
    );
    return (json['balance'] ?? 0.0).toDouble();
  }
}
