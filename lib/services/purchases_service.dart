import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchasesService {
  static final PurchasesService _instance = PurchasesService._internal();

  factory PurchasesService() {
    return _instance;
  }

  PurchasesService._internal();

  // TODO: Replace with your actual RevenueCat API keys
  static const String _appleApiKey = 'appl_BmkBhcPKGxMJSUXTmeFNGqaUBnM';
  static const String _googleApiKey = 'goog_BjtgBCStEkOwVWJbhtciNrUqOrz';

  bool _isConfigured = false;

  /// Initialize RevenueCat SDK
  Future<void> init() async {
    if (_isConfigured) return;

    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      configuration = PurchasesConfiguration(_appleApiKey);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      configuration = PurchasesConfiguration(_googleApiKey);
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
      _isConfigured = true;
    }
  }

  /// Login the user with their Supabase Auth UID
  /// This ensures their purchases are tied to their backend account
  Future<void> login(String supabaseUid) async {
    if (!_isConfigured) return;
    try {
      await Purchases.logIn(supabaseUid);
    } catch (e) {
      debugPrint('Error logging into RevenueCat: $e');
    }
  }

  /// Logout (e.g., when they sign out of Supabase)
  Future<void> logout() async {
    if (!_isConfigured) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('Error logging out of RevenueCat: $e');
    }
  }

  /// Fetch available offerings (subscriptions)
  Future<List<Package>> getOfferings() async {
    if (!_isConfigured) return [];
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        return offerings.current!.availablePackages;
      }
    } catch (e) {
      debugPrint('Error fetching offerings: $e');
    }
    return [];
  }

  /// Purchase a specific package
  Future<bool> purchasePackage(Package package) async {
    try {
      final purchaseResult = await Purchases.purchasePackage(package);
      // Assuming your entitlement is named 'premium' in RevenueCat
      return purchaseResult
              .customerInfo
              .entitlements
              .all['premium']
              ?.isActive ??
          false;
    } catch (e) {
      debugPrint('Purchase error: $e');
      return false;
    }
  }

  /// Check if the user is currently subscribed
  Future<bool> isSubscribed() async {
    if (!_isConfigured) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } catch (e) {
      debugPrint('Error checking subscription: $e');
      return false;
    }
  }

  /// Restore previous purchases
  Future<bool> restorePurchases() async {
    if (!_isConfigured) return false;
    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      return false;
    }
  }
}
