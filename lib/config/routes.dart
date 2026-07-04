/// App routing configuration using go_router.
///
/// Maps closely to the Next.js App Router page structure.
/// Auth guards redirect unauthenticated users to login.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:junko_bodie/screens/landing_screen.dart';
import 'package:junko_bodie/screens/login_screen.dart';
import 'package:junko_bodie/screens/lobby_screen.dart';
import 'package:junko_bodie/screens/game_screen.dart';
import 'package:junko_bodie/screens/profile_screen.dart';
import 'package:junko_bodie/screens/rankings_screen.dart';
import 'package:junko_bodie/screens/season_screen.dart';
import 'package:junko_bodie/screens/tournament_list_screen.dart';
import 'package:junko_bodie/screens/tournament_game_screen.dart';
import 'package:junko_bodie/screens/session_history_screen.dart';

/// Creates the app router.
///
/// [isAuthenticated] and [hasSubscription] are passed from the auth provider
/// so the router can redirect based on auth state.
GoRouter buildRouter({
  required bool isAuthenticated,
  required bool hasSubscription,
  required bool isLoading,
}) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // While loading auth, don't redirect anywhere
      if (isLoading) return null;

      final isOnLanding = state.uri.path == '/';
      final isOnLogin = state.uri.path == '/login';
      final isOnSubscribe = state.uri.path == '/subscribe';

      // Not logged in → can only be on landing or login
      if (!isAuthenticated) {
        if (isOnLanding || isOnLogin) return null;
        return '/login';
      }

      // ⚠️ TEMPORARY: subscription paywall disabled.
      // Original code intentionally preserved below (commented) so we can
      // re-enable it once the Stripe flow is wired into Flutter.
      //
      // if (!hasSubscription) {
      //   if (isOnSubscribe ||
      //       state.uri.path == '/account/billing' ||
      //       isOnLanding) {
      //     return null;
      //   }
      //   return '/subscribe';
      // }

      // Logged in → redirect away from landing/login straight into the lobby
      if (isOnLanding || isOnLogin) return '/lobby';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/lobby',
        name: 'lobby',
        builder: (context, state) => const LobbyScreen(),
      ),
      // Placeholder routes — screens will be built in later phases
      GoRoute(
        path: '/game',
        name: 'game',
        builder: (context, state) => const GameScreen(),
      ),
      GoRoute(
        path: '/tournament',
        name: 'tournament',
        builder: (context, state) => const TournamentListScreen(),
      ),
      GoRoute(
        path: '/tournament/:id',
        name: 'tournament_game',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return TournamentGameScreen(tournamentId: id);
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/rankings',
        name: 'rankings',
        builder: (context, state) => const RankingsScreen(),
      ),
      GoRoute(
        path: '/session-history',
        name: 'session_history',
        builder: (context, state) => const SessionHistoryScreen(),
      ),
      GoRoute(
        path: '/season',
        name: 'season',
        builder: (context, state) => const SeasonScreen(),
      ),
      GoRoute(
        path: '/subscribe',
        name: 'subscribe',
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Subscribe'),
      ),
      GoRoute(
        path: '/account/billing',
        name: 'billing',
        builder: (context, state) => const _PlaceholderScreen(title: 'Billing'),
      ),
    ],
  );
}

/// Temporary placeholder for screens not yet built.
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 48, color: Color(0xFFC9A84C)),
            const SizedBox(height: 16),
            Text(
              '$title — Coming Soon',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF5F5F5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This screen will be built in a later phase.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
