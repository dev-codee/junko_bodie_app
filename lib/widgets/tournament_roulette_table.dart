import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/logic/bets.dart';
import 'package:junko_bodie/logic/rng.dart' as rng;
import 'package:junko_bodie/providers/tournament_provider.dart';
import 'package:junko_bodie/widgets/betting_layout.dart';
import 'package:junko_bodie/widgets/roulette_wheel.dart';

class TournamentRouletteTable extends StatelessWidget {
  const TournamentRouletteTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TournamentProvider>(
      builder: (context, provider, child) {
        final bool canBet = provider.phase == 'betting';
        final bool isLocked = provider.phase == 'locked';
        final bool isSpinning = provider.phase == 'spinning';
        final bool isResult = provider.phase == 'result';

        final bool hasBets = provider.bets.isNotEmpty;

        // Build combined bets map for visual display (my bets + bot bets)
        final mergedBets = <String, PlacedBet>{};
        
        // Add human player bets
        provider.bets.forEach((betId, b) {
          mergedBets[betId] = PlacedBet(
            betId: betId,
            amount: b.amount,
            chips: b.chips,
            customColor: '#c9a44c',
            playerInitial: 'Me',
          );
        });

        // Add bot wagers
        for (var bb in provider.botBets) {
          final String betId = bb['betId'] ?? '';
          final double amount = (bb['amount'] ?? 0.0).toDouble();
          final List<double> chips = (bb['chips'] as List<dynamic>?)?.map((c) => (c as num).toDouble()).toList() ?? [amount];
          final String username = bb['username'] ?? 'Bot';

          final playerInfo = _scoreByUsername(provider.scores, username);
          final String colorHex = (playerInfo != null && playerInfo['color'] != null)
              ? playerInfo['color'].toString()
              : '#ffffff';

          final existing = mergedBets[betId];
          if (existing != null) {
            mergedBets[betId] = PlacedBet(
              betId: betId,
              amount: existing.amount + amount,
              chips: [...existing.chips, ...chips],
              customColor: colorHex,
              playerInitial: username.substring(0, math.min(2, username.length)),
            );
          } else {
            mergedBets[betId] = PlacedBet(
              betId: betId,
              amount: amount,
              chips: chips,
              customColor: colorHex,
              playerInitial: username.substring(0, math.min(2, username.length)),
            );
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final double height = constraints.maxHeight;
            final double width = constraints.maxWidth;

            // Enforce landscape proportions
            final double wheelSize = (height * 0.72).clamp(180.0, 300.0);

            // Wheel Type mapping
            final wheelTypeEnum = provider.wheelType == 'american'
                ? rng.WheelType.american
                : rng.WheelType.european;

            // Mapping spin results
            rng.SpinResult? currentSpinResult;
            if (provider.lastSpinResult != null) {
              final int num = provider.lastSpinResult['number'] ?? 0;
              currentSpinResult = rng.SpinResult(
                id: provider.lastSpinResult['id']?.toString() ?? '',
                number: num,
                displayNumber: rng.RNG.getDisplayNumber(num),
                color: rng.RNG.getNumberColor(num),
                parity: rng.RNG.getParity(num),
                dozen: rng.RNG.getDozen(num),
                column: rng.RNG.getColumn(num),
                half: rng.RNG.getHalf(num),
              );
            }

            return Container(
              width: width,
              height: height,
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                border: Border.all(color: const Color(0xFF050505), width: 6),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.04),
                    blurRadius: 1,
                    spreadRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                  const BoxShadow(
                    color: Colors.black,
                    blurRadius: 30,
                    offset: Offset(0, 15),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Gold Border Frame
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFC9A84C).withOpacity(0.2),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),

                  // Green Felt Area
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const RadialGradient(
                            center: Alignment.center,
                            radius: 0.8,
                            colors: [Color(0xFF143D30), Color(0xFF081A15)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            // 1. Wheel Section (Left)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOutCubic,
                              alignment: Alignment.center,
                              width: isSpinning ? wheelSize * 1.15 : wheelSize,
                              child: RouletteWheel(
                                wheelType: wheelTypeEnum,
                                spinResult: currentSpinResult,
                                isSpinning: isSpinning,
                                onSpinComplete: () {
                                  provider.completeSpin();
                                },
                                size: isSpinning ? wheelSize * 1.15 : wheelSize,
                                tournamentMode: true,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // 2. Felt Betting Section (Right)
                            Expanded(
                              child: Column(
                                children: [
                                  // Top row Title
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ShaderMask(
                                            shaderCallback: (bounds) => const LinearGradient(
                                              colors: [Color(0xFFF5EDD5), Color(0xFFC9A44C)],
                                            ).createShader(bounds),
                                            child: const Text(
                                              'ROULETTE TOURNAMENT',
                                              style: TextStyle(
                                                fontFamily: 'Georgia',
                                                fontSize: 14,
                                                fontStyle: FontStyle.italic,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            'ROUND ${provider.currentRound} | SPIN ${provider.currentSpin}/5',
                                            style: TextStyle(
                                              color: const Color(0xFFC9A84C).withOpacity(0.5),
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Betting layout grid with closed overlay
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        // Betting Layout
                                        Positioned.fill(
                                          child: AnimatedOpacity(
                                            duration: const Duration(milliseconds: 300),
                                            opacity: isSpinning ? 0.3 : 1.0,
                                            child: IgnorePointer(
                                              ignoring: !canBet,
                                              child: BettingLayout(
                                                bets: mergedBets,
                                                onPlaceBet: provider.placeBet,
                                                onRemoveBet: provider.removeBet,
                                                disabled: !canBet,
                                                winningResult: currentSpinResult,
                                                showWinHighlight: isResult,
                                                phase: provider.phase,
                                                deleteMode: provider.deleteMode,
                                                wheelType: wheelTypeEnum,
                                                myBets: provider.bets,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // BETS CLOSED overlay
                                        if (isLocked || isSpinning)
                                          Positioned.fill(
                                            child: Center(
                                              child: Transform.rotate(
                                                angle: -5.0 * math.pi / 180.0,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.85),
                                                    border: Border.all(color: const Color(0xFFC9A44C), width: 3),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Text(
                                                        'BETS LOCKED',
                                                        style: TextStyle(
                                                          fontFamily: 'Georgia',
                                                          color: Colors.white,
                                                          fontSize: 20,
                                                          fontWeight: FontWeight.w900,
                                                          fontStyle: FontStyle.italic,
                                                          letterSpacing: 2,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Container(
                                                        height: 1.5,
                                                        width: 100,
                                                        decoration: const BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [Colors.transparent, Color(0xFFC9A44C), Colors.transparent],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'AWAITING SERVER SPIN...',
                                                        style: GoogleFonts.inter(
                                                          color: const Color(0xFFC9A84C),
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.bold,
                                                          letterSpacing: 2.0,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Action Controls
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (canBet && hasBets) ...[
                                        _CasinoButton(
                                          label: '2X',
                                          onTap: provider.doubleAllBets,
                                          enabled: canBet,
                                        ),
                                        const SizedBox(width: 8),
                                        _CasinoButton(
                                          label: 'UNDO',
                                          onTap: provider.undo,
                                          enabled: canBet,
                                        ),
                                        const SizedBox(width: 8),
                                        _CasinoButton(
                                          label: 'CLEAR',
                                          onTap: provider.clearBets,
                                          enabled: canBet,
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      if (canBet && !hasBets && provider.lastSpinBets.isNotEmpty) ...[
                                        _CasinoButton(
                                          label: 'REBET',
                                          onTap: provider.rebet,
                                          enabled: canBet,
                                        ),
                                        const SizedBox(width: 12),
                                      ],

                                      // Submit/Lock Button
                                      GestureDetector(
                                        onTap: () {
                                          if (canBet && hasBets) {
                                            provider.submitBets(provider.bets);
                                          }
                                        },
                                        child: Container(
                                          height: 30,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          decoration: BoxDecoration(
                                            gradient: canBet && hasBets
                                                ? const LinearGradient(colors: [Color(0xFFE5C060), Color(0xFFC9A44C)])
                                                : const LinearGradient(colors: [Color(0xFF1E3A2F), Color(0xFF10261E)]),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: canBet && hasBets ? const Color(0xFFC9A44C) : Colors.white10,
                                              width: 1,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'LOCK BETS',
                                            style: TextStyle(
                                              color: canBet && hasBets ? const Color(0xFF07140E) : Colors.white24,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CasinoButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _CasinoButton({
    required this.label,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF163C30) : const Color(0xFF0F2B22),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: enabled ? const Color(0x60C9A44C) : Colors.white10,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? const Color(0xFFC9A44C) : Colors.white10,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// Find a score entry by username in a loosely-typed scores list, returning
/// null when not found. Avoids `firstWhere(..., orElse: () => null)` which
/// trips Dart 3's strict type inference on non-nullable element types.
Map<String, dynamic>? _scoreByUsername(List<dynamic> scores, String username) {
  for (final s in scores) {
    if (s is Map && s['username'] == username) {
      return Map<String, dynamic>.from(s);
    }
  }
  return null;
}
