import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/config/theme.dart';
import 'package:junko_bodie/logic/rng.dart';
import 'package:junko_bodie/models/player.dart';
import 'package:junko_bodie/services/user_service.dart';
import 'package:junko_bodie/providers/game_provider.dart';
import 'package:junko_bodie/widgets/roulette_table.dart';
import 'package:junko_bodie/widgets/result_display.dart';
import 'package:junko_bodie/widgets/win_celebration.dart';
import 'package:junko_bodie/widgets/chip_tray.dart';
import 'package:junko_bodie/widgets/settings_modal.dart';
import 'package:junko_bodie/widgets/staged_betting_selector.dart';
import 'package:junko_bodie/widgets/strategy_prompt_modal.dart';
import 'package:junko_bodie/audio/audio_engine.dart';
import 'package:junko_bodie/logic/game_phases.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final UserService _userService = UserService();
  Player? _userProfile;
  bool _profileLoading = true;

  bool _showResult = false;
  bool _showWinCelebration = false;

  // Staged-betting (strategy) flow state.
  bool _awaitingStrategyChoice = false;
  bool _stagePopulated = false;

  GameProvider? _gameProvider; // captured for safe use in dispose()

  @override
  void initState() {
    super.initState();
    // Force Landscape orientation on screen load
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Set immersive mode for full screen casino felt
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Load user settings, profile, and initial game balance, then start the
    // session-history recording once the balance is known.
    _loadUserProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<GameProvider>();
      await provider.loadProfileBalance();
      await provider.startGameSession();
    });

    // Start background music
    soundEngine.playBackgroundMusic();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gameProvider = context.read<GameProvider>();
  }

  @override
  void dispose() {
    // Restore default portrait/landscape orientations on exit
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Restore default system UI overlay bars
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    // Finalize the session-history record (fire-and-forget).
    _gameProvider?.endGameSession();

    // Stop background music when leaving the game
    soundEngine.stopBackgroundMusic();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _userService.getProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _profileLoading = false;
        });
      }
    } catch (e) {
      debugPrint('GameScreen: Failed to load user profile: $e');
      if (mounted) {
        setState(() {
          _profileLoading = false;
        });
      }
    }
  }

  void _handleDismissResult(GameProvider provider) {
    // In strategy mode, pause on the result then prompt the player for the
    // next staged-betting action instead of immediately starting a new round.
    if (provider.stagedBettingEnabled && provider.activeStrategy != null) {
      setState(() {
        _showResult = false;
        _showWinCelebration = false;
        _awaitingStrategyChoice = true;
      });
      _showStrategyPrompt(provider);
      return;
    }

    setState(() {
      _showResult = false;
      _showWinCelebration = false;
    });
    provider.startNewRound();
  }

  void _showStrategyPrompt(GameProvider provider) {
    final strategy = provider.activeStrategy;
    if (strategy == null || strategy.stages.isEmpty) {
      _awaitingStrategyChoice = false;
      provider.startNewRound();
      return;
    }

    final int stageNumber = provider.currentStageIndex + 1;
    final bool isLast =
        provider.currentStageIndex >= strategy.stages.length - 1;

    void finish() {
      Navigator.of(context).pop();
      setState(() => _awaitingStrategyChoice = false);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => StrategyPromptModal(
        stageNumber: stageNumber,
        isLastStage: isLast,
        onReplayStage: () {
          soundEngine.playClick();
          finish();
          // Keep the same stage index to replay it.
          provider.startNewRound();
        },
        onGoToStage: (int stageIndex) {
          soundEngine.playClick();
          finish();
          provider.setCurrentStageIndex(
            stageIndex.clamp(0, strategy.stages.length - 1),
          );
          provider.startNewRound();
        },
        onNextStage: () {
          soundEngine.playClick();
          finish();
          final nextIdx = provider.currentStageIndex + 1;
          provider.setCurrentStageIndex(
            nextIdx >= strategy.stages.length ? 0 : nextIdx,
          );
          provider.startNewRound();
        },
        onExit: () {
          soundEngine.playClick();
          finish();
          provider.setStagedBettingEnabled(false);
          provider.setActiveStrategy(null);
          provider.setCurrentStageIndex(0);
          provider.startNewRound();
        },
      ),
    );
  }

  /// Auto-populate the current stage's bets each time we (re)enter the betting
  /// phase with an active strategy. Mirrors the web's auto-populate effect.
  void _maybeAutoPopulateStage(GameProvider provider) {
    if (provider.phase != GamePhase.betting) {
      _stagePopulated = false;
      return;
    }
    if (!provider.stagedBettingEnabled ||
        provider.activeStrategy == null ||
        _stagePopulated) {
      return;
    }
    _stagePopulated = true;
    final strategy = provider.activeStrategy!;
    if (provider.currentStageIndex < strategy.stages.length) {
      final stage = strategy.stages[provider.currentStageIndex];
      provider.applyStageBets(stage.bets);
    }
  }

  void _showResultPopup(GameProvider provider) {
    if (provider.lastPayout != null) {
      setState(() {
        _showResult = true;
        if (provider.lastPayout!.netResult > 0) {
          _showWinCelebration = true;
        }
      });
    } else {
      provider.startNewRound();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, provider, child) {
        // Automatically trigger results display when wheel stops spinning.
        // Suppressed while awaiting a strategy choice so the result popup does
        // not re-appear behind the strategy prompt.
        final isResultPhase = provider.phase == GamePhase.result;
        if (isResultPhase &&
            !_showResult &&
            !_awaitingStrategyChoice &&
            provider.currentResult != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showResultPopup(provider);
          });
        }

        // Auto-populate staged bets when entering the betting phase.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeAutoPopulateStage(provider);
        });

        // Show loading screen if fetching profile initially
        if (provider.loading && provider.balance == 0.0) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A1F1A),
            body: Center(
              child: Text(
                'LOADING CASINO...',
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

        final bool isSpinning = provider.phase == GamePhase.spinning;

        return Scaffold(
          backgroundColor: const Color(0xFF06140E),
          body: Stack(
            children: [
              // Main Layout Structure. While spinning we hide the header, footer
              // and player card and drop the felt padding, so the table (and its
              // centered wheel) fills the entire screen.
              Column(
                children: [
                  // 1. Top Header Bar (hidden during spin for the full-screen wheel)
                  if (!isSpinning) _buildHeader(provider),
                  // 2. Main Gameplay Felt Table
                  Expanded(
                    child: Padding(
                      padding: isSpinning
                          ? EdgeInsets.zero
                          : const EdgeInsets.only(
                              left: 0.0,
                              right: 5.0,
                            ),
                      child: const RouletteTable(
                        key: ValueKey('solo_roulette_table'),
                        tournamentMode: false,
                      ),
                    ),
                  ),
                  // 3. Footer Bar (hidden during spin)
                  if (!isSpinning) _buildFooter(provider, isSpinning),
                ],
              ),

              // 4. Floating Player Card — hidden while spinning.
              if (!isSpinning)
                Positioned(
                  bottom: 2.0,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 48.0),
                      child: _buildFloatingPlayerCard(),
                    ),
                  ),
                ),

              // 5. Result Display Blur Overlay
              ResultDisplay(
                result: provider.currentResult,
                payout: provider.lastPayout,
                visible: _showResult,
                onDismiss: () => _handleDismissResult(provider),
              ),

              // 6. Confetti Win Celebration
              WinCelebration(show: _showWinCelebration),

              // 7. Toast Funds Error Display
              if (provider.fundError != null) _buildToast(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(GameProvider provider) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A2F1F), Color(0xFF26170F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFFC9A44C), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Lobby Back Button
          IconButton(
            onPressed: () {
              soundEngine.playClick();
              context.go('/lobby');
            },
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFFF5EDD5),
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Lobby',
          ),
          const SizedBox(width: 16),
          // Spin History List
          Expanded(child: SpinHistoryWidget(history: provider.history)),
          // Strategy (staged betting) Selector
          const StagedBettingSelector(),
          const SizedBox(width: 8),
          // Settings Modal Trigger Button
          IconButton(
            onPressed: () {
              soundEngine.playClick();
              showDialog(
                context: context,
                builder: (_) => ChangeNotifierProvider<GameProvider>.value(
                  value: provider,
                  child: SettingsModal(
                    onResetSession: () {
                      provider.resetSessionStats();
                    },
                    tournamentMode: false,
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.settings,
              color: Color(0xFFF5EDD5),
              size: 22,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(GameProvider provider, bool isSpinning) {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF26170F), Color(0xFF4A2F1F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(top: BorderSide(color: Color(0xFFC9A44C), width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 4, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Interactive Chips tray (flush to the left edge)
          Expanded(
            flex: 9,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ChipTray(
                selectedChip: provider.selectedChip,
                onSelectChip: provider.setSelectedChip,
                balance: provider.balance,
                totalBet: provider.totalBet,
                disabled: isSpinning,
              ),
            ),
          ),
          const SizedBox(
            width: 176,
          ), // Reserve center area for the floating player card
          // Right: Player Balance / Stats / Total Bet — FittedBox scales the
          // group down so it never overflows the footer width.
          Expanded(
            flex: 7,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Balance Sheet Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7A553A), Color(0xFF2D1E12)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border.all(
                          color: const Color(0xFFC9A84C).withOpacity(0.6),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'BALANCE',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${provider.balance.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},")}',
                            style: GoogleFonts.playfairDisplay(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Session Stats Widget
                    SessionStatsWidget(stats: provider.sessionStats),
                    const SizedBox(width: 6),
                    // Total Bet Sized Box Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        border: Border.all(
                          color: const Color(0xFFC9A84C).withOpacity(0.5),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TOTAL BET',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFF5D68D),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${provider.totalBet.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},")}',
                            style: GoogleFonts.playfairDisplay(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
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
  }

  Widget _buildFloatingPlayerCard() {
    final avatarType = _userProfile?.avatarUrl.isNotEmpty == true
        ? _userProfile!.avatarUrl
        : 'default';
    final displayName = _userProfile?.username ?? 'Player';

    return GestureDetector(
      onTap: () {
        soundEngine.playClick();
        context.push('/profile').then((_) {
          // Re-enforce orientation after returning
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          _loadUserProfile(); // Reload profile if changed
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5C3B27), Color(0xFF3D271A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFFC9A84C).withOpacity(0.5),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 15,
              offset: const Offset(0, -5),
            ),
            BoxShadow(
              color: const Color(0xFFC9A84C).withOpacity(0.12),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar Circle
            Stack(
              alignment: Alignment.center,
              children: [
                AvatarWidget(type: avatarType, size: 32),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Profile text
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $displayName!',
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ELITE VIP MEMBER',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFC9A84C),
                        fontSize: 6,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC9A84C),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToast(GameProvider provider) {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.95),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                provider.fundError!,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  provider.setFundError(null);
                },
                child: const Icon(Icons.close, color: Colors.white70, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Spin History Horizontal Row Widget
// ──────────────────────────────────────────────────────────────────────────────
class SpinHistoryWidget extends StatelessWidget {
  final List<SpinResult> history;
  const SpinHistoryWidget({Key? key, required this.history}) : super(key: key);

  Color _getColor(String colorStr) {
    if (colorStr == 'red') return const Color(0xFFC0392B);
    if (colorStr == 'green') return const Color(0xFF267B4B);
    return const Color(0xFF1A1A1A);
  }

  @override
  Widget build(BuildContext context) {
    // "HISTORY" label (with count) shown before the result circles, matching
    // the web app's header.
    final Widget label = const Text(
      'HISTORY',
      style: const TextStyle(
        fontFamily: 'Georgia',
        color: Color(0xFFF5EDD5),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 2.0,
      ),
    );

    if (history.isEmpty) {
      return Row(
        children: [
          label,
          const SizedBox(width: 12),
          Text(
            'NO SPINS YET',
            style: GoogleFonts.inter(
              color: const Color(0xFFE4E0D4).withOpacity(0.4),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        label,
        const SizedBox(width: 14),
        Expanded(
          child: SizedBox(
            height: 24,
            child: Builder(
              builder: (context) {
                // history[0] is the newest. Keep natural order so the most
                // recent spin sits on the far left (matches the web app).
                final displayed = history
                    .take(math.min(history.length, 15))
                    .toList();
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: displayed.length,
                  itemBuilder: (context, index) {
                    final spin = displayed[index];
                    final displayColor = _getColor(spin.color);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: displayColor,
                        border: Border.all(
                          color: const Color(0xFFC9A84C).withOpacity(0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        spin.displayNumber,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Session Stats Card Row Widget
// ──────────────────────────────────────────────────────────────────────────────
class SessionStatsWidget extends StatelessWidget {
  final Map<String, double> stats;
  const SessionStatsWidget({Key? key, required this.stats}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double lastBet = stats['lastBet'] ?? 0.0;
    final double lastWin = stats['lastWin'] ?? 0.0;
    final double sessionWin = stats['sessionWin'] ?? 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatCard('Last Bet', lastBet, Colors.white.withOpacity(0.8)),
        const SizedBox(width: 4),
        _buildStatCard(
          'Last Win',
          lastWin,
          lastWin > 0
              ? const Color(0xFF4ADE80)
              : lastWin < 0
              ? const Color(0xFFEF4444)
              : Colors.white.withOpacity(0.8),
        ),
        const SizedBox(width: 4),
        _buildStatCard(
          'Session Win',
          sessionWin,
          sessionWin > 0
              ? const Color(0xFF4ADE80)
              : sessionWin < 0
              ? const Color(0xFFEF4444)
              : Colors.white.withOpacity(0.8),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, double val, Color valColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border.all(
          color: const Color(0xFFC9A84C).withOpacity(0.15),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(0xFFE4E0D4).withOpacity(0.5),
              fontSize: 6,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            '${val >= 0 ? '' : '-'}\$${val.abs().toInt()}',
            style: GoogleFonts.inter(
              color: valColor,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Custom Avatar Icon Drawer Widget
// ──────────────────────────────────────────────────────────────────────────────
class AvatarWidget extends StatelessWidget {
  final String type;
  final double size;
  final Color? color;
  final BoxBorder? border;

  const AvatarWidget({
    Key? key,
    required this.type,
    this.size = 32.0,
    this.color,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFFF5EDD5);
    final isCustomAvatar = type.startsWith('http') || type.startsWith('/');
    Widget child;

    if (isCustomAvatar) {
      child = Image.network(
        type,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.person, color: Color(0xFFC9A84C)),
      );
    } else {
      switch (type) {
        case 'default':
          child = Icon(Icons.person_outline, size: size * 0.7, color: c);
          break;
        case 'crown':
          child = Icon(
            Icons.workspace_premium_outlined,
            size: size * 0.7,
            color: c,
          );
          break;
        case 'diamond':
          child = Icon(Icons.diamond_outlined, size: size * 0.7, color: c);
          break;
        case 'star':
          child = Icon(Icons.star_outline, size: size * 0.7, color: c);
          break;
        case 'spade':
          child = Center(
            child: Text(
              '♠',
              style: TextStyle(
                color: c,
                fontSize: size * 0.8,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          );
          break;
        case 'heart':
          child = Center(
            child: Text(
              '♥',
              style: TextStyle(
                color: c,
                fontSize: size * 0.8,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          );
          break;
        case 'club':
          child = Center(
            child: Text(
              '♣',
              style: TextStyle(
                color: c,
                fontSize: size * 0.8,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          );
          break;
        case 'dice':
          child = Icon(Icons.casino_outlined, size: size * 0.7, color: c);
          break;
        case 'chip':
          child = Icon(Icons.circle_outlined, size: size * 0.7, color: c);
          break;
        case 'trophy':
          child = Icon(Icons.emoji_events_outlined, size: size * 0.7, color: c);
          break;
        case 'bolt':
          child = Icon(Icons.bolt_outlined, size: size * 0.7, color: c);
          break;
        default:
          child = Icon(Icons.person_outline, size: size * 0.7, color: c);
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.08),
        border:
            border ?? Border.all(color: const Color(0xFFC9A84C), width: 1.5),
      ),
      child: ClipOval(child: child),
    );
  }
}
