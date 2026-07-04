import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:junko_bodie/logic/rng.dart';
import 'package:junko_bodie/logic/payouts.dart';

class ResultDisplay extends StatefulWidget {
  final SpinResult? result;
  final PayoutResult? payout;
  final bool visible;
  final VoidCallback onDismiss;
  final bool tournamentMode;

  const ResultDisplay({
    Key? key,
    required this.result,
    required this.payout,
    required this.visible,
    required this.onDismiss,
    this.tournamentMode = false,
  }) : super(key: key);

  @override
  State<ResultDisplay> createState() => _ResultDisplayState();
}

class _ResultDisplayState extends State<ResultDisplay> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _startDismissTimer();
    }
  }

  @override
  void didUpdateWidget(covariant ResultDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _startDismissTimer();
      } else {
        _cancelDismissTimer();
      }
    }
  }

  @override
  void dispose() {
    _cancelDismissTimer();
    super.dispose();
  }

  void _startDismissTimer() {
    _cancelDismissTimer();
    final duration = widget.tournamentMode ? 2500 : 3000;
    _dismissTimer = Timer(Duration(milliseconds: duration), () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  void _cancelDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
  }

  Color _getNumberColor(String colorStr) {
    switch (colorStr) {
      case 'red':
        return const Color(0xFFEF4444);
      case 'green':
        return const Color(0xFF10B981);
      case 'black':
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool show = widget.visible && widget.result != null;

    return IgnorePointer(
      ignoring: !show,
      child: AnimatedOpacity(
        opacity: show ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: Container(
            color: Colors.black.withOpacity(0.92),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Center(
                child: GestureDetector(
                  onTap: () {}, // Prevent dismissal when clicking center container
                  // FittedBox scales the whole panel down so it never overflows
                  // the (short) landscape height on any device.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.result != null) ...[
                          // 1. Winning Number (Spun Number)
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Radial background glow matching pocket color
                              Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getNumberColor(widget.result!.color).withOpacity(0.4),
                                      blurRadius: 80,
                                      spreadRadius: 20,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                widget.result!.displayNumber,
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  color: _getNumberColor(widget.result!.color),
                                  fontSize: widget.tournamentMode ? 110 : 130,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -2,
                                  height: 1.1,
                                  shadows: [
                                    Shadow(
                                      color: _getNumberColor(widget.result!.color).withOpacity(0.3),
                                      blurRadius: 40,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (!widget.tournamentMode) ...[
                            const SizedBox(height: 8),
                            Text(
                              'WINNING NUMBER',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                        ],

                        // 2. Net Win Display
                        if (widget.payout != null) ...[
                          Text(
                            widget.payout!.netResult >= 0 ? 'NET WIN' : 'NET LOSS',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${widget.payout!.netResult > 0 ? '+' : widget.payout!.netResult < 0 ? '-' : ''}\$',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  color: widget.payout!.netResult > 0
                                      ? const Color(0xFF4ADE80)
                                      : widget.payout!.netResult == 0
                                          ? Colors.white.withOpacity(0.7)
                                          : const Color(0xFFEF4444),
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedCounter(
                                value: widget.payout!.netResult.abs(),
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  color: widget.payout!.netResult > 0
                                      ? const Color(0xFF4ADE80)
                                      : widget.payout!.netResult == 0
                                          ? Colors.white.withOpacity(0.7)
                                          : const Color(0xFFEF4444),
                                  fontSize: 68,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // 3. Tap to Continue prompt
                        if (!widget.tournamentMode) ...[
                          const SizedBox(height: 28),
                          Text(
                            'TAP ANYWHERE TO CONTINUE',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Animated Counter Widget
// ──────────────────────────────────────────────────────────────────────────────
class AnimatedCounter extends StatefulWidget {
  final double value;
  final TextStyle style;
  final Duration duration;

  const AnimatedCounter({
    Key? key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0.0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _animation = Tween<double>(begin: 0.0, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final int displayVal = _animation.value.round();
        // format commas
        final formatted = displayVal.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            );
        return Text(
          formatted,
          style: widget.style,
        );
      },
    );
  }
}
