import 'package:flutter/material.dart';
import 'package:junko_bodie/models/tournament.dart';

class PrivateTournamentFinishOverlay extends StatelessWidget {
  final Tournament tournament;
  final String? currentPlayerId;
  final VoidCallback onContinue;
  const PrivateTournamentFinishOverlay({
    super.key,
    required this.tournament,
    this.currentPlayerId,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final winners = tournament.players.where(
      (p) => p.playerId == tournament.winnerId,
    );
    final winner = winners.isEmpty ? null : winners.first;
    final won =
        currentPlayerId != null && currentPlayerId == tournament.winnerId;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(dismissible: false, color: Color(0xD9020A08)),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 650),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: .94 + value * .06,
                    child: child,
                  ),
                ),
                child: Semantics(
                  namesRoute: true,
                  scopesRoute: true,
                  explicitChildNodes: true,
                  label: 'Private tournament complete',
                  child: Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        colors: [Color(0xFF254332), Color(0xFF0A1912)],
                        radius: 1.2,
                      ),
                      border: Border.all(color: const Color(0xFFC9A44C)),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'PRIVATE TOURNAMENT COMPLETE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFD8BD77),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontSize: 11,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Icon(
                            Icons.emoji_events_outlined,
                            size: 60,
                            color: Color(0xFFEFCC71),
                          ),
                        ),
                        Text(
                          won
                              ? 'You take the crown!'
                              : '${winner?.username ?? 'Your friend'} takes the crown!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFF7EFD9),
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                          ),
                        ),
                        if (winner != null)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '${winner.username} · ${winner.currentChips.clamp(0, double.infinity).toStringAsFixed(0)} final chips',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFDFC987)),
                            ),
                          ),
                        Text(
                          tournament.completionReason == 'forfeit'
                              ? 'Won by forfeit. The last remaining player wins.'
                              : 'The final spin is in. Thanks for bringing your friends to the table.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFC2CCBF)),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          autofocus: true,
                          onPressed: onContinue,
                          child: const Text('View final standings'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
