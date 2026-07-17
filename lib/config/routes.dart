/// App routing configuration using go_router.
///
/// Maps closely to the Next.js App Router page structure.
/// Auth guards redirect unauthenticated users to login.
library;

import 'package:flutter/foundation.dart';
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
import 'package:junko_bodie/screens/strategies_screen.dart';
import 'package:junko_bodie/screens/strategy_builder_screen.dart';

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
    debugLogDiagnostics: kDebugMode,
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
        path: '/strategies',
        name: 'strategies',
        builder: (context, state) => const StrategiesScreen(),
      ),
      GoRoute(
        path: '/strategies/build',
        name: 'strategies_build',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'];
          return StrategyBuilderScreen(strategyId: id);
        },
      ),
      GoRoute(
        path: '/season',
        name: 'season',
        builder: (context, state) => const SeasonScreen(),
      ),
      GoRoute(
        path: '/subscribe',
        name: 'subscribe',
        redirect: (_, __) => '/lobby',
      ),
      GoRoute(
        path: '/account/billing',
        name: 'billing',
        redirect: (_, __) => '/lobby',
      ),
    ],
  );
}
