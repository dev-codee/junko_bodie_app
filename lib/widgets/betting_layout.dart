import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:junko_bodie/config/theme.dart';
import 'package:junko_bodie/logic/bets.dart';
import 'package:junko_bodie/logic/rng.dart';
import 'package:junko_bodie/logic/payouts.dart';
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
                        customColor: widget.bet!.customColor,
                        playerInitial: widget.bet!.playerInitial,
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
  final bool isHovered;

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
    this.isHovered = false,
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
    final bool effectiveHover = widget.isHovered || _localHovered;

    // Ensure hit area is at least 36x36 if a bet is placed so the chip is fully clickable.
    final double hitWidth = hasBet ? math.max(36.0, widget.width) : widget.width;
    final double hitHeight = hasBet ? math.max(36.0, widget.height) : widget.height;

    return Positioned(
      left: widget.left - hitWidth / 2,
      top: widget.top - hitHeight / 2,
      width: hitWidth,
      height: hitHeight,
      child: IgnorePointer(
        ignoring: widget.deleteMode && !hasBet,
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
            onTap: (widget.deleteMode && !hasBet) ? null : _handleTap,
            onLongPress: (widget.deleteMode && !hasBet) ? null : _handleLongPress,
            onSecondaryTap: (widget.deleteMode && !hasBet) ? null : _handleLongPress,
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
                    gradient: effectiveHover && !widget.disabled
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
                    isHovered: effectiveHover,
                    customColor: bet.customColor,
                    playerInitial: bet.playerInitial,
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
  final bool isHovered;

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
    this.isHovered = false,
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
    final bool effectiveHover = widget.isHovered || _isHovered;

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
                  : effectiveHover && !widget.disabled && !widget.deleteMode
                      ? AppColors.gold.withOpacity(0.18)
                      : widget.backgroundColor ?? Colors.transparent,
              border: effectiveHover
                  ? Border.all(color: AppColors.gold, width: 2.0)
                  : widget.border ?? Border.all(color: const Color(0xFF5EA896), width: 1.5),
              boxShadow: [
                if (widget.isWinner)
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.5),
                    blurRadius: 10,
                  ),
                if (effectiveHover && !widget.disabled && !widget.deleteMode)
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.35),
                    blurRadius: 6,
                    spreadRadius: 1,
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
                    isHovered: effectiveHover,
                    customColor: widget.bet!.customColor,
                    playerInitial: widget.bet!.playerInitial,
                  ),

                // Tooltip
                if (hasBet && effectiveHover && !widget.isCompact)
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
  Timer? _longPressTimer;
  bool _didLongPress = false;
  String? _currentPointerBetId;
  Offset? _pointerDownPos;
  bool _isPointerActive = false;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

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

  List<int> _getNumbersForBet(String betId) {
    if (betId.startsWith('straight-')) {
      final s = betId.substring('straight-'.length);
      if (s == '00') return [37];
      final n = int.tryParse(s);
      return n != null ? [n] : [];
    }
    if (betId.startsWith('split-')) {
      final parts = betId.substring('split-'.length).split('-');
      final nums = <int>[];
      for (final p in parts) {
        if (p == '00') {
          nums.add(37);
        } else {
          final n = int.tryParse(p);
          if (n != null) nums.add(n);
        }
      }
      return nums;
    }
    if (betId.startsWith('street-')) {
      final parts = betId.substring('street-'.length).split('-');
      return parts.map((p) => int.tryParse(p) ?? 0).where((n) => n > 0).toList();
    }
    if (betId.startsWith('corner-')) {
      final parts = betId.substring('corner-'.length).split('-');
      return parts.map((p) => int.tryParse(p) ?? 0).where((n) => n > 0).toList();
    }
    if (betId.startsWith('sixline-')) {
      final parts = betId.substring('sixline-'.length).split('-');
      if (parts.length >= 2) {
        final start = int.tryParse(parts[0]) ?? 0;
        final end = int.tryParse(parts[1]) ?? 0;
        if (start > 0 && end >= start) {
          return List.generate(end - start + 1, (i) => start + i);
        }
      }
      return [];
    }
    if (betId.startsWith('trio-')) {
      final parts = betId.substring('trio-'.length).split('-');
      return parts.map((p) => p == '00' ? 37 : (int.tryParse(p) ?? 0)).toList();
    }
    if (betId.startsWith('basket-')) {
      return widget.wheelType == WheelType.american
          ? const [0, 37, 1, 2, 3]
          : const [0, 1, 2, 3];
    }
    switch (betId) {
      case 'column-1st':
        return column1st;
      case 'column-2nd':
        return column2nd;
      case 'column-3rd':
        return column3rd;
      case 'dozen-1st':
        return dozen1st;
      case 'dozen-2nd':
        return dozen2nd;
      case 'dozen-3rd':
        return dozen3rd;
      case 'low':
        return lowNumbers;
      case 'high':
        return highNumbers;
      case 'even':
        return evenNumbers;
      case 'odd':
        return oddNumbers;
      case 'red':
        return redNumbers;
      case 'black':
        return blackNumbers;
    }
    return [];
  }

  String _getBetDisplayName(String betId) {
    if (betId.startsWith('straight-')) {
      final s = betId.substring('straight-'.length);
      return 'Number $s';
    }
    if (betId.startsWith('split-')) {
      final parts = betId.substring('split-'.length).split('-');
      return 'Split (${parts.join(' & ')})';
    }
    if (betId.startsWith('street-')) {
      final parts = betId.substring('street-'.length).split('-');
      return 'Street (${parts.join(', ')})';
    }
    if (betId.startsWith('corner-')) {
      final parts = betId.substring('corner-'.length).split('-');
      return 'Corner (${parts.join(', ')})';
    }
    if (betId.startsWith('sixline-')) {
      final parts = betId.substring('sixline-'.length).split('-');
      return 'Six Line (${parts.first} to ${parts.last})';
    }
    if (betId.startsWith('trio-')) {
      final parts = betId.substring('trio-'.length).split('-');
      return 'Trio (${parts.join(', ')})';
    }
    if (betId.startsWith('basket-')) {
      return widget.wheelType == WheelType.american
          ? 'Basket (0, 00, 1, 2, 3)'
          : 'Basket (0, 1, 2, 3)';
    }
    switch (betId) {
      case 'column-1st':
        return '1st Column (2 to 1)';
      case 'column-2nd':
        return '2nd Column (2 to 1)';
      case 'column-3rd':
        return '3rd Column (2 to 1)';
      case 'dozen-1st':
        return '1st 12';
      case 'dozen-2nd':
        return '2nd 12';
      case 'dozen-3rd':
        return '3rd 12';
      case 'low':
        return '1 - 18';
      case 'high':
        return '19 - 36';
      case 'even':
        return 'EVEN';
      case 'odd':
        return 'ODD';
      case 'red':
        return 'RED';
      case 'black':
        return 'BLACK';
    }
    return betId;
  }

  String? _resolveBetAtOffset(Offset pos, Size size) {
    if (pos.dx < 0 || pos.dx > size.width || pos.dy < 0 || pos.dy > size.height) {
      return null;
    }

    final double spacerWidth = widget.isCompact ? 32.0 : 44.0;
    final double colWidth = widget.isCompact ? 32.0 : 40.0;
    const double totalFlex = 5.0;
    final double gridHeight = size.height * (3.0 / totalFlex);
    final double dozenHeight = size.height * (1.0 / totalFlex);

    final double gridWidth = (size.width - colWidth) - spacerWidth;
    if (gridWidth <= 0) return null;

    final double cellWidth = gridWidth / 12.0;
    final double cellHeight = gridHeight / 3.0;

    // ── SECTION 3: Even Chances (1-18, Even, Red, Black, Odd, 19-36) ──
    if (pos.dy >= gridHeight + dozenHeight) {
      final double relX = pos.dx - spacerWidth;
      final double netWidth = size.width - colWidth - spacerWidth;
      if (netWidth <= 0) return null;
      final int idx = ((relX / netWidth) * 6).floor().clamp(0, 5);
      const outsideBets = ['low', 'even', 'red', 'black', 'odd', 'high'];
      return outsideBets[idx];
    }

    // ── SECTION 2: Dozens ──
    if (pos.dy >= gridHeight + 12.0) {
      final double relX = pos.dx - spacerWidth;
      final double netWidth = size.width - colWidth - spacerWidth;
      if (netWidth <= 0) return null;
      final int idx = ((relX / netWidth) * 3).floor().clamp(0, 2);
      const dozenBets = ['dozen-1st', 'dozen-2nd', 'dozen-3rd'];
      return dozenBets[idx];
    }

    // ── SECTION 1: Zeros, Numbers Grid, Columns, Streets/Sixlines ──

    // Columns block on the right
    if (pos.dx >= size.width - colWidth) {
      final int row = (pos.dy / cellHeight).floor().clamp(0, 2);
      if (row == 0) return 'column-3rd';
      if (row == 1) return 'column-2nd';
      return 'column-1st';
    }

    // Zeros block on the left
    if (pos.dx < spacerWidth - 6.0) {
      if (widget.wheelType == WheelType.american) {
        if ((pos.dy - (gridHeight / 2)).abs() < cellHeight * 0.25) {
          return 'split-0-00';
        }
        return pos.dy < gridHeight / 2 ? 'straight-00' : 'straight-0';
      } else {
        return 'straight-0';
      }
    }

    // Boundary between Zeros and Column 0 (Numbers 1, 2, 3)
    if (pos.dx < spacerWidth + 8.0) {
      if (pos.dy > gridHeight - 16.0) {
        return widget.wheelType == WheelType.american
            ? 'basket-0-00-1-2-3'
            : 'basket-0-1-2-3';
      }
      if (widget.wheelType == WheelType.american) {
        if (pos.dy < gridHeight * 0.25) return 'split-00-3';
        if ((pos.dy - gridHeight * 0.333).abs() < 14) return 'trio-00-2-3';
        if (pos.dy < gridHeight * 0.45) return 'split-00-2';
        if ((pos.dy - gridHeight * 0.50).abs() < 14) return 'trio-0-00-2';
        if (pos.dy < gridHeight * 0.62) return 'split-0-2';
        if ((pos.dy - gridHeight * 0.666).abs() < 14) return 'trio-0-1-2';
        return 'split-0-1';
      } else {
        if (pos.dy < gridHeight * 0.25) return 'split-0-3';
        if ((pos.dy - gridHeight * 0.333).abs() < 14) return 'trio-0-2-3';
        if (pos.dy < gridHeight * 0.60) return 'split-0-2';
        if ((pos.dy - gridHeight * 0.666).abs() < 14) return 'trio-0-1-2';
        return 'split-0-1';
      }
    }

    // Numbers Grid & Bottom Streets / Sixlines
    final double relX = pos.dx - spacerWidth;
    final int col = (relX / cellWidth).floor().clamp(0, 11);

    // Street & Sixline on bottom seam
    if (pos.dy >= gridHeight - 14.0 && pos.dy <= gridHeight + 12.0) {
      final double colFrac = (relX - col * cellWidth) / cellWidth;
      if (colFrac < 0.18 && col > 0) {
        final int n = (col - 1) * 3 + 1;
        return 'sixline-$n-${n + 5}';
      }
      if (colFrac > 0.82 && col < 11) {
        final int n = col * 3 + 1;
        return 'sixline-$n-${n + 5}';
      }
      final int n = col * 3 + 1;
      return 'street-$n-${n + 1}-${n + 2}';
    }

    // Inside Numbers Grid: 3 rows
    final int row = (pos.dy / cellHeight).floor().clamp(0, 2);

    final double xInCell = relX - col * cellWidth;
    final double yInCell = pos.dy - row * cellHeight;
    final double u = (xInCell / cellWidth).clamp(0.0, 1.0);
    final double v = (yInCell / cellHeight).clamp(0.0, 1.0);

    const double hMargin = 0.20;
    const double vMargin = 0.22;

    // 1) Top edge / corners
    if (v < vMargin && row > 0) {
      if (u < hMargin && col > 0) {
        final int n = (col - 1) * 3 + (3 - row);
        return 'corner-$n-${n + 1}-${n + 3}-${n + 4}';
      }
      if (u > 1.0 - hMargin && col < 11) {
        final int n = col * 3 + (3 - row);
        return 'corner-$n-${n + 1}-${n + 3}-${n + 4}';
      }
      final int n = col * 3 + (3 - row);
      return 'split-$n-${n + 1}';
    }

    // 2) Bottom edge / corners (when row < 2)
    if (v > 1.0 - vMargin && row < 2) {
      if (u < hMargin && col > 0) {
        final int n = (col - 1) * 3 + (2 - row);
        return 'corner-$n-${n + 1}-${n + 3}-${n + 4}';
      }
      if (u > 1.0 - hMargin && col < 11) {
        final int n = col * 3 + (2 - row);
        return 'corner-$n-${n + 1}-${n + 3}-${n + 4}';
      }
      final int n = col * 3 + (2 - row);
      return 'split-$n-${n + 1}';
    }

    // 3) Left edge (horizontal split with col - 1)
    if (u < hMargin && col > 0) {
      final int n = (col - 1) * 3 + (3 - row);
      return 'split-$n-${n + 3}';
    }

    // 4) Right edge (horizontal split with col + 1)
    if (u > 1.0 - hMargin && col < 11) {
      final int n = col * 3 + (3 - row);
      return 'split-$n-${n + 3}';
    }

    // 5) Center: Straight number bet!
    final int num = col * 3 + (3 - row);
    return 'straight-$num';
  }

  void _updateHover(String betId) {
    final nums = _getNumbersForBet(betId);
    setState(() {
      _hoveredBetId = betId;
      _hoveredNumbers = nums;
    });
  }

  void _clearHover() {
    if (_hoveredBetId != null || _hoveredNumbers.isNotEmpty) {
      setState(() {
        _hoveredBetId = null;
        _hoveredNumbers = const [];
        _currentPointerBetId = null;
      });
    }
  }

  void _onPointerDown(PointerDownEvent event, Size size) {
    if (widget.disabled) return;
    _isPointerActive = true;
    _didLongPress = false;
    _pointerDownPos = event.localPosition;

    final betId = _resolveBetAtOffset(event.localPosition, size);
    _currentPointerBetId = betId;
    if (betId != null) {
      _updateHover(betId);

      _longPressTimer?.cancel();
      _longPressTimer = Timer(const Duration(milliseconds: 550), () {
        if (!mounted || !_isPointerActive) return;
        if (widget.bets.containsKey(betId)) {
          widget.onRemoveBet(betId);
          _didLongPress = true;
        }
      });
    } else {
      _clearHover();
    }
  }

  void _onPointerMove(PointerMoveEvent event, Size size) {
    if (widget.disabled || !_isPointerActive) return;

    if (_pointerDownPos != null &&
        (event.localPosition - _pointerDownPos!).distance > 10.0) {
      _longPressTimer?.cancel();
    }

    final betId = _resolveBetAtOffset(event.localPosition, size);
    if (betId != _currentPointerBetId) {
      _currentPointerBetId = betId;
      if (betId != null) {
        _updateHover(betId);
      } else {
        _clearHover();
      }
    }
  }

  void _onPointerUp(PointerUpEvent event, Size size) {
    _longPressTimer?.cancel();
    final bool wasActive = _isPointerActive;
    _isPointerActive = false;
    if (!wasActive || widget.disabled) {
      _clearHover();
      return;
    }

    if (_didLongPress) {
      _didLongPress = false;
      _clearHover();
      return;
    }

    final betId = _resolveBetAtOffset(event.localPosition, size);
    if (betId != null) {
      if (widget.deleteMode) {
        if (widget.bets.containsKey(betId)) {
          widget.onClearZone?.call(betId);
        }
      } else {
        soundEngine.playChipSound();
        widget.onPlaceBet(betId);
      }

      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && !_isPointerActive) {
          _clearHover();
        }
      });
    } else {
      _clearHover();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _longPressTimer?.cancel();
    _isPointerActive = false;
    _didLongPress = false;
    _clearHover();
  }

  void _onMouseHover(PointerHoverEvent event, Size size) {
    if (widget.disabled || _isPointerActive) return;
    final betId = _resolveBetAtOffset(event.localPosition, size);
    if (betId != _currentPointerBetId) {
      _currentPointerBetId = betId;
      if (betId != null) {
        _updateHover(betId);
      } else {
        _clearHover();
      }
    }
  }

  String _targetingLabel() {
    if (_hoveredBetId == null) return '';
    final label = _getBetDisplayName(_hoveredBetId!);
    final hasBet = widget.bets.containsKey(_hoveredBetId!);

    if (widget.deleteMode) {
      if (hasBet) {
        final amount = widget.bets[_hoveredBetId!]!.amount.toInt();
        return 'X OFF: Release to REMOVE \$$amount on $label';
      } else {
        return 'X OFF: No bet on $label';
      }
    }

    if (_hoveredNumbers.length > 1) {
      return 'Release to place on $label (${_hoveredNumbers.length} numbers)';
    }
    return 'Release to place on $label';
  }

  @override
  Widget build(BuildContext context) {
    final double spacerWidth = widget.isCompact ? 32 : 44;
    final double colWidth = widget.isCompact ? 32 : 40;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _onPointerDown(e, totalSize),
          onPointerMove: (e) => _onPointerMove(e, totalSize),
          onPointerUp: (e) => _onPointerUp(e, totalSize),
          onPointerCancel: _onPointerCancel,
          child: MouseRegion(
            onHover: (e) => _onMouseHover(e, totalSize),
            onExit: (_) {
              if (!_isPointerActive) _clearHover();
            },
            child: Container(
              padding: const EdgeInsets.all(4.0),
              child: Stack(
                children: [
                  IgnorePointer(
                    ignoring: true,
                    child: Column(
                      children: [
                        // ── SECTION 1: Zeros, Numbers Grid, Columns ──
                        Expanded(
                          flex: 3,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final totalWidth = constraints.maxWidth;
                                    final gridHeight = constraints.maxHeight;
                                    final gridWidth = totalWidth - spacerWidth;

                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        // Background Grid & Zeros Row
                                        Row(
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
                                                              width: 32,
                                                              height: 32,
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
                                                              isHovered: _hoveredBetId == 'split-0-00',
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
                                                child: Column(
                                                  children: gridRows.map((row) {
                                                    return Expanded(
                                                      child: Row(
                                                        children: row.map((number) {
                                                          final betId = 'straight-$number';
                                                          return NumberCell(
                                                            num: number,
                                                            bet: widget.bets[betId],
                                                            onPlace: () => widget.onPlaceBet(betId),
                                                            onRemove: () => widget.onRemoveBet(betId),
                                                            disabled: widget.disabled,
                                                            isWinner: _isWinningNumber(number) || _isBetWinner(betId),
                                                            phase: widget.phase,
                                                            isHovered: _hoveredNumbers.contains(number) || _selfHoveredNumber == number,
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
                                              ),
                                            ),
                                          ],
                                        ),

                                        // ── COMBINATION BETS OVERLAY (STREETS, SPLITS, CORNERS, SIXLINES) ──
                                        // Horizontal Splits
                                        ...[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33].map((n) {
                                          final betId = 'split-$n-${n + 3}';
                                          final col = (n - 1) ~/ 3;
                                          final row = 2 - ((n - 1) % 3);
                                          final left = spacerWidth + (col + 1) * (gridWidth / 12);
                                          final top = (row + 0.5) * (gridHeight / 3);

                                          return DropZone(
                                            key: ValueKey(betId),
                                            betId: betId,
                                            left: left,
                                            top: top,
                                            width: 32,
                                            height: 32,
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
                                            isHovered: _hoveredBetId == betId,
                                          );
                                        }),

                                        // Vertical Splits
                                        ...[1, 2, 4, 5, 7, 8, 10, 11, 13, 14, 16, 17, 19, 20, 22, 23, 25, 26, 28, 29, 31, 32, 34, 35].map((n) {
                                          final betId = 'split-$n-${n + 1}';
                                          final col = (n - 1) ~/ 3;
                                          final row = 2 - ((n - 1) % 3);
                                          final left = spacerWidth + (col + 0.5) * (gridWidth / 12);
                                          final top = row * (gridHeight / 3);

                                          return DropZone(
                                            key: ValueKey(betId),
                                            betId: betId,
                                            left: left,
                                            top: top,
                                            width: 32,
                                            height: 32,
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
                                            isHovered: _hoveredBetId == betId,
                                          );
                                        }),

                                        // Corner Bets
                                        ...[1, 2, 4, 5, 7, 8, 10, 11, 13, 14, 16, 17, 19, 20, 22, 23, 25, 26, 28, 29, 31, 32].map((n) {
                                          final betId = 'corner-$n-${n + 1}-${n + 3}-${n + 4}';
                                          final col = (n - 1) ~/ 3;
                                          final row = 2 - ((n - 1) % 3);
                                          final left = spacerWidth + (col + 1) * (gridWidth / 12);
                                          final top = row * (gridHeight / 3);

                                          return DropZone(
                                            key: ValueKey(betId),
                                            betId: betId,
                                            left: left,
                                            top: top,
                                            width: 32,
                                            height: 32,
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
                                            isHovered: _hoveredBetId == betId,
                                          );
                                        }),

                                        // Street Bets
                                        ...[1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34].map((n) {
                                          final betId = 'street-$n-${n + 1}-${n + 2}';
                                          final col = (n - 1) ~/ 3;
                                          final left = spacerWidth + (col + 0.5) * (gridWidth / 12);
                                          final top = gridHeight;

                                          return DropZone(
                                            key: ValueKey(betId),
                                            betId: betId,
                                            left: left,
                                            top: top,
                                            width: 24,
                                            height: 32,
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
                                            isHovered: _hoveredBetId == betId,
                                          );
                                        }),

                                        // Sixline Bets
                                        ...[1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31].map((n) {
                                          final betId = 'sixline-$n-${n + 5}';
                                          final col = (n - 1) ~/ 3;
                                          final left = spacerWidth + (col + 1) * (gridWidth / 12);
                                          final top = gridHeight;

                                          return DropZone(
                                            key: ValueKey(betId),
                                            betId: betId,
                                            left: left,
                                            top: top,
                                            width: 24,
                                            height: 32,
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
                                            isHovered: _hoveredBetId == betId,
                                          );
                                        }),

                                        // Boundary splits with Zero
                                        DropZone(betId: 'split-0-1', left: spacerWidth, top: gridHeight * 0.833, width: 44, height: 44, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('split-0-1'), phase: widget.phase, numbers: const [0, 1], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('split-0-1') ?? true, isHovered: _hoveredBetId == 'split-0-1'),
                                        DropZone(betId: 'split-0-2', left: spacerWidth, top: widget.wheelType == WheelType.american ? gridHeight * 0.60 : gridHeight * 0.50, width: 44, height: 44, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('split-0-2'), phase: widget.phase, numbers: const [0, 2], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('split-0-2') ?? true, isHovered: _hoveredBetId == 'split-0-2'),
                                        if (widget.wheelType == WheelType.american) ...[
                                          DropZone(betId: 'split-00-2', left: spacerWidth, top: gridHeight * 0.40, width: 44, height: 44, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('split-00-2'), phase: widget.phase, numbers: const [37, 2], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('split-00-2') ?? true, isHovered: _hoveredBetId == 'split-00-2'),
                                          DropZone(betId: 'split-00-3', left: spacerWidth, top: gridHeight * 0.166, width: 44, height: 44, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('split-00-3'), phase: widget.phase, numbers: const [37, 3], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('split-00-3') ?? true, isHovered: _hoveredBetId == 'split-00-3'),
                                        ] else ...[
                                          DropZone(betId: 'split-0-3', left: spacerWidth, top: gridHeight * 0.166, width: 44, height: 44, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('split-0-3'), phase: widget.phase, numbers: const [0, 3], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('split-0-3') ?? true, isHovered: _hoveredBetId == 'split-0-3'),
                                        ],

                                        // Trio & Basket
                                        DropZone(betId: 'trio-0-1-2', left: spacerWidth, top: gridHeight * 0.666, width: 44, height: 44, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('trio-0-1-2'), phase: widget.phase, numbers: const [0, 1, 2], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('trio-0-1-2') ?? true, isHovered: _hoveredBetId == 'trio-0-1-2'),
                                        DropZone(betId: 'trio-0-2-3', left: spacerWidth, top: gridHeight * 0.333, width: 44, height: 44, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('trio-0-2-3'), phase: widget.phase, numbers: const [0, 2, 3], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('trio-0-2-3') ?? true, isHovered: _hoveredBetId == 'trio-0-2-3'),
                                        if (widget.wheelType == WheelType.american) ...[
                                          DropZone(betId: 'trio-00-2-3', left: spacerWidth, top: gridHeight * 0.333, width: 44, height: 44, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('trio-00-2-3'), phase: widget.phase, numbers: const [37, 2, 3], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('trio-00-2-3') ?? true, isHovered: _hoveredBetId == 'trio-00-2-3'),
                                          DropZone(betId: 'trio-0-00-2', left: spacerWidth, top: gridHeight * 0.50, width: 44, height: 44, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('trio-0-00-2'), phase: widget.phase, numbers: const [0, 37, 2], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('trio-0-00-2') ?? true, isHovered: _hoveredBetId == 'trio-0-00-2'),
                                          DropZone(betId: 'basket-0-00-1-2-3', left: spacerWidth, top: gridHeight, width: 44, height: 44, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('basket-0-00-1-2-3'), phase: widget.phase, numbers: const [0, 37, 1, 2, 3], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('basket-0-00-1-2-3') ?? true, isHovered: _hoveredBetId == 'basket-0-00-1-2-3'),
                                        ] else ...[
                                          DropZone(betId: 'basket-0-1-2-3', left: spacerWidth, top: gridHeight, width: 44, height: 44, bets: widget.bets, onPlace: widget.onPlaceBet, onRemove: widget.onRemoveBet, disabled: widget.disabled, isWinner: _isBetWinner('basket-0-1-2-3'), phase: widget.phase, numbers: const [0, 1, 2, 3], onHover: _handleHover, onHoverEnd: _handleHoverEnd, deleteMode: widget.deleteMode, onPopLastChip: widget.onPopLastChip, onClearZone: widget.onClearZone, isMine: widget.myBets?.containsKey('basket-0-1-2-3') ?? true, isHovered: _hoveredBetId == 'basket-0-1-2-3'),
                                        ],
                                      ],
                                    );
                                  },
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
                                      isHovered: _hoveredBetId == 'column-3rd',
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
                                      isHovered: _hoveredBetId == 'column-2nd',
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
                                      isHovered: _hoveredBetId == 'column-1st',
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
                                        border: const Border(
                                          right: BorderSide(color: Color(0xFF5EA896), width: 1.5),
                                        ),
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
                                        isHovered: _hoveredBetId == 'dozen-1st',
                                      ),
                                      OutsideBetCell(
                                        label: '2nd 12',
                                        betId: 'dozen-2nd',
                                        border: const Border(
                                          right: BorderSide(color: Color(0xFF5EA896), width: 1.5),
                                        ),
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
                                        isHovered: _hoveredBetId == 'dozen-2nd',
                                      ),
                                      OutsideBetCell(
                                        label: '3rd 12',
                                        betId: 'dozen-3rd',
                                        border: const Border(),
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
                                        isHovered: _hoveredBetId == 'dozen-3rd',
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
                                        isHovered: _hoveredBetId == 'low',
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
                                        isHovered: _hoveredBetId == 'even',
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
                                        isHovered: _hoveredBetId == 'red',
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
                                        isHovered: _hoveredBetId == 'black',
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
                                        isHovered: _hoveredBetId == 'odd',
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
                                        isHovered: _hoveredBetId == 'high',
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
                  ),

                  // Floating highlight overlay for targeting banner
                  if (_hoveredBetId != null)
                    Positioned(
                      top: 6,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: widget.deleteMode
                                  ? const Color(0xFF5A1010).withOpacity(0.92)
                                  : Colors.black.withOpacity(0.88),
                              border: Border.all(
                                color: widget.deleteMode
                                    ? Colors.redAccent
                                    : AppColors.gold,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.deleteMode
                                      ? Colors.red.withOpacity(0.4)
                                      : AppColors.gold.withOpacity(0.35),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.deleteMode
                                      ? Icons.remove_circle_outline
                                      : Icons.touch_app,
                                  size: 14,
                                  color: widget.deleteMode ? Colors.white : AppColors.gold,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _targetingLabel(),
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
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
          ),
        );
      },
    );
  }
}
