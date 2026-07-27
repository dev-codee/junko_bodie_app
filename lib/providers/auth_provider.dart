/// Auth provider — manages Supabase authentication state.
///
/// Translated from GameContext.tsx auth-related logic.
/// Uses Provider (ChangeNotifier) pattern.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:junko_bodie/services/subscription_service.dart';
import 'package:junko_bodie/services/purchases_service.dart';
import 'package:junko_bodie/services/user_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = true;
  bool _hasSubscription = false;
  bool _needsPasswordReset = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get hasSubscription => _hasSubscription;
  bool get needsPasswordReset => _needsPasswordReset;

  final SupabaseClient _supabase = Supabase.instance.client;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    // Listen for auth state changes
    _supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      _user = data.session?.user;

      if (event == AuthChangeEvent.passwordRecovery) {
        _needsPasswordReset = true;
      }

      // Check subscription when user signs in
      if (_user != null) {
        await checkSubscription();
      } else {
        _hasSubscription = false;
      }
      
      _isLoading = false;
      notifyListeners();
    });

    // Get initial session
    final session = _supabase.auth.currentSession;
    _user = session?.user;
    
    if (_user != null) {
      await checkSubscription();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Check if the user has an active subscription.
  /// Checks local RevenueCat state first, then calls the backend API endpoint.
  Future<void> checkSubscription() async {
    try {
      // 1. Check local RevenueCat purchase (App Store / Play Store)
      final rcSubscribed = await PurchasesService().isSubscribed();
      if (rcSubscribed) {
        _hasSubscription = true;
        notifyListeners();
        return;
      }

      // 2. Fallback: check backend status (Stripe web purchases)
      final status = await SubscriptionService().getStatus();
      _hasSubscription = status.hasAccess;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking subscription status: $e');
      }
      _hasSubscription = false;
    }
    notifyListeners();
  }

  /// Sign in with Google OAuth.
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.junkobodieroulette.app://login-callback/',
    );
  }

  /// Sign in with Apple. Required by Apple App Store Guidelines (4.8).
  /// Uses native flow on iOS/macOS and falls back to Web OAuth flow on other platforms.
  Future<void> signInWithApple() async {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)) {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('Apple identity token is null.');
      }

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );
    } else {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'com.junkobodieroulette.app://login-callback/',
      );
    }
  }

  /// Sign in with email and password.
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with email and password.
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Request a password reset email.
  Future<void> resetPasswordForEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'com.junkobodieroulette.app://login-callback/',
    );
  }

  /// Update password (used after deep linking via password recovery)
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
    _needsPasswordReset = false;
    notifyListeners();
  }

  /// Sign out.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _user = null;
    _hasSubscription = false;
    notifyListeners();
  }

  /// Delete the current user's account and all associated data,
  /// then sign the user out. Required by Apple App Store Guideline 5.1.1.
  Future<void> deleteAccount() async {
    final userService = UserService();
    await userService.deleteAccount();
    await signOut();
  }
}
