/// Animated guide mascot — Dart port of the web `TourGuideCharacter`.
/// Picks an expression image from the current step id, shows a circular
/// gold-rimmed avatar with a gentle floating hover animation.
library;

import 'package:flutter/material.dart';

const _kGold = Color(0xFFC9A44C);
const _kDarkGreen = Color(0xFF0F2E21);

class TourGuideCharacter extends StatefulWidget {
  final String stepId;
  final String side; // 'left' | 'right'
  final double size;

  const TourGuideCharacter({
    super.key,
    this.stepId = '',
    this.side = 'left',
    this.size = 96,
  });

  @override
  State<TourGuideCharacter> createState() => _TourGuideCharacterState();
}

class _TourGuideCharacterState extends State<TourGuideCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hover =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
        ..repeat(reverse: true);

  String get _imageAsset {
    final id = widget.stepId;
    if (id == 'lib_graduation' ||
        id == 'sim_grade' ||
        id.contains('success') ||
        id.contains('complete')) {
      return 'assets/images/character/guide_success.png';
    }
    if (id == 'lib_welcome' ||
        id == 'sim_run' ||
        id == 'debug_spin' ||
        id.contains('spin')) {
      return 'assets/images/character/guide_excited.png';
    }
    return 'assets/images/character/guide_talking.png';
  }

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kDarkGreen,
        border: Border.all(color: _kGold, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 22, offset: Offset(0, 10)),
          BoxShadow(color: Color(0x59C9A44C), blurRadius: 20),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Transform.flip(
        flipX: widget.side == 'right',
        child: Image.asset(_imageAsset, fit: BoxFit.cover),
      ),
    );

    return AnimatedBuilder(
      animation: _hover,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_hover.value);
        return Transform.translate(offset: Offset(0, -8 * t), child: child);
      },
      child: avatar,
    );
  }
}
