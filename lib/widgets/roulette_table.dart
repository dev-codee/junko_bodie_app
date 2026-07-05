import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:junko_bodie/config/theme.dart';
import 'package:junko_bodie/logic/bets.dart';
import 'package:junko_bodie/logic/rng.dart';
import 'package:junko_bodie/logic/game_phases.dart';
import 'package:junko_bodie/providers/game_provider.dart';
import 'package:junko_bodie/widgets/betting_layout.dart';
import 'package:junko_bodie/widgets/roulette_wheel.dart';
import 'package:junko_bodie/audio/audio_engine.dart';

class RouletteTable extends StatefulWidget {
  final bool tournamentMode;

  const RouletteTable({super.key, this.tournamentMode = false});

  @override
  State<RouletteTable> createState() => _RouletteTableState();
}

class _RouletteTableState extends State<RouletteTable> {
  // Stable key so the wheel keeps its spin physics while it reparents between
  // the inline slot and the centered spinning overlay.
  final GlobalKey _wheelKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final tournamentMode = widget.tournamentMode;
    return Consumer<GameProvider>(
      builder: (context, provider, child) {
        final canBet = provider.phase == GamePhase.betting;
        final isLocked = provider.phase == GamePhase.locked;
        final isSpinning = provider.phase == GamePhase.spinning;
        final isResult = provider.phase == GamePhase.result;

        final hasBets = provider.bets.isNotEmpty;
        final spinEnabled =
            canBet && hasBets; // Require bets to spin in solo game

        return LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive sizes
            final double height = constraints.maxHeight;
            final double width = constraints.maxWidth;

            // Enforce landscape layout proportions. Leave vertical room below
            // the wheel for the AMERICAN/EUROPEAN toggle (~52px) so the wheel
            // column never overflows the felt.
            // Request nearly the full felt height; the FittedBox below caps it
            // so it never overflows. The toggle is overlaid on the wheel's rim
            // (not stacked below) so the wheel gets the whole height.
            final double wheelSize = (height * 1.02).clamp(240.0, 480.0);
            // Large size for the centered spin overlay. While spinning the table
            // fills the whole screen (header/footer are hidden), so this sizes the
            // wheel to the full screen height for a dramatic, centered spin.
            final double spinWheelSize = (height * 1.05).clamp(300.0, 680.0);

            // The wheel widget — built once with a stable key so it can move
            // between the inline slot and the spin overlay without restarting.
            final Widget wheelWidget = RouletteWheel(
              key: _wheelKey,
              wheelType: provider.wheelType,
              spinResult: provider.currentResult,
              isSpinning: isSpinning,
              onSpinComplete: () {
                provider.resolveResult();
              },
              size: isSpinning ? spinWheelSize : wheelSize,
              tournamentMode: tournamentMode,
            );

            return Container(
              width: width,
              height: height,
              // Edge-to-edge solid green with no frame while spinning, so the
              // wheel fills the whole screen on a clean green backdrop.
              padding: isSpinning ? EdgeInsets.zero : const EdgeInsets.all(3.0),
              decoration: isSpinning
                  ? const BoxDecoration(color: Color(0xFF0A2318))
                  : BoxDecoration(
                color: const Color(0xFF0A0A0A),
                border: Border.all(color: const Color(0xFF050505), width: 3),
                borderRadius: BorderRadius.circular(18),
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
                  // Brushed Gold Inner Frame Border
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
                  // Green felt surface area
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const RadialGradient(
                            center: Alignment.center,
                            radius: 0.8,
                            colors: [Color(0xFF143D30), Color(0xFF081A15)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.8),
                              blurRadius: 40,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 1. Wheel Section (Left) — wheel + variant toggle.
                            // While spinning the wheel is lifted into a centered
                            // overlay (below), so here we reserve its width with
                            // a placeholder to keep the layout stable.
                            SizedBox(
                              width: wheelSize,
                              child: isSpinning
                                  ? const SizedBox.shrink()
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: wheelSize,
                                            height: wheelSize,
                                            child: wheelWidget,
                                          ),
                                          // Variant toggle sits below the wheel
                                          // (compact) so it never overlaps it.
                                          if (!tournamentMode && canBet) ...[
                                            const SizedBox(height: 2),
                                            WheelTypeToggle(
                                              wheelType: provider.wheelType,
                                              onChanged: (t) {
                                                soundEngine.playClick();
                                                provider.setWheelType(t);
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            // 2. Betting Table Section (Right)
                            Expanded(
                              child: Column(
                                children: [
                                  // Top row: centered title with the timer
                                  // floated to the right (matches web layout).
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Centered brand title
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          ShaderMask(
                                            shaderCallback: (bounds) =>
                                                const LinearGradient(
                                                  colors: [
                                                    Color(0xFFF5EDD5),
                                                    Color(0xFFC9A44C),
                                                  ],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                ).createShader(bounds),
                                            child: const Text(
                                              'JUNKO BODIE',
                                              style: TextStyle(
                                                fontFamily: 'Georgia',
                                                fontSize: 15,
                                                fontStyle: FontStyle.italic,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            'R O U L E T T E',
                                            style: TextStyle(
                                              fontFamily: 'Georgia',
                                              color: const Color(
                                                0xFFC9A84C,
                                              ).withOpacity(0.6),
                                              fontSize: 6,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 3,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Betting timer pinned to the right
                                      if (provider.isTimerEnabled && canBet)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: BetTimer(
                                            duration: 45,
                                            isActive: canBet,
                                            onTimeout: () => _handleTimeout(provider),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  // Betting layout felt grid with status overlays
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        // Betting Layout Grid
                                        Positioned.fill(
                                          child: AnimatedOpacity(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            opacity: isSpinning ? 0.3 : 1.0,
                                            child: IgnorePointer(
                                              ignoring: !canBet,
                                              child: BettingLayout(
                                                bets: provider.bets,
                                                onPlaceBet: provider.placeBet,
                                                onRemoveBet: provider.removeBet,
                                                disabled: !canBet,
                                                winningResult:
                                                    provider.currentResult,
                                                payoutResult:
                                                    provider.lastPayout,
                                                showWinHighlight: isResult,
                                                phase: provider.phase.name,
                                                deleteMode: provider.deleteMode,
                                                onPopLastChip:
                                                    provider.popLastChip,
                                                onClearZone: provider.clearZone,
                                                wheelType: provider.wheelType,
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
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 24,
                                                        vertical: 12,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.85),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFFC9A44C,
                                                      ),
                                                      width: 3,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.8),
                                                        blurRadius: 50,
                                                      ),
                                                    ],
                                                  ),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'BETS CLOSED',
                                                        style: const TextStyle(
                                                          fontFamily: 'Georgia',
                                                          color: Colors.white,
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                          letterSpacing: 2,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Container(
                                                        height: 1.5,
                                                        width: 100,
                                                        decoration: const BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              Colors
                                                                  .transparent,
                                                              Color(0xFFC9A44C),
                                                              Colors
                                                                  .transparent,
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'GOOD LUCK',
                                                        style:
                                                            GoogleFonts.inter(
                                                              color:
                                                                  const Color(
                                                                    0xFFC9A84C,
                                                                  ),
                                                              fontSize: 8,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              letterSpacing:
                                                                  2.0,
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
                                  const SizedBox(height: 2),
                                  // Control Buttons Row — FittedBox(scaleDown) keeps
                                  // the (variable) button set within the row width so
                                  // the SPIN button never overflows on the right.
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // 2X Double and Delete Toggle (visible when bets are present)
                                        if (canBet && hasBets) ...[
                                          CasinoButton(
                                            label: '2X',
                                            onTap: () {
                                              provider.doubleAllBets();
                                            },
                                            enabled: canBet,
                                          ),
                                          const SizedBox(width: 8),
                                          CasinoButton(
                                            label: provider.deleteMode
                                                ? 'Normal'
                                                : 'X',
                                            onTap: () {
                                              provider.toggleDeleteMode();
                                            },
                                            enabled: canBet,
                                          ),
                                          const SizedBox(width: 12),
                                          // Vertical Separator
                                          Container(
                                            width: 1.5,
                                            height: 24,
                                            color: const Color(
                                              0xFF5EA896,
                                            ).withOpacity(0.3),
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                        // Rebet, Clear, Undo
                                        CasinoButton(
                                          label: 'Rebet',
                                          onTap: () {
                                            soundEngine.playRebetSound();
                                            provider.rebet();
                                          },
                                          enabled:
                                              canBet && provider.hasLastSpin,
                                        ),
                                        const SizedBox(width: 8),
                                        CasinoButton(
                                          label: 'Clear',
                                          onTap: () {
                                            soundEngine.playSwoosh();
                                            provider.clearBets();
                                          },
                                          enabled: canBet && hasBets,
                                        ),
                                        const SizedBox(width: 8),
                                        CasinoButton(
                                          label: 'Undo',
                                          onTap: () {
                                            soundEngine.playSwoosh();
                                            provider.clearLastBet();
                                          },
                                          enabled: canBet && hasBets,
                                        ),
                                        const SizedBox(width: 16),
                                        // Spin button
                                        SpinButton(
                                          onTap: () => _handleSpin(provider),
                                          isSpinning: isSpinning,
                                          enabled: spinEnabled,
                                        ),
                                      ],
                                    ),
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

                  // ── Spinning wheel overlay ──────────────────────────────
                  // While the wheel spins it's lifted out of the inline slot
                  // into a large, screen-centered overlay (dimmed backdrop),
                  // then returns to its place when the spin completes.
                  if (isSpinning)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          // Solid green backdrop — nothing bleeds through.
                          color: const Color(0xFF0A2318),
                          alignment: Alignment.center,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.65, end: 1.0),
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutBack,
                            builder: (context, scale, child) =>
                                Transform.scale(scale: scale, child: child),
                            child: SizedBox(
                              width: spinWheelSize,
                              height: spinWheelSize,
                              child: wheelWidget,
                            ),
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

  void _handleSpin(GameProvider provider) async {
    soundEngine.playSpinClick();
    await provider.executeSpin();
  }

  // Auto-spin when the betting timer runs out — mirrors the web app:
  // lock the table, brief dramatic pause, then spin (even with no bets).
  void _handleTimeout(GameProvider provider) {
    if (provider.phase != GamePhase.betting) return;
    provider.setPhase(GamePhase.locked);
    soundEngine.playLockSound();
    Future.delayed(const Duration(milliseconds: 1500), () {
      // Only proceed if we're still locked (user hasn't navigated away, etc.)
      if (provider.phase == GamePhase.locked) {
        _handleSpin(provider);
      }
    });
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Betting Timer Widget
// ──────────────────────────────────────────────────────────────────────────────
class BetTimer extends StatefulWidget {
  final int duration;
  final bool isActive;
  final VoidCallback onTimeout;

  const BetTimer({
    Key? key,
    required this.duration,
    required this.isActive,
    required this.onTimeout,
  }) : super(key: key);

  @override
  State<BetTimer> createState() => _BetTimerState();
}

class _BetTimerState extends State<BetTimer> {
  int _timeLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.duration;
    if (widget.isActive) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant BetTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _timeLeft = widget.duration;
        _startTimer();
      } else {
        _stopTimer();
      }
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft <= 1) {
        setState(() {
          _timeLeft = 0;
        });
        _stopTimer();
        widget.onTimeout();
      } else {
        setState(() {
          _timeLeft--;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    const double size = 42.0;
    const double radius = 17.0;
    const double strokeWidth = 3.0;
    final double value = _timeLeft / widget.duration;

    final isDanger = _timeLeft <= 5;
    final displayColor = isDanger ? Colors.red : const Color(0xFFC9A44C);

    // alternate opacity when in danger to create a flashing/pulse effect
    final double pulseOpacity = (isDanger && _timeLeft % 2 == 0) ? 0.3 : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background Circle track
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: strokeWidth,
                  color: Colors.white.withOpacity(0.1),
                ),
                // Active Countdown Circle
                CircularProgressIndicator(
                  value: value,
                  strokeWidth: strokeWidth,
                  color: displayColor,
                ),
                // Text countdown
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: pulseOpacity,
                  child: Text(
                    '$_timeLeft',
                    style: GoogleFonts.inter(
                      color: displayColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'TIME TO BET',
            style: GoogleFonts.inter(
              color: const Color(0xFFC9A84C).withOpacity(0.6),
              fontSize: 6,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 3D Styled Casino Button
// ──────────────────────────────────────────────────────────────────────────────
class CasinoButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  const CasinoButton({
    Key? key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<CasinoButton> createState() => _CasinoButtonState();
}

class _CasinoButtonState extends State<CasinoButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;

    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: active
          ? (_) {
              setState(() => _isPressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: active ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: EdgeInsets.only(
          top: _isPressed ? 4.0 : 0.0,
          bottom: _isPressed ? 0.0 : 4.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: active
                ? [const Color(0xFF3D5443), const Color(0xFF2A2A2A)]
                : [const Color(0xFF222222), const Color(0xFF111111)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: active
                ? const Color(0xFFC9A44C)
                : const Color(0xFFC9A44C).withOpacity(0.2),
            width: 1.8,
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: active && !_isPressed
              ? [
                  const BoxShadow(
                    color: Color(0xFF1A0F09),
                    offset: Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          widget.label.toUpperCase(),
          style: GoogleFonts.inter(
            color: active
                ? const Color(0xFFE4E0D4)
                : const Color(0xFFE4E0D4).withOpacity(0.25),
            fontWeight: FontWeight.w900,
            fontSize: 9,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Special 3D Spin Button Widget
// ──────────────────────────────────────────────────────────────────────────────
class SpinButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isSpinning;
  final bool enabled;

  const SpinButton({
    Key? key,
    required this.onTap,
    required this.isSpinning,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<SpinButton> createState() => _SpinButtonState();
}

class _SpinButtonState extends State<SpinButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool active =
        widget.enabled && widget.onTap != null && !widget.isSpinning;

    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: active
          ? (_) {
              setState(() => _isPressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: active ? () => setState(() => _isPressed = false) : null,
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: EdgeInsets.only(
              top: _isPressed ? 6.0 : 0.0,
              bottom: _isPressed ? 0.0 : 6.0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isSpinning
                    ? [const Color(0xFF0A1F1A), const Color(0xFF050F0D)]
                    : active
                    ? [
                        const Color(0xFF2A7D51),
                        const Color(0xFF1A5C3D),
                        const Color(0xFF0F3D28),
                      ]
                    : [const Color(0xFF333333), const Color(0xFF222222)],
                stops: widget.isSpinning
                    ? null
                    : (active ? [0.0, 0.4, 1.0] : null),
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(
                color: widget.isSpinning
                    ? const Color(0xFFC9A44C)
                    : active
                    ? const Color(0xFFF5EDD5)
                    : const Color(0xFF333333),
                width: 2.2,
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: active && !_isPressed
                  ? [
                      const BoxShadow(
                        color: Color(0xFF1A0F09),
                        offset: Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: const Color(0xFFC9A84C).withOpacity(0.2),
                        blurRadius: 20,
                      ),
                    ]
                  : widget.isSpinning
                  ? [
                      BoxShadow(
                        color: const Color(0xFFC9A44C).withOpacity(0.15),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Shimmer overlay when active
                if (active)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: FractionallySizedBox(
                        widthFactor: 2.0,
                        alignment: Alignment(
                          -1.0 + (_shimmerController.value * 2.0),
                          0.0,
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white12,
                                Colors.transparent,
                              ],
                              stops: [0.3, 0.5, 0.7],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Text(
                  widget.isSpinning ? 'SPINNING...' : 'SPIN',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    color: widget.isSpinning
                        ? const Color(0xFFC9A44C)
                        : active
                        ? Colors.white
                        : const Color(0xFF555555),
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                    letterSpacing: 3.0,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Wheel-variant toggle (AMERICAN / EUROPEAN) shown under the wheel in solo mode
// ──────────────────────────────────────────────────────────────────────────────
class WheelTypeToggle extends StatelessWidget {
  final WheelType wheelType;
  final ValueChanged<WheelType> onChanged;

  const WheelTypeToggle({
    super.key,
    required this.wheelType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: const Color(0xFFC9A44C).withOpacity(0.4),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('AMERICAN', WheelType.american),
          _segment('EUROPEAN', WheelType.european),
        ],
      ),
    );
  }

  Widget _segment(String label, WheelType type) {
    final bool active = wheelType == type;
    return GestureDetector(
      onTap: () => onChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFFF5EDD5), Color(0xFFC9A44C)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          borderRadius: BorderRadius.circular(100),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFFC9A44C).withOpacity(0.4),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Georgia',
            color: active
                ? const Color(0xFF06140E)
                : const Color(0xFFC9A44C).withOpacity(0.7),
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
