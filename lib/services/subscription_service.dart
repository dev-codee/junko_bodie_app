import 'package:junko_bodie/services/api_service.dart';

/// Represents the subscription status of a user.
class SubscriptionStatus {
  final bool hasAccess;
  final String? status;
  final String? plan;
  final bool isAuthenticated;

  SubscriptionStatus({
    required this.hasAccess,
    this.status,
    this.plan,
    required this.isAuthenticated,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) =>
      SubscriptionStatus(
        hasAccess: json['hasAccess'] ?? false,
        status: json['status'],
        plan: json['plan'],
        isAuthenticated: json['isAuthenticated'] ?? false,
      );
}

/// Service for checking Stripe subscription status on the backend.
class SubscriptionService {
  final ApiService _api = ApiService();

  /// Retrieve the subscription status for the authenticated user.
  Future<SubscriptionStatus> getStatus() async {
    final json = await _api.get('/api/subscription/status');
    return SubscriptionStatus.fromJson(json);
  }
}
