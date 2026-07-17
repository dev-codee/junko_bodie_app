import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/providers/tournament_provider.dart';
import 'package:junko_bodie/models/tournament.dart';
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

  // Round-transition overlays (mirror the web's "Match Found" + "Round N
  // Starting" full-screen moments shown at each round boundary).
  int _lastRound = 1;
  bool _matchStartShown = false;
  bool _showMatchStart = false;
  bool _showRoundStart = false;
  int _roundStartNumber = 1;
  Timer? _matchStartTimer;
  Timer? _roundStartTimer;

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
    
    _matchStartTimer?.cancel();
    _roundStartTimer?.cancel();

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

        // Detect round boundaries to show the match-found / round-starting
        // transition overlays (mirrors the web tournament flow).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeTriggerRoundOverlays(provider);
        });

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
          final int num = int.tryParse(provider.lastSpinResult['number']?.toString() ?? '') ?? 0;
          resultModel = SpinResult(
            id: provider.lastSpinResult['id']?.toString() ?? '',
            number: num,
            displayNumber: provider.lastSpinResult['displayNumber']?.toString() ?? RNG.getDisplayNumber(num),
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
        // Identify if tournament completed
        final isCompleted = provider.phase == 'completed' || provider.tournament?.status == 'completed';
        
        final bool isSpinning = provider.phase == 'spinning';

        // Show the elimination screen persistently once I'm out (not just during
        // the transient 'elimination' phase) so a mid-tournament elimination
        // doesn't flash and drop me back onto the board.
        // However, if the tournament is completed, we hide this overlay so the
        // Summary (TournamentWinnerOverlay) can be shown instead.
        final showElimOverlay = isMeEliminated && !isCompleted;

        return Scaffold(
          backgroundColor: const Color(0xFF050B08),
          endDrawer: Drawer(
            width: 250.0,
            backgroundColor: const Color(0xFF050B08),
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: TournamentScoresSidebar(
                    scores: provider.scores,
                    myPlayerId: mePlayer?.playerId,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TournamentEventsFeed(
                    events: provider.events,
                  ),
                ),
              ],
            ),
          ),
          body: Stack(
            children: [
              // 1. Main Gameplay Felt Table
              AnimatedPadding(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: isSpinning
                    ? EdgeInsets.zero
                    : const EdgeInsets.only(top: 48, bottom: 58),
                child: Padding(
                  padding: isSpinning
                      ? EdgeInsets.zero
                      : const EdgeInsets.only(left: 0.0, right: 5.0),
                  child: LayoutBuilder(
                    builder: (context, tableConstraints) {
                      final double tableWidth = math.max(tableConstraints.maxWidth, 850.0);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: const TournamentRouletteTable(),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 2. Top Header Bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                top: isSpinning ? -48 : 0,
                left: 0,
                right: 0,
                child: _buildHeader(provider),
              ),

              // 3. Bottom footer
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                bottom: isSpinning ? -68 : 0,
                left: 0,
                right: 0,
                child: _buildFooter(provider, canBet, balance, totalBet, mePlayer),
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
                visible: isCompleted,
                onExit: () {
                  provider.stopPolling();
                  context.go('/lobby');
                },
              ),

              // 8. Funds Error Toast display
              if (provider.fundError != null)
                _buildToast(provider),

              // 9. Round-transition overlays (top-most)
              if (_showMatchStart)
                _buildMatchFoundOverlay(provider),
              if (_showRoundStart)
                _buildRoundStartOverlay(provider),
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
          colors: [Color(0xFF4A2F1F), Color(0xFF26170F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFFC9A44C), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.only(left: 16, right: 36),
      child: Row(
        children: [
          // Lobby exit button
          TextButton.icon(
            onPressed: () {
              soundEngine.playClick();
              provider.stopPolling();
              context.go('/lobby');
            },
            icon: const Icon(Icons.chevron_left, color: Color(0xFFC9A44C), size: 16),
            label: const Text(
              'LOBBY',
              style: TextStyle(
                color: Color(0xFFC9A44C),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
              backgroundColor: const Color(0xFFC9A44C).withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(width: 16),

          // Horizontal spin history row
          Expanded(
            child: _SpinHistoryList(history: provider.history),
          ),

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
          const SizedBox(width: 8),

          // Scoreboard Button
          Builder(
            builder: (ctx) => IconButton(
              onPressed: () {
                soundEngine.playClick();
                Scaffold.of(ctx).openEndDrawer();
              },
              icon: const Icon(Icons.menu, color: Color(0xFFF5EDD5), size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 12),

          // Round / Spin indicator (matches the web header, far right)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'ROUND ${provider.currentRound} OF 5',
                style: const TextStyle(
                  color: Color(0xFFC9A44C),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                'SPIN ${provider.currentSpin}/5',
                style: TextStyle(
                  color: const Color(0xFFF5EDD5).withOpacity(0.6),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer bar ─────────────────────────────────────────────────────────
  // Web-style layout: chip tray on the left, player card centered, betting
  // controls + total-bet / balance pills on the right.
  Widget _buildFooter(
    TournamentProvider provider,
    bool canBet,
    double balance,
    double totalBet,
    TournamentPlayer? mePlayer,
  ) {
    final bool hasBets = provider.bets.isNotEmpty;
    final bool canRebet = canBet && provider.lastSpinBets.isNotEmpty;

    return Container(
      height: 58,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A2F1F), Color(0xFF26170F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          top: BorderSide(color: Color(0xFFC9A44C), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: Row(
        children: [
          // Left: chip tray
          Expanded(
            flex: 6,
            child: ChipTray(
              selectedChip: provider.selectedChip,
              onSelectChip: provider.selectChip,
              balance: balance,
              totalBet: totalBet,
              disabled: !canBet,
              chipSize: 30,
            ),
          ),
          const SizedBox(width: 8),

          // Center: player card
          _buildPlayerCard(mePlayer, balance),
          const SizedBox(width: 8),

          // Right: total bet, controls, balance
          Expanded(
            flex: 5,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _footerPill('TOTAL BET', '\$${totalBet.toStringAsFixed(0)}'),
                    const SizedBox(width: 8),
                    _footerButton('REBET', canRebet, provider.rebet),
                    const SizedBox(width: 6),
                    _footerButton('UNDO', canBet && hasBets, provider.undo),
                    const SizedBox(width: 6),
                    _footerButton('CLEAR', canBet && hasBets, provider.clearBets),
                    const SizedBox(width: 6),
                    _footerButton('2X', canBet && hasBets, provider.doubleAllBets),
                    const SizedBox(width: 6),
                    _footerDeleteButton(canBet, provider.deleteMode, provider.toggleDeleteMode),
                    const SizedBox(width: 8),
                    _footerPill('BALANCE', '\$${balance.toStringAsFixed(0)}'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerPill(String label, String value) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFC9A44C).withOpacity(0.1),
        border: Border.all(color: const Color(0xFFC9A44C).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 7.5,
              letterSpacing: 0.6,
              color: Color(0xFFC9A44C),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerButton(String label, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 38,
        constraints: const BoxConstraints(minWidth: 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFF3A4A3E), Color(0xFF2A3A2E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: enabled ? null : const Color(0x33141414),
          border: Border.all(
            color: enabled ? const Color(0xFFC9A44C) : Colors.white10,
            width: 1.6,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.white24,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  // Delete-mode toggle (✕). Turns red while active; tapping a placed bet on the
  // felt then removes that zone's chips.
  Widget _footerDeleteButton(bool enabled, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          gradient: !enabled
              ? null
              : active
                  ? const LinearGradient(
                      colors: [Color(0xFF3A1515), Color(0xFF2A0808)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF2A3A2E), Color(0xFF1A2A1E)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
          color: enabled ? null : const Color(0x33141414),
          border: Border.all(
            color: !enabled
                ? Colors.white10
                : active
                    ? const Color(0xFFF87171)
                    : const Color(0xFFC9A44C),
            width: 1.6,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.close,
          size: 16,
          color: !enabled
              ? Colors.white24
              : active
                  ? const Color(0xFFF87171)
                  : const Color(0xFFE4E0D4),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(TournamentPlayer? mePlayer, double balance) {
    final String name = mePlayer?.username ?? 'Player';
    final String avatar = mePlayer?.avatarUrl ?? '';
    final bool isNetwork = avatar.startsWith('http') || avatar.startsWith('/');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C3B27), Color(0xFF3D271A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFC9A44C).withOpacity(0.5), width: 1.5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
              border: Border.all(color: const Color(0xFFC9A44C), width: 1.5),
            ),
            child: ClipOval(
              child: isNetwork
                  ? Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, color: Color(0xFFC9A44C), size: 18),
                    )
                  : const Icon(Icons.person, color: Color(0xFFC9A44C), size: 18),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  height: 1.1,
                ),
              ),
              Text(
                'TOURNAMENT PRO',
                style: GoogleFonts.inter(
                  color: const Color(0xFFC9A44C),
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Round-transition overlays ─────────────────────────────────────────────
  int _activePlayerCount(TournamentProvider provider) {
    final players = provider.tournament?.players;
    if (players == null) return 0;
    return players.where((p) => p.status == 'active').length;
  }

  void _maybeTriggerRoundOverlays(TournamentProvider provider) {
    if (provider.tournament?.status != 'active') return;

    // Match Found — shown once at the very start (round 1, spin 1).
    if (!_matchStartShown &&
        provider.currentRound == 1 &&
        provider.currentSpin == 1) {
      _matchStartShown = true;
      _lastRound = 1;
      soundEngine.announceMatchFound();
      setState(() => _showMatchStart = true);
      _matchStartTimer?.cancel();
      _matchStartTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _showMatchStart = false);
      });
      return;
    }

    // Round Starting — shown when a new round begins (rounds 2..5).
    if (provider.phase == 'betting' &&
        provider.currentRound > 1 &&
        provider.currentSpin == 1 &&
        _lastRound != provider.currentRound) {
      _lastRound = provider.currentRound;
      setState(() {
        _showRoundStart = true;
        _roundStartNumber = provider.currentRound;
      });
      _roundStartTimer?.cancel();
      _roundStartTimer = Timer(const Duration(milliseconds: 3000), () {
        if (mounted) setState(() => _showRoundStart = false);
      });
    }
  }

  Widget _buildMatchFoundOverlay(TournamentProvider provider) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [Color(0xFF247A5E), Color(0xFF0A1E14)],
          ),
        ),
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MATCHMAKING COMPLETE',
                style: GoogleFonts.inter(
                  color: const Color(0xFFC9A44C),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'MATCH FOUND!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1,
                  shadows: [
                    Shadow(color: Color(0x99C9A44C), blurRadius: 40),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 2,
                width: 220,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xFFC9A44C), Colors.transparent],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'ROUND 1 STARTING',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundStartOverlay(TournamentProvider provider) {
    final int remaining = _activePlayerCount(provider);
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [Color(0xF20D2A20), Color(0xFA050D0A)],
          ),
        ),
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.7, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TOURNAMENT PROGRESS',
                style: GoogleFonts.inter(
                  color: const Color(0xFFC9A44C),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'ROUND $_roundStartNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 60,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1,
                  shadows: [
                    Shadow(color: Color(0x99C9A44C), blurRadius: 40),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 3,
                width: 240,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xFFC9A44C), Colors.transparent],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'ACTIVE & PREPARED',
                style: GoogleFonts.inter(
                  color: const Color(0xFF4ADE80),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$remaining Players Remaining',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
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
        itemCount: math.min(history.length, 15),
        itemBuilder: (context, index) {
          final spin = history[index];
          final String numStr = spin['displayNumber']?.toString() ??
              (spin['number'] != null
                  ? RNG.getDisplayNumber(int.tryParse(spin['number'].toString()) ?? 0)
                  : '0');
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
