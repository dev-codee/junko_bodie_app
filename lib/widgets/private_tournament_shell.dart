import 'package:flutter/material.dart';
import 'package:junko_bodie/services/api_service.dart';

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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF102E24),
    appBar: AppBar(
      title: Text(title),
      leading: IconButton(
        tooltip: 'Back',
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: children,
          ),
        ),
      ),
    ),
  );
}

String privateTournamentError(Object error) {
  // Keep server-provided product messages; hide network implementation details.
  if (error is ApiException && error.statusCode != null) return error.message;
  if (error is FormatException) return error.message;
  return 'Unable to connect. Please try again.';
}
