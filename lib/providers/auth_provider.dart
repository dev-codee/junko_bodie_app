/// Auth provider — manages Supabase authentication state.
///
/// Translated from GameContext.tsx auth-related logic.
/// Uses Provider (ChangeNotifier) pattern.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:junko_bodie/services/subscription_service.dart';
import 'package:junko_bodie/services/user_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = true;
  bool _hasSubscription = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get hasSubscription => _hasSubscription;

  final SupabaseClient _supabase = Supabase.instance.client;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    // Listen for auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      _isLoading = false;
      notifyListeners();

      // Check subscription when user signs in
      if (_user != null) {
        checkSubscription();
      } else {
        _hasSubscription = false;
        notifyListeners();
      }
    });

    // Get initial session
    final session = _supabase.auth.currentSession;
    _user = session?.user;
    _isLoading = false;
    notifyListeners();

    if (_user != null) {
      await checkSubscription();
    }
  }

  /// Check if the user has an active subscription.
  /// Calls the existing Next.js API endpoint.
  Future<void> checkSubscription() async {
    try {
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
