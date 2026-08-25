/// Root MaterialApp widget.
///
/// Sets up the theme, Provider, and go_router.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/config/theme.dart';
import 'package:junko_bodie/config/routes.dart';
import 'package:junko_bodie/providers/auth_provider.dart';
import 'package:junko_bodie/providers/game_provider.dart';
import 'package:junko_bodie/providers/tournament_provider.dart';
import 'package:junko_bodie/widgets/age_gate.dart';
import 'package:junko_bodie/tour/tour_controller.dart';
import 'package:junko_bodie/tour/tour_overlay.dart';

class JunkoBodieApp extends StatelessWidget {
  const JunkoBodieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => TournamentProvider()),
        ChangeNotifierProvider(create: (_) => TourController()..init()),
      ],
      child: const _AppWithRouter(),
    );
  }
}

class _AppWithRouter extends StatefulWidget {
  const _AppWithRouter();

  @override
  State<_AppWithRouter> createState() => _AppWithRouterState();
}

class _AppWithRouterState extends State<_AppWithRouter> {
  bool _ageGateChecked = false;
  GoRouter? _router;
  bool _tourHooksWired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ageGateChecked) {
      _ageGateChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showAgeGateIfNeeded(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final router = buildRouter(
      isAuthenticated: auth.isAuthenticated,
      hasSubscription: auth.hasSubscription,
      isLoading: auth.isLoading,
      needsPasswordReset: auth.needsPasswordReset,
    );
    _router = router;

    // Wire the tour controller to go_router for cross-screen navigation and
    // current-route awareness (done once; closures read the latest _router).
    if (!_tourHooksWired) {
      _tourHooksWired = true;
      final tour = context.read<TourController>();
      tour.navigator = (route) => _router?.go(route);
      tour.routeGetter =
          () => _router?.routerDelegate.currentConfiguration.uri.path ?? '';
    }

    return MaterialApp.router(
      title: 'Junko Bodie Roulette Tournament',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const TourOverlay(),
          ],
        );
      },
    );
  }
}

