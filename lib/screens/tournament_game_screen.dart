import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/providers/tournament_provider.dart';
import 'package:junko_bodie/widgets/tournament_roulette_table.dart';
import 'package:junko_bodie/widgets/tournament_scores_sidebar.dart';
import 'package:junko_bodie/widgets/tournament_events_feed.dart';
import 'package:junko_bodie/widgets/tournament_elimination_overlay.dart';
import 'package:junko_bodie/widgets/tournament_winner_overlay.dart';
import 'package:junko_bodie/widgets/result_display.dart';
import 'package:junko_bodie/widgets/win_celebration.dart';
import 'package:junko_bodie/widgets/chip_tray.dart';
import 'package:junko_bodie/widgets/settings_modal.dart';
import 'package:junko_bodie/audio/audio_engine.dart';
import 'package:junko_bodie/logic/rng.dart';
import 'package:junko_bodie/logic/payouts.dart';

class TournamentGameScreen extends StatefulWidget {
  final String tournamentId;

  const TournamentGameScreen({
    super.key,
    required this.tournamentId,
  });

  @override
  State<TournamentGameScreen> createState() => _TournamentGameScreenState();
}

class _TournamentGameScreenState extends State<TournamentGameScreen> {
  bool _showResult = false;
  bool _showWinCelebration = false;

  @override
  void initState() {
    super.initState();
    // Force Landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Set immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Initial load and start polling. ensurePolling is idempotent so it's safe
    // to call even when matchmaking already started the loop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TournamentProvider>(context, listen: false);
      provider.loadTournament(tourneyId: widget.tournamentId);
      provider.ensurePolling(widget.tournamentId);
    });

    soundEngine.playTourneyBackgroundMusic();
  }

  @override
  void dispose() {
    // Restore default portrait/landscape orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Restore default system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    
    // Stop polling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TournamentProvider>(context, listen: false);
      provider.stopPolling();
    });

    soundEngine.stopTourneyBackgroundMusic();
    super.dispose();
  }

  void _handleDismissResult(TournamentProvider provider) {
    setState(() {
      _showResult = false;
      _showWinCelebration = false;
    });
    provider.dismissResult();
  }

  void _showResultPopup(TournamentProvider provider) {
    if (provider.lastPlayerPayout != null) {
      setState(() {
        _showResult = true;
        final double net = (provider.lastPlayerPayout['netResult'] ?? 0.0).toDouble();
        if (net > 0) {
          _showWinCelebration = true;
        }
      });
    } else {
      provider.dismissResult();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TournamentProvider>(
      builder: (context, provider, child) {
        // Handle result popups
        final isResultPhase = provider.phase == 'result';
        if (isResultPhase && !_showResult && provider.lastSpinResult != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showResultPopup(provider);
          });
        }

        // Handle loading
        if (provider.isLoading && provider.tournament == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF07140E),
            body: Center(
              child: Text(
                'LOADING ARENA...',
                style: TextStyle(
                  color: Color(0xFFC9A44C),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ),
          );
        }

        final bool canBet = provider.phase == 'betting';
        
        final mePlayer = provider.me;
        final double balance = (mePlayer?.currentChips ?? 0.0).toDouble();
        final double totalBet = provider.totalBet;

        // Custom model mapper for ResultDisplay compatibility
        SpinResult? resultModel;
        if (provider.lastSpinResult != null) {
          final int num = provider.lastSpinResult['number'] ?? 0;
          resultModel = SpinResult(
            id: provider.lastSpinResult['id']?.toString() ?? '',
            number: num,
            displayNumber: RNG.getDisplayNumber(num),
            color: RNG.getNumberColor(num),
            parity: RNG.getParity(num),
            dozen: RNG.getDozen(num),
            column: RNG.getColumn(num),
            half: RNG.getHalf(num),
          );
        }

        PayoutResult? payoutModel;
        if (provider.lastPlayerPayout != null) {
          final double net = (provider.lastPlayerPayout['netResult'] ?? 0.0).toDouble();
          final double wagered = (provider.lastPlayerPayout['totalWagered'] ?? 0.0).toDouble();
          final double returned = (provider.lastPlayerPayout['totalReturned'] ?? 0.0).toDouble();
          payoutModel = PayoutResult(
            netResult: net,
            totalWagered: wagered,
            totalWon: returned - wagered,
            totalReturned: returned,
            outcomes: const [],
          );
        }

        // Identify if me is eliminated
        final isMeEliminated = mePlayer != null && mePlayer.status == 'eliminated';
        final showElimOverlay = isMeEliminated && (provider.phase == 'elimination' || provider.tournament?.status == 'completed');

        // Identify if tournament completed
        final isCompleted = provider.phase == 'completed' || provider.tournament?.status == 'completed';

        return Scaffold(
          backgroundColor: const Color(0xFF050B08),
          body: Stack(
            children: [
              // Main gameplay container
              Column(
                children: [
                  // 1. Top Header
                  _buildHeader(provider),
                  
                  // 2. Middle area (Scores, Roulette, Events)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Standings Leaderboard Sidebar (Left)
                        TournamentScoresSidebar(
                          scores: provider.scores,
                          myPlayerId: mePlayer?.playerId,
                        ),

                        // Roulette Felt Table (Center)
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                            child: TournamentRouletteTable(),
                          ),
                        ),

                        // Events Feed Sidebar (Right)
                        TournamentEventsFeed(
                          events: provider.events,
                        ),
                      ],
                    ),
                  ),

                  // 3. Bottom ChipTray
                  ChipTray(
                    selectedChip: provider.selectedChip,
                    onSelectChip: provider.selectChip,
                    balance: balance,
                    totalBet: totalBet,
                    disabled: !canBet,
                  ),
                ],
              ),

              // 4. Result Display Overlay
              ResultDisplay(
                result: resultModel,
                payout: payoutModel,
                visible: _showResult,
                onDismiss: () => _handleDismissResult(provider),
              ),

              // 5. Confetti celebration
              WinCelebration(
                show: _showWinCelebration,
              ),

              // 6. Elimination screen overlay
              TournamentEliminationOverlay(
                player: _findScoreFor(provider.scores, mePlayer?.playerId.toString()),
                visible: showElimOverlay,
                onDismiss: () {
                  provider.stopPolling();
                  context.go('/lobby');
                },
              ),

              // 7. Tournament Winner overlay
              TournamentWinnerOverlay(
                tournament: provider.tournament?.toJson(),
                mePlayer: _findScoreFor(provider.scores, mePlayer?.playerId.toString()),
                visible: isCompleted && !isMeEliminated,
                onExit: () {
                  provider.stopPolling();
                  context.go('/lobby');
                },
              ),

              // 8. Funds Error Toast display
              if (provider.fundError != null)
                _buildToast(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(TournamentProvider provider) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F3220), Color(0xFF07140E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFFC9A44C), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Lobby exit button
          IconButton(
            onPressed: () {
              soundEngine.playClick();
              provider.stopPolling();
              context.go('/lobby');
            },
            icon: const Icon(Icons.arrow_back, color: Color(0xFFF5EDD5), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Exit Arena',
          ),
          const SizedBox(width: 16),

          // Horizontal spin history row
          Expanded(
            child: _SpinHistoryList(history: provider.history),
          ),

          // Timer display
          if (provider.phase == 'betting' || provider.phase == 'locked')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: provider.phase == 'locked' ? const Color(0xFF1E3A2F) : const Color(0xFFC9A44C),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer,
                    size: 11,
                    color: provider.phase == 'locked' ? Colors.white60 : const Color(0xFF07140E),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    provider.phase == 'locked' ? 'LOCKED' : '${provider.timeRemaining}s',
                    style: TextStyle(
                      color: provider.phase == 'locked' ? Colors.white : const Color(0xFF07140E),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 16),

          // Settings Button
          IconButton(
            onPressed: () {
              soundEngine.playClick();
              showDialog(
                context: context,
                builder: (context) => const SettingsModal(),
              );
            },
            icon: const Icon(Icons.settings, color: Color(0xFFF5EDD5), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildToast(TournamentProvider provider) {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red[900]?.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.redAccent, width: 1),
          ),
          child: Text(
            provider.fundError!,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _SpinHistoryList extends StatelessWidget {
  final List<dynamic> history;

  const _SpinHistoryList({required this.history});

  Color _getColor(String colorStr) {
    if (colorStr == 'red') return const Color(0xFFC0392B);
    if (colorStr == 'green') return const Color(0xFF267B4B);
    return const Color(0xFF1A1A1A);
  }

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Text(
        'NO SPINS YET',
        style: GoogleFonts.inter(
          color: const Color(0xFFE4E0D4).withOpacity(0.4),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      );
    }

    return SizedBox(
      height: 24,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: math.min(history.length, 6),
        itemBuilder: (context, index) {
          final spin = history[index];
          final String numStr = spin['number']?.toString() ?? spin['displayNumber']?.toString() ?? '0';
          final String colorStr = spin['color'] ?? 'green';
          final displayColor = _getColor(colorStr);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: displayColor,
              border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.5), width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              numStr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Find the score entry for a given player id in the (loosely-typed) scores list.
///
/// Returns `null` if not found. Avoids `firstWhere(..., orElse: () => null)`
/// which trips Dart's strict type inference on the dynamic list.
Map<String, dynamic>? _findScoreFor(List<dynamic> scores, String? playerId) {
  if (playerId == null) return null;
  for (final s in scores) {
    if (s is Map && s['player_id']?.toString() == playerId) {
      return Map<String, dynamic>.from(s);
    }
  }
  return null;
}
