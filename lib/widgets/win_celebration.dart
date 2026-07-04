import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class WinCelebration extends StatefulWidget {
  final bool show;

  const WinCelebration({
    Key? key,
    required this.show,
  }) : super(key: key);

  @override
  State<WinCelebration> createState() => _WinCelebrationState();
}

class _WinCelebrationState extends State<WinCelebration> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 3));
    if (widget.show) {
      _controller.play();
    }
  }

  @override
  void didUpdateWidget(covariant WinCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show != oldWidget.show) {
      if (widget.show) {
        _controller.play();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _controller,
        blastDirection: math.pi / 2, // shoot downwards
        maxBlastForce: 12,
        minBlastForce: 4,
        emissionFrequency: 0.08,
        numberOfParticles: 25,
        gravity: 0.15,
        shouldLoop: false,
        colors: const [
          Colors.green,
          Colors.blue,
          Colors.pink,
          Colors.orange,
          Colors.purple,
          Color(0xFFC9A84C), // Gold
          Colors.white,
        ],
      ),
    );
  }
}
