import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:junko_bodie/models/tournament.dart';
import 'package:junko_bodie/widgets/private_tournament_shell.dart';

class PrivateTournamentResults extends StatelessWidget {
  final Tournament tournament;
  const PrivateTournamentResults({super.key, required this.tournament});
  @override
  Widget build(BuildContext context) {
    final complete = tournament.status == 'completed';
    final players = [...tournament.players]
      ..sort((a, b) {
        final rank = (a.finalPosition ?? 1).compareTo(b.finalPosition ?? 1);
        return rank != 0 ? rank : b.currentChips.compareTo(a.currentChips);
      });
    final winners = players.where((p) => p.playerId == tournament.winnerId);
    return PrivateTournamentShell(
      title: complete ? 'Private results' : 'Private standings',
      onBack: () => context.go('/tournament/private'),
      children: [
        Text(
          complete
              ? '${winners.isEmpty ? 'Your friend' : winners.first.username} wins!'
              : 'Your tournament standings',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          complete
              ? 'Thanks for playing together.'
              : 'Your friends are still playing. These standings update until the match finishes.',
        ),
        const Text(
          'Private matches do not award public championship points or badges.',
        ),
        const SizedBox(height: 16),
        for (final p in players)
          ListTile(
            title: Text(p.username),
            subtitle: p.forfeitedAt != null
                ? const Text('Left tournament')
                : null,
            leading: Text(
              p.finalPosition != null
                  ? '#${p.finalPosition}'
                  : complete
                  ? '#1'
                  : 'Playing',
            ),
            trailing: Text(
              '${p.currentChips.clamp(0, double.infinity).toStringAsFixed(0)} chips',
            ),
          ),
        FilledButton(
          onPressed: () => context.go('/tournament/private'),
          child: const Text('Play with Friends'),
        ),
      ],
    );
  }
}
