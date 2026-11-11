import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:junko_bodie/services/api_service.dart';

const privateGreen = Color(0xFF0F2318);
const privateGold = Color(0xFFC9A44C);
const privateCream = Color(0xFFF5EDD5);

class PrivateTournamentShell extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback onBack;
  const PrivateTournamentShell({
    super.key,
    required this.title,
    required this.children,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: const ColorScheme.light(
          primary: privateGreen,
          onPrimary: privateCream,
          secondary: privateGold,
          surface: privateCream,
          onSurface: privateGreen,
          error: Color(0xFF8B2920),
        ),
        textTheme: theme.textTheme.apply(
          bodyColor: privateGreen,
          displayColor: privateGreen,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: privateGold,
            foregroundColor: privateGreen,
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF605026),
            side: const BorderSide(color: Color(0xFFB69B5F)),
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: privateGreen),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: privateGreen,
          iconColor: Color(0xFF8B6914),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFFFFDF7),
          labelStyle: TextStyle(color: Color(0xFF79602A)),
          hintStyle: TextStyle(color: Color(0xFFABA48F)),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: privateGold),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFE8D9B8),
        appBar: AppBar(
          backgroundColor: privateGreen,
          foregroundColor: privateCream,
          title: Text(title, style: const TextStyle(fontSize: 17)),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 700 || constraints.maxHeight < 500;
              final outer = compact ? 12.0 : 24.0;
              return SingleChildScrollView(
                padding: EdgeInsets.all(outer),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, constraints.maxHeight - outer * 2),
                  ),
                  child: Center(
                    child: Container(
                      width: math.min(1100, constraints.maxWidth - outer * 2),
                      padding: EdgeInsets.all(compact ? 20 : 32),
                      decoration: BoxDecoration(
                        color: privateCream,
                        border: Border.all(color: privateGold, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26755019),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

String privateTournamentError(Object error) {
  if (error is ApiException && error.statusCode != null) return error.message;
  if (error is FormatException) return error.message;
  return 'Unable to connect. Please try again.';
}
