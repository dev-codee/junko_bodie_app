/// Root MaterialApp widget.
///
/// Sets up the theme, Provider, and go_router.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/config/theme.dart';
import 'package:junko_bodie/config/routes.dart';
import 'package:junko_bodie/providers/auth_provider.dart';
import 'package:junko_bodie/providers/game_provider.dart';
import 'package:junko_bodie/providers/tournament_provider.dart';
import 'package:junko_bodie/widgets/age_gate.dart';

class JunkoBodieApp extends StatelessWidget {
  const JunkoBodieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => TournamentProvider()),
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
    );

    return MaterialApp.router(
      title: 'Junko Bodie Roulette Tournament',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}

