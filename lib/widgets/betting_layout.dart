import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:junko_bodie/config/theme.dart';
import 'package:junko_bodie/logic/bets.dart';
import 'package:junko_bodie/logic/rng.dart';
import 'package:junko_bodie/logic/payouts.dart';
import 'package:junko_bodie/logic/game_phases.dart';
import 'package:junko_bodie/widgets/chip_stack.dart';
import 'package:junko_bodie/audio/audio_engine.dart';

// --- Number Mappings for Outside Bets ---
final List<int> redNumbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36];
final List<int> blackNumbers = [2, 4, 6, 8, 10, 11, 13, 15, 17, 20, 22, 24, 26, 28, 29, 31, 33, 35];
final List<int> evenNumbers = List.generate(18, (i) => (i + 1) * 2);
final List<int> oddNumbers = List.generate(18, (i) => i * 2 + 1);
final List<int> lowNumbers = List.generate(18, (i) => i + 1);
final List<int> highNumbers = List.generate(18, (i) => i + 19);
final List<int> dozen1st = List.generate(12, (i) => i + 1);
final List<int> dozen2nd = List.generate(12, (i) => i + 13);
final List<int> dozen3rd = List.generate(12, (i) => i + 25);
final List<int> column1st = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34];
final List<int> column2nd = [2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35];
final List<int> column3rd = [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36];

final List<List<int>> gridRows = [
  column3rd,
  column2nd,
  column1st,
];

Color getCellBg(int num) {
  final color = RNG.getNumberColor(num);
  if (color == 'red') return AppColors.rouletteRed;
  if (color == 'green') return AppColors.rouletteGreen;
  return AppColors.rouletteBlack;
}

/// A single interactive number cell on the felt table.
class NumberCell extends StatefulWidget {
  final int num;
  final PlacedBet? bet;
  final VoidCallback onPlace;
  final VoidCallback onRemove;
  final bool disabled;
  final bool isWinner;
  final String phase;
  final BoxBorder? border;
  final bool isHovered;
  final ValueChanged<int>? onNumberHover;
  final VoidCallback? onNumberHoverEnd;
  final bool deleteMode;
  final ValueChanged<String>? onPopLastChip;
  final ValueChanged<String>? onClearZone;
  final bool isMine;
  final bool isCompact;

  const NumberCell({
    super.key,
    required this.num,
    this.bet,
    required this.onPlace,
    required this.onRemove,
    required this.disabled,
    required this.isWinner,
    required this.phase,
    this.border,
    this.isHovered = false,
    this.onNumberHover,
    this.onNumberHoverEnd,
    this.deleteMode = false,
    this.onPopLastChip,
    this.onClearZone,
    this.isMine = true,
    this.isCompact = false,
  });

  @override
  State<NumberCell> createState() => _NumberCellState();
}

class _NumberCellState extends State<NumberCell> with SingleTickerProviderStateMixin {
  late AnimationController _winAnimController;

  @override
  void initState() {
    super.initState();
    _winAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.isWinner) {
      _winAnimController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant NumberCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWinner && !_winAnimController.isAnimating) {
      _winAnimController.repeat(reverse: true);
    } else if (!widget.isWinner && _winAnimController.isAnimating) {
      _winAnimController.stop();
    }
  }

  @override
  void dispose() {
    _winAnimController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.disabled) return;
    if (widget.deleteMode && widget.bet != null) {
      widget.onClearZone?.call('straight-${RNG.getDisplayNumber(widget.num)}');
    } else if (!widget.deleteMode) {
      soundEngine.playChipSound();
      widget.onPlace();
    }
  }

  void _handleLongPress() {
    if (widget.disabled) return;
    if (widget.bet != null) {
      widget.onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBet = widget.bet != null;

    return Expanded(
      child: MouseRegion(
        onEnter: (_) => widget.onNumberHover?.call(widget.num),
        onExit: (_) => widget.onNumberHoverEnd?.call(),
        child: GestureDetector(
          onTapDown: (_) => widget.onNumberHover?.call(widget.num),
          onTapUp: (_) {
            Future.delayed(const Duration(milliseconds: 1000), () {
              widget.onNumberHoverEnd?.call();
            });
          },
          onTapCancel: () {
            Future.delayed(const Duration(milliseconds: 1000), () {
              widget.onNumberHoverEnd?.call();
            });
          },
          onTap: _handleTap,
          onLongPress: _handleLongPress,
          onSecondaryTap: _handleLongPress,
          child: AnimatedBuilder(
            animation: _winAnimController,
            builder: (context, child) {
              // Pulse shadow and border if it is a winner
              BoxShadow? winShadow;
              if (widget.isWinner) {
                winShadow = BoxShadow(
                  color: AppColors.goldLight.withOpacity(_winAnimController.value * 0.7),
                  blurRadius: 15,
                  spreadRadius: 2,
                );
              }

              // Gold "lightning" highlight on cells covered by the hovered bet
              // zone — mirrors the web's inset gold glow + gold border.
              final bool showHover =
                  widget.isHovered && !widget.isWinner && !widget.disabled;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: showHover
                      ? AppColors.gold.withOpacity(0.18)
                      : Colors.transparent,
                  border: showHover
                      ? Border.all(color: AppColors.gold, width: 1.2)
                      : (widget.border ??
                          Border.all(color: const Color(0xFF5EA896), width: 1.5)),
                  boxShadow: winShadow != null
                      ? [winShadow]
                      : showHover
                          ? [
                              BoxShadow(
                                color: AppColors.gold.withOpacity(0.45),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // The numbered oval (stadium shape) — larger than the old
                    // circle so the grid reads like the web reference.
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: widget.isCompact ? 30 : 44,
                      height: widget.isCompact ? 22 : 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: getCellBg(widget.num),
                        border: Border.all(
                          color: widget.isWinner
                              ? AppColors.gold
                              : Colors.white.withOpacity(0.12),
                          width: 1,
                        ),
                        boxShadow: [
                          if (widget.isWinner)
                            BoxShadow(
                              color: AppColors.gold.withOpacity(0.8),
                              blurRadius: 10,
                            ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          RNG.getDisplayNumber(widget.num),
                          style: playfairDisplay(
                            fontSize: widget.isCompact ? 12 : 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ).copyWith(height: 1.0),
                        ),
                      ),
                    ),

                    // Placed Chips
                    if (hasBet)
                      ChipStackWidget(
                        chips: widget.bet!.chips,
                        phase: widget.phase,
                        deleteMode: widget.deleteMode,
                        isMine: widget.isMine,
                        isHovered: widget.isHovered,
                      ),

                    // Amount tooltip (if hovered and not compact)
                    if (hasBet && widget.isHovered && !widget.isCompact)
                      Positioned(
                        top: -45,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.9),
                            border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '\$${widget.bet!.amount.toInt()}',
                            style: GoogleFonts.inter(
                              color: AppColors.gold,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// An invisible/subtle interactive drop zone placed at intersections (splits, corners).
class DropZone extends StatefulWidget {
  final String betId;
  final double left;
  final double top;
  final double width;
  final double height;
  final Map<String, PlacedBet> bets;
  final ValueChanged<String> onPlace;
  final ValueChanged<String> onRemove;
  final bool disabled;
  final bool isWinner;
  final String phase;
  final List<int> numbers;
  final Function(List<int>, String)? onHover;
  final VoidCallback? onHoverEnd;
  final bool deleteMode;
  final ValueChanged<String>? onPopLastChip;
  final ValueChanged<String>? onClearZone;
  final bool isMine;

  const DropZone({
    super.key,
    required this.betId,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.bets,
    required this.onPlace,
    required this.onRemove,
    required this.disabled,
    required this.isWinner,
    required this.phase,
    required this.numbers,
    this.onHover,
    this.onHoverEnd,
    this.deleteMode = false,
    this.onPopLastChip,
    this.onClearZone,
    this.isMine = true,
  });

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _localHovered = false;

  void _handleTap() {
    if (widget.disabled) return;
    if (widget.deleteMode && widget.bets.containsKey(widget.betId)) {
      widget.onClearZone?.call(widget.betId);
    } else if (!widget.deleteMode) {
      soundEngine.playChipSound();
      widget.onPlace(widget.betId);
      // Touch feedback — flash the covered numbers gold briefly.
      widget.onHover?.call(widget.numbers, widget.betId);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) widget.onHoverEnd?.call();
      });
    }
  }

  void _handleLongPress() {
    if (widget.disabled) return;
    if (widget.bets.containsKey(widget.betId)) {
      widget.onRemove(widget.betId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bet = widget.bets[widget.betId];
    final hasBet = bet != null;

    return Positioned(
      left: widget.left - widget.width / 2,
      top: widget.top - widget.height / 2,
      width: widget.width,
      height: widget.height,
      child: MouseRegion(
          onEnter: (_) {
            if (!widget.disabled) {
              widget.onHover?.call(widget.numbers, widget.betId);
              setState(() => _localHovered = true);
            }
          },
          onExit: (_) {
            if (!widget.disabled) {
              widget.onHoverEnd?.call();
              setState(() => _localHovered = false);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              if (!widget.disabled) {
                widget.onHover?.call(widget.numbers, widget.betId);
                setState(() => _localHovered = true);
              }
            },
            onTapUp: (_) {
              if (!widget.disabled) {
                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (mounted) {
                    widget.onHoverEnd?.call();
                    setState(() => _localHovered = false);
                  }
                });
              }
            },
            onTapCancel: () {
              if (!widget.disabled) {
                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (mounted) {
                    widget.onHoverEnd?.call();
                    setState(() => _localHovered = false);
                  }
                });
              }
            },
            onTap: _handleTap,
            onLongPress: _handleLongPress,
            onSecondaryTap: _handleLongPress,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Highlight circle on hover
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _localHovered && !widget.disabled
                        ? RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.4),
                              AppColors.gold.withOpacity(0.15),
                              Colors.transparent,
                            ],
                          )
                        : null,
                  ),
                ),

                // Chip stack on this intersection
                if (hasBet)
                  ChipStackWidget(
                    chips: bet.chips,
                    phase: widget.phase,
                    deleteMode: widget.deleteMode,
                    isMine: widget.isMine,
                    isHovered: _localHovered,
                  ),

                // Winner indicator
                if (widget.isWinner)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.goldLight, width: 1.5),
                      ),
                    ),
                  ),

                // Tooltip
                if (hasBet && _localHovered)
                  Positioned(
                    bottom: 45,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.9),
                        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '\$${bet.amount.toInt()}',
                        style: GoogleFonts.inter(
                          color: AppColors.gold,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
    );
  }
}

/// Representing outside bet blocks (Dozens, Columns, Odd/Even, etc.)
class OutsideBetCell extends StatefulWidget {
  final String label;
  final PlacedBet? bet;
  final VoidCallback onPlace;
  final VoidCallback onRemove;
  final bool disabled;
  final bool isWinner;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final BoxBorder? border;
  final String phase;
  final List<int> numbers;
  final Function(List<int>, String)? onHover;
  final VoidCallback? onHoverEnd;
  final String betId;
  final bool deleteMode;
  final ValueChanged<String>? onClearZone;
  final bool isMine;
  final bool isCompact;

  const OutsideBetCell({
    super.key,
    required this.label,
    this.bet,
    required this.onPlace,
    required this.onRemove,
    required this.disabled,
    required this.isWinner,
    this.textStyle,
    this.backgroundColor,
    this.border,
    required this.phase,
    required this.numbers,
    this.onHover,
    this.onHoverEnd,
    required this.betId,
    this.deleteMode = false,
    this.onClearZone,
    this.isMine = true,
    this.isCompact = false,
  });

  @override
  State<OutsideBetCell> createState() => _OutsideBetCellState();
}

class _OutsideBetCellState extends State<OutsideBetCell> {
  bool _isHovered = false;

  void _handleTap() {
    if (widget.disabled) return;
    if (widget.deleteMode && widget.bet != null) {
      widget.onClearZone?.call(widget.betId);
    } else if (!widget.deleteMode) {
      soundEngine.playChipSound();
      widget.onPlace();
      // Touch feedback — flash the covered numbers gold briefly.
      widget.onHover?.call(widget.numbers, widget.betId);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) widget.onHoverEnd?.call();
      });
    }
  }

  void _handleLongPress() {
    if (widget.disabled) return;
    if (widget.bet != null) {
      widget.onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBet = widget.bet != null;

    return Expanded(
      child: MouseRegion(
        onEnter: (_) {
          if (!widget.disabled) {
            widget.onHover?.call(widget.numbers, widget.betId);
            setState(() => _isHovered = true);
          }
        },
        onExit: (_) {
          if (!widget.disabled) {
            widget.onHoverEnd?.call();
            setState(() => _isHovered = false);
          }
        },
        child: GestureDetector(
          onTapDown: (_) {
            if (!widget.disabled) {
              widget.onHover?.call(widget.numbers, widget.betId);
              setState(() => _isHovered = true);
            }
          },
          onTapUp: (_) {
            if (!widget.disabled) {
              widget.onHoverEnd?.call();
              setState(() => _isHovered = false);
            }
          },
          onTapCancel: () {
            if (!widget.disabled) {
              widget.onHoverEnd?.call();
              setState(() => _isHovered = false);
            }
          },
          onTap: _handleTap,
          onLongPress: _handleLongPress,
          onSecondaryTap: _handleLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.isWinner
                  ? AppColors.gold.withOpacity(0.3)
                  : widget.backgroundColor ?? Colors.transparent,
              border: widget.border ?? Border.all(color: const Color(0xFF5EA896), width: 1.5),
              boxShadow: [
                if (widget.isWinner)
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.5),
                    blurRadius: 10,
                  ),
                if (_isHovered && !widget.disabled && !widget.deleteMode)
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.12),
                    blurRadius: 4,
                  ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Label text
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: widget.textStyle ??
                      GoogleFonts.inter(
                        fontSize: widget.isCompact ? 9 : 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                ),

                // Placed chips stack
                if (hasBet)
                  ChipStackWidget(
                    chips: widget.bet!.chips,
                    phase: widget.phase,
                    deleteMode: widget.deleteMode,
                    isMine: widget.isMine,
                    isHovered: _isHovered,
                  ),

                // Tooltip
                if (hasBet && _isHovered && !widget.isCompact)
                  Positioned(
                    top: -22,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.9),
                        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '\$${widget.bet!.amount.toInt()}',
                        style: GoogleFonts.inter(
                          color: AppColors.gold,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The main felt table layout displaying the standard betting grid.
class BettingLayout extends StatefulWidget {
  final Map<String, PlacedBet> bets;
  final ValueChanged<String> onPlaceBet;
  final ValueChanged<String> onRemoveBet;
  final bool disabled;
  final SpinResult? winningResult;
  final PayoutResult? payoutResult;
  final bool showWinHighlight;
  final String phase;
  final bool deleteMode;
  final ValueChanged<String>? onPopLastChip;
  final ValueChanged<String>? onClearZone;
  final WheelType wheelType;
  final Map<String, PlacedBet>? myBets;
  final bool isCompact;

  const BettingLayout({
    super.key,
    required this.bets,
    required this.onPlaceBet,
    required this.onRemoveBet,
    required this.disabled,
    this.winningResult,
    this.payoutResult,
    required this.showWinHighlight,
    required this.phase,
    this.deleteMode = false,
    this.onPopLastChip,
    this.onClearZone,
    required this.wheelType,
    this.myBets,
    this.isCompact = false,
  });

  @override
  State<BettingLayout> createState() => _BettingLayoutState();
}

class _BettingLayoutState extends State<BettingLayout> {
  List<int> _hoveredNumbers = [];
  String? _hoveredBetId;
  int? _selfHoveredNumber;

  bool _isBetWinner(String betId) {
    if (!widget.showWinHighlight || widget.payoutResult == null) return false;
    return widget.payoutResult!.outcomes.any((o) => o.betId == betId && o.isWin);
  }

  bool _isWinningNumber(int num) {
    if (!widget.showWinHighlight || widget.winningResult == null) return false;
    return widget.winningResult!.number == num;
  }

  void _handleHover(List<int> nums, String betId) {
    setState(() {
      _hoveredNumbers = nums;
      _hoveredBetId = betId;
    });
  }

  void _handleHoverEnd() {
    setState(() {
      _hoveredNumbers = const [];
      _hoveredBetId = null;
    });
  }

  void _handleNumberHover(int num) {
    setState(() => _selfHoveredNumber = num);
  }

  void _handleNumberHoverEnd() {
    setState(() => _selfHoveredNumber = null);
  }

  @override
  Widget build(BuildContext context) {
    final double spacerWidth = widget.isCompact ? 32 : 44;
    final double colWidth = widget.isCompact ? 32 : 40;

    return Container(
      padding: const EdgeInsets.all(4.0),
      child: Stack(
        children: [
          Column(
            children: [
              // ── SECTION 1: Zeros, Numbers Grid, Columns ──
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // ZEROS BLOCK
              Container(
                width: spacerWidth,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF5EA896), width: 1.5),
                  color: Colors.transparent,
                ),
                child: widget.wheelType == WheelType.american
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              Column(
                                children: [
                                  NumberCell(
                                    num: 37, // "00"
                                    bet: widget.bets['straight-00'],
                                    onPlace: () => widget.onPlaceBet('straight-00'),
                                    onRemove: () => widget.onRemoveBet('straight-00'),
                                    disabled: widget.disabled,
                                    isWinner: _isWinningNumber(37) || _isBetWinner('straight-00'),
                                    phase: widget.phase,
                                    isHovered: _hoveredNumbers.contains(37) || _selfHoveredNumber == 37,
                                    onNumberHover: _handleNumberHover,
                                    onNumberHoverEnd: _handleNumberHoverEnd,
                                    deleteMode: widget.deleteMode,
                                    onPopLastChip: widget.onPopLastChip,
                                    onClearZone: widget.onClearZone,
                                    isMine: widget.myBets?.containsKey('straight-00') ?? true,
                                    isCompact: widget.isCompact,
                                  ),
                                  NumberCell(
                                    num: 0,
                                    bet: widget.bets['straight-0'],
                                    onPlace: () => widget.onPlaceBet('straight-0'),
                                    onRemove: () => widget.onRemoveBet('straight-0'),
                                    disabled: widget.disabled,
                                    isWinner: _isWinningNumber(0) || _isBetWinner('straight-0'),
                                    phase: widget.phase,
                                    isHovered: _hoveredNumbers.contains(0) || _selfHoveredNumber == 0,
                                    onNumberHover: _handleNumberHover,
                                    onNumberHoverEnd: _handleNumberHoverEnd,
                                    deleteMode: widget.deleteMode,
                                    onPopLastChip: widget.onPopLastChip,
                                    onClearZone: widget.onClearZone,
                                    isMine: widget.myBets?.containsKey('straight-0') ?? true,
                                    isCompact: widget.isCompact,
                                  ),
                                ],
                              ),
                              DropZone(
                                betId: 'split-0-00',
                                left: constraints.maxWidth / 2,
                                top: constraints.maxHeight / 2,
                                width: 16,
                                height: 8,
                                bets: widget.bets,
                                onPlace: widget.onPlaceBet,
                                onRemove: widget.onRemoveBet,
                                disabled: widget.disabled,
                                isWinner: _isBetWinner('split-0-00'),
                                phase: widget.phase,
                                numbers: const [0, 37],
                                onHover: _handleHover,
                                onHoverEnd: _handleHoverEnd,
                                deleteMode: widget.deleteMode,
                                onPopLastChip: widget.onPopLastChip,
                                onClearZone: widget.onClearZone,
                                isMine: widget.myBets?.containsKey('split-0-00') ?? true,
                              ),
                            ],
                          );
                        },
                      )
                    : Column(
                        children: [
                          NumberCell(
                            num: 0,
                            bet: widget.bets['straight-0'],
                            onPlace: () => widget.onPlaceBet('straight-0'),
                            onRemove: () => widget.onRemoveBet('straight-0'),
                            disabled: widget.disabled,
                            isWinner: _isWinningNumber(0) || _isBetWinner('straight-0'),
                            phase: widget.phase,
                            isHovered: _hoveredNumbers.contains(0) || _selfHoveredNumber == 0,
                            onNumberHover: _handleNumberHover,
                            onNumberHoverEnd: _handleNumberHoverEnd,
                            deleteMode: widget.deleteMode,
                            onPopLastChip: widget.onPopLastChip,
                            onClearZone: widget.onClearZone,
                            isMine: widget.myBets?.containsKey('straight-0') ?? true,
                            isCompact: widget.isCompact,
                          ),
                        ],
                      ),
              ),

              // NUMBERS GRID
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF5EA896), width: 1.5),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final gridWidth = constraints.maxWidth;
                      final gridHeight = constraints.maxHeight;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 3 Rows of 12 columns
                          Column(
                            children: gridRows.map((row) {
                              return Expanded(
                                child: Row(
                                  children: row.map((num) {
                                    final betId = 'straight-$num';
                                    return NumberCell(
                                      num: num,
                                      bet: widget.bets[betId],
                                      onPlace: () => widget.onPlaceBet(betId),
                                      onRemove: () => widget.onRemoveBet(betId),
                                      disabled: widget.disabled,
                                      isWinner: _isWinningNumber(num) || _isBetWinner(betId),
                                      phase: widget.phase,
                                      isHovered: _hoveredNumbers.contains(num) || _selfHoveredNumber == num,
                                      onNumberHover: _handleNumberHover,
                                      onNumberHoverEnd: _handleNumberHoverEnd,
                                      deleteMode: widget.deleteMode,
                                      onPopLastChip: widget.onPopLastChip,
                                      onClearZone: widget.onClearZone,
                                      isMine: widget.myBets?.containsKey(betId) ?? true,
                                      isCompact: widget.isCompact,
                                    );
                                  }).toList(),
                                ),
                              );
                            }).toList(),
                          ),

                          // ── COMBINATION BETS OVERLAY (STREETS, SPLITS, CORNERS, SIXLINES) ──
                          // Horizontal Splits
                          ...[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33].map((n) {
                            final betId = 'split-$n-${n + 3}';
                            final col = (n - 1) ~/ 3;
                            final row = 2 - ((n - 1) % 3);
                            final left = (col + 1) * (gridWidth / 12);
                            final top = (row + 0.5) * (gridHeight / 3);

                            return DropZone(
                              key: ValueKey(betId),
                              betId: betId,
                              left: left,
                              top: top,
                              width: 16,
                              height: 20,
                              bets: widget.bets,
                              onPlace: widget.onPlaceBet,
                              onRemove: widget.onRemoveBet,
                              disabled: widget.disabled,
                              isWinner: _isBetWinner(betId),
                              phase: widget.phase,
                              numbers: [n, n + 3],
                              onHover: _handleHover,
                              onHoverEnd: _handleHoverEnd,
                              deleteMode: widget.deleteMode,
                              onPopLastChip: widget.onPopLastChip,
                              onClearZone: widget.onClearZone,
                              isMine: widget.myBets?.containsKey(betId) ?? true,
                            );
                          }),

                          // Vertical Splits
                          ...[1, 2, 4, 5, 7, 8, 10, 11, 13, 14, 16, 17, 19, 20, 22, 23, 25, 26, 28, 29, 31, 32, 34, 35].map((n) {
                            final betId = 'split-$n-${n + 1}';
                            final col = (n - 1) ~/ 3;
                            final row = 2 - ((n - 1) % 3);
                            final left = (col + 0.5) * (gridWidth / 12);
                            final top = row * (gridHeight / 3);

                            return DropZone(
                              key: ValueKey(betId),
                              betId: betId,
                              left: left,
                              top: top,
                              width: 24,
                              height: 16,
                              bets: widget.bets,
                              onPlace: widget.onPlaceBet,
                              onRemove: widget.onRemoveBet,
                              disabled: widget.disabled,
                              isWinner: _isBetWinner(betId),
                              phase: widget.phase,
                              numbers: [n, n + 1],
                              onHover: _handleHover,
                              onHoverEnd: _handleHoverEnd,
                              deleteMode: widget.deleteMode,
                              onPopLastChip: widget.onPopLastChip,
                              onClearZone: widget.onClearZone,
                              isMine: widget.myBets?.containsKey(betId) ?? true,
                            );
                          }),

                          // Corner Bets
                          ...[1, 2, 4, 5, 7, 8, 10, 11, 13, 14, 16, 17, 19, 20, 22, 23, 25, 26, 28, 29, 31, 32].map((n) {
                            final betId = 'corner-$n-${n + 1}-${n + 3}-${n + 4}';
                            final col = (n - 1) ~/ 3;
                            final row = 2 - ((n - 1) % 3);
                            final left = (col + 1) * (gridWidth / 12);
                            final top = row * (gridHeight / 3);

                            return DropZone(
                              key: ValueKey(betId),
                              betId: betId,
                              left: left,
                              top: top,
                              width: 20,
                              height: 20,
                              bets: widget.bets,
                              onPlace: widget.onPlaceBet,
                              onRemove: widget.onRemoveBet,
                              disabled: widget.disabled,
                              isWinner: _isBetWinner(betId),
                              phase: widget.phase,
                              numbers: [n, n + 1, n + 3, n + 4],
                              onHover: _handleHover,
                              onHoverEnd: _handleHoverEnd,
                              deleteMode: widget.deleteMode,
                              onPopLastChip: widget.onPopLastChip,
                              onClearZone: widget.onClearZone,
                              isMine: widget.myBets?.containsKey(betId) ?? true,
                            );
                          }),

                          // Street Bets
                          ...[1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34].map((n) {
                            final betId = 'street-$n-${n + 1}-${n + 2}';
                            final col = (n - 1) ~/ 3;
                            final left = (col + 0.5) * (gridWidth / 12);
                            final top = gridHeight;

                            return DropZone(
                              key: ValueKey(betId),
                              betId: betId,
                              left: left,
                              top: top,
                              width: 24,
                              height: 16,
                              bets: widget.bets,
                              onPlace: widget.onPlaceBet,
                              onRemove: widget.onRemoveBet,
                              disabled: widget.disabled,
                              isWinner: _isBetWinner(betId),
                              phase: widget.phase,
                              numbers: [n, n + 1, n + 2],
                              onHover: _handleHover,
                              onHoverEnd: _handleHoverEnd,
                              deleteMode: widget.deleteMode,
                              onPopLastChip: widget.onPopLastChip,
                              onClearZone: widget.onClearZone,
                              isMine: widget.myBets?.containsKey(betId) ?? true,
                            );
                          }),

                          // Sixline Bets
                          ...[1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31].map((n) {
                            final betId = 'sixline-$n-${n + 5}';
                            final col = (n - 1) ~/ 3;
                            final left = (col + 1) * (gridWidth / 12);
                            final top = gridHeight;

                            return DropZone(
                              key: ValueKey(betId),
                              betId: betId,
                              left: left,
                              top: top,
                              width: 20,
                              height: 20,
                              bets: widget.bets,
                              onPlace: widget.onPlaceBet,
                              onRemove: widget.onRemoveBet,
                              disabled: widget.disabled,
                              isWinner: _isBetWinner(betId),
                              phase: widget.phase,
                              numbers: [n, n + 1, n + 2, n + 3, n + 4, n + 5],
                              onHover: _handleHover,
                              onHoverEnd: _handleHoverEnd,
                              deleteMode: widget.deleteMode,
                              onPopLastChip: widget.onPopLastChip,
                              onClearZone: widget.onClearZone,
                              isMine: widget.myBets?.containsKey(betId) ?? true,
                            );
                          }),

                          // Boundary splits with Zero
                          DropZone(betId: 'split-0-1', left: 0, top: gridHeight * 0.833, width: 32, height: 32, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('split-0-1'), phase: widget.phase, numbers: const [0, 1], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('split-0-1') ?? true),
                          DropZone(betId: 'split-0-2', left: 0, top: widget.wheelType == WheelType.american ? gridHeight * 0.60 : gridHeight * 0.50, width: 32, height: 32, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('split-0-2'), phase: widget.phase, numbers: const [0, 2], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('split-0-2') ?? true),
                          if (widget.wheelType == WheelType.american) ...[
                            DropZone(betId: 'split-00-2', left: 0, top: gridHeight * 0.40, width: 32, height: 32, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('split-00-2'), phase: widget.phase, numbers: const [37, 2], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('split-00-2') ?? true),
                            DropZone(betId: 'split-00-3', left: 0, top: gridHeight * 0.166, width: 32, height: 32, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('split-00-3'), phase: widget.phase, numbers: const [37, 3], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('split-00-3') ?? true),
                          ] else ...[
                            DropZone(betId: 'split-0-3', left: 0, top: gridHeight * 0.166, width: 32, height: 32, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('split-0-3'), phase: widget.phase, numbers: const [0, 3], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('split-0-3') ?? true),
                          ],

                          // Trio & Basket
                          DropZone(betId: 'trio-0-1-2', left: 0, top: gridHeight * 0.666, width: 32, height: 32, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('trio-0-1-2'), phase: widget.phase, numbers: const [0, 1, 2], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('trio-0-1-2') ?? true),
                          DropZone(betId: 'trio-0-2-3', left: 0, top: gridHeight * 0.333, width: 32, height: 32, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('trio-0-2-3'), phase: widget.phase, numbers: const [0, 2, 3], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('trio-0-2-3') ?? true),
                          if (widget.wheelType == WheelType.american) ...[
                            DropZone(betId: 'trio-00-2-3', left: 0, top: gridHeight * 0.333, width: 32, height: 32, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('trio-00-2-3'), phase: widget.phase, numbers: const [37, 2, 3], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('trio-00-2-3') ?? true),
                            DropZone(betId: 'basket-0-00-1-2-3', left: 0, top: gridHeight, width: 32, height: 32, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('basket-0-00-1-2-3'), phase: widget.phase, numbers: const [0, 37, 1, 2, 3], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('basket-0-00-1-2-3') ?? true),
                          ] else ...[
                            DropZone(betId: 'basket-0-1-2-3', left: 0, top: gridHeight, width: 32, height: 32, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('basket-0-1-2-3'), phase: widget.phase, numbers: const [0, 1, 2, 3], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('basket-0-1-2-3') ?? true),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),

              // COLUMNS BLOCK
              Container(
                width: colWidth,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF5EA896), width: 1.5),
                ),
                child: Column(
                  children: [
                    OutsideBetCell(
                      label: '2 to 1',
                      betId: 'column-3rd',
                      bet: widget.bets['column-3rd'],
                      onPlace: () => widget.onPlaceBet('column-3rd'),
                      onRemove: () => widget.onRemoveBet('column-3rd'),
                      disabled: widget.disabled,
                      isWinner: _isBetWinner('column-3rd'),
                      phase: widget.phase,
                      numbers: column3rd,
                      onHover: _handleHover,
                      onHoverEnd: _handleHoverEnd,
                      deleteMode: widget.deleteMode,
                      onClearZone: widget.onClearZone,
                      isMine: widget.myBets?.containsKey('column-3rd') ?? true,
                      isCompact: widget.isCompact,
                    ),
                    OutsideBetCell(
                      label: '2 to 1',
                      betId: 'column-2nd',
                      bet: widget.bets['column-2nd'],
                      onPlace: () => widget.onPlaceBet('column-2nd'),
                      onRemove: () => widget.onRemoveBet('column-2nd'),
                      disabled: widget.disabled,
                      isWinner: _isBetWinner('column-2nd'),
                      phase: widget.phase,
                      numbers: column2nd,
                      onHover: _handleHover,
                      onHoverEnd: _handleHoverEnd,
                      deleteMode: widget.deleteMode,
                      onClearZone: widget.onClearZone,
                      isMine: widget.myBets?.containsKey('column-2nd') ?? true,
                      isCompact: widget.isCompact,
                    ),
                    OutsideBetCell(
                      label: '2 to 1',
                      betId: 'column-1st',
                      bet: widget.bets['column-1st'],
                      onPlace: () => widget.onPlaceBet('column-1st'),
                      onRemove: () => widget.onRemoveBet('column-1st'),
                      disabled: widget.disabled,
                      isWinner: _isBetWinner('column-1st'),
                      phase: widget.phase,
                      numbers: column1st,
                      onHover: _handleHover,
                      onHoverEnd: _handleHoverEnd,
                      deleteMode: widget.deleteMode,
                      onClearZone: widget.onClearZone,
                      isMine: widget.myBets?.containsKey('column-1st') ?? true,
                      isCompact: widget.isCompact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── SECTION 2: Dozens ──
          Expanded(
            flex: 1,
            child: Row(
              children: [
                SizedBox(width: spacerWidth),
                Expanded(
                  child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Color(0xFF5EA896), width: 1.5),
                      right: BorderSide(color: Color(0xFF5EA896), width: 1.5),
                      bottom: BorderSide(color: Color(0xFF5EA896), width: 1.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      OutsideBetCell(
                        label: '1st 12',
                        betId: 'dozen-1st',
                        bet: widget.bets['dozen-1st'],
                        onPlace: () => widget.onPlaceBet('dozen-1st'),
                        onRemove: () => widget.onRemoveBet('dozen-1st'),
                        disabled: widget.disabled,
                        isWinner: _isBetWinner('dozen-1st'),
                        phase: widget.phase,
                        numbers: dozen1st,
                        onHover: _handleHover,
                        onHoverEnd: _handleHoverEnd,
                        deleteMode: widget.deleteMode,
                        onClearZone: widget.onClearZone,
                        isMine: widget.myBets?.containsKey('dozen-1st') ?? true,
                        isCompact: widget.isCompact,
                      ),
                      OutsideBetCell(
                        label: '2nd 12',
                        betId: 'dozen-2nd',
                        bet: widget.bets['dozen-2nd'],
                        onPlace: () => widget.onPlaceBet('dozen-2nd'),
                        onRemove: () => widget.onRemoveBet('dozen-2nd'),
                        disabled: widget.disabled,
                        isWinner: _isBetWinner('dozen-2nd'),
                        phase: widget.phase,
                        numbers: dozen2nd,
                        onHover: _handleHover,
                        onHoverEnd: _handleHoverEnd,
                        deleteMode: widget.deleteMode,
                        onClearZone: widget.onClearZone,
                        isMine: widget.myBets?.containsKey('dozen-2nd') ?? true,
                        isCompact: widget.isCompact,
                      ),
                      OutsideBetCell(
                        label: '3rd 12',
                        betId: 'dozen-3rd',
                        bet: widget.bets['dozen-3rd'],
                        onPlace: () => widget.onPlaceBet('dozen-3rd'),
                        onRemove: () => widget.onRemoveBet('dozen-3rd'),
                        disabled: widget.disabled,
                        isWinner: _isBetWinner('dozen-3rd'),
                        phase: widget.phase,
                        numbers: dozen3rd,
                        onHover: _handleHover,
                        onHoverEnd: _handleHoverEnd,
                        deleteMode: widget.deleteMode,
                        onClearZone: widget.onClearZone,
                        isMine: widget.myBets?.containsKey('dozen-3rd') ?? true,
                        isCompact: widget.isCompact,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: colWidth),
            ],
          ),
        ),

          // ── SECTION 3: Even Chances (1-18, Even, Red, Black, Odd, 19-36) ──
          Expanded(
            flex: 1,
            child: Row(
              children: [
                SizedBox(width: spacerWidth),
                Expanded(
                  child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Color(0xFF5EA896), width: 1.5),
                      right: BorderSide(color: Color(0xFF5EA896), width: 1.5),
                      bottom: BorderSide(color: Color(0xFF5EA896), width: 1.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      OutsideBetCell(
                        label: '1-18',
                        betId: 'low',
                        bet: widget.bets['low'],
                        onPlace: () => widget.onPlaceBet('low'),
                        onRemove: () => widget.onRemoveBet('low'),
                        disabled: widget.disabled,
                        isWinner: _isBetWinner('low'),
                        phase: widget.phase,
                        numbers: lowNumbers,
                        onHover: _handleHover,
                        onHoverEnd: _handleHoverEnd,
                        deleteMode: widget.deleteMode,
                        onClearZone: widget.onClearZone,
                        isMine: widget.myBets?.containsKey('low') ?? true,
                        isCompact: widget.isCompact,
                      ),
                      OutsideBetCell(
                        label: 'Even',
                        betId: 'even',
                        bet: widget.bets['even'],
                        onPlace: () => widget.onPlaceBet('even'),
                        onRemove: () => widget.onRemoveBet('even'),
                        disabled: widget.disabled,
                        isWinner: _isBetWinner('even'),
                        phase: widget.phase,
                        numbers: evenNumbers,
                        onHover: _handleHover,
                        onHoverEnd: _handleHoverEnd,
                        deleteMode: widget.deleteMode,
                        onClearZone: widget.onClearZone,
                        isMine: widget.myBets?.containsKey('even') ?? true,
                        isCompact: widget.isCompact,
                      ),
                      OutsideBetCell(
                        label: 'Red',
                        betId: 'red',
                        bet: widget.bets['red'],
                        onPlace: () => widget.onPlaceBet('red'),
                        onRemove: () => widget.onRemoveBet('red'),
                        disabled: widget.disabled,
                        isWinner: _isBetWinner('red'),
                        backgroundColor: AppColors.rouletteRed,
                        textStyle: GoogleFonts.inter(
                          fontSize: widget.isCompact ? 9 : 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                        phase: widget.phase,
                        numbers: redNumbers,
                        onHover: _handleHover,
                        onHoverEnd: _handleHoverEnd,
                        deleteMode: widget.deleteMode,
                        onClearZone: widget.onClearZone,
                        isMine: widget.myBets?.containsKey('red') ?? true,
                        isCompact: widget.isCompact,
                      ),
                      OutsideBetCell(
                        label: 'Black',
                        betId: 'black',
                        bet: widget.bets['black'],
                        onPlace: () => widget.onPlaceBet('black'),
                        onRemove: () => widget.onRemoveBet('black'),
                        disabled: widget.disabled,
                        isWinner: _isBetWinner('black'),
                        backgroundColor: const Color(0xFF1E1E1E),
                        textStyle: GoogleFonts.inter(
                          fontSize: widget.isCompact ? 9 : 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                        phase: widget.phase,
                        numbers: blackNumbers,
                        onHover: _handleHover,
                        onHoverEnd: _handleHoverEnd,
                        deleteMode: widget.deleteMode,
                        onClearZone: widget.onClearZone,
                        isMine: widget.myBets?.containsKey('black') ?? true,
                        isCompact: widget.isCompact,
                      ),
                      OutsideBetCell(
                        label: 'Odd',
                        betId: 'odd',
                        bet: widget.bets['odd'],
                        onPlace: () => widget.onPlaceBet('odd'),
                        onRemove: () => widget.onRemoveBet('odd'),
                        disabled: widget.disabled,
                        isWinner: _isBetWinner('odd'),
                        phase: widget.phase,
                        numbers: oddNumbers,
                        onHover: _handleHover,
                        onHoverEnd: _handleHoverEnd,
                        deleteMode: widget.deleteMode,
                        onClearZone: widget.onClearZone,
                        isMine: widget.myBets?.containsKey('odd') ?? true,
                        isCompact: widget.isCompact,
                      ),
                      OutsideBetCell(
                        label: '19-36',
                        betId: 'high',
                        bet: widget.bets['high'],
                        onPlace: () => widget.onPlaceBet('high'),
                        onRemove: () => widget.onRemoveBet('high'),
                        disabled: widget.disabled,
                        isWinner: _isBetWinner('high'),
                        phase: widget.phase,
                        numbers: highNumbers,
                        onHover: _handleHover,
                        onHoverEnd: _handleHoverEnd,
                        deleteMode: widget.deleteMode,
                        onClearZone: widget.onClearZone,
                        isMine: widget.myBets?.containsKey('high') ?? true,
                        isCompact: widget.isCompact,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: colWidth),
            ],
          ),
        ),
        ],
      ),

      // Floating highlight overlay for targeting count
      if (_hoveredBetId != null && _hoveredNumbers.isNotEmpty)
        Positioned(
          left: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Targeting: ${_hoveredNumbers.length} numbers',
              style: GoogleFonts.inter(
                color: AppColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}
