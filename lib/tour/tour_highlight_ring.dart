/// Spotlight overlay — Dart port of the web `TourHighlightRing`.
/// Dims the whole screen, punches a rounded cutout around the target so the
/// real widget beneath stays tappable, and frames it with a pulsing gold ring.
library;

import 'package:flutter/material.dart';

const _kGold = Color(0xFFC9A44C);
const _kGoldBright = Color(0xFFFFD700);
const double _kPad = 8.0;
const double _kRadius = 14.0;

class TourHighlightRing extends StatefulWidget {
  /// Target rect in global coords, or null while the target is being measured.
  final Rect? targetRect;

  const TourHighlightRing({super.key, required this.targetRect});

  @override
  State<TourHighlightRing> createState() => _TourHighlightRingState();
}

class _TourHighlightRingState extends State<TourHighlightRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rect = widget.targetRect;

    // The spotlight is purely visual — it NEVER blocks pointers. Blocking taps
    // outside the hole trapped dropdown menus (they open outside the spotlight)
    // and prevented the user from scrolling the page to follow the target.
    if (rect == null) {
      return const Positioned.fill(
        child: IgnorePointer(
          child: ColoredBox(color: Color(0xAD000000)),
        ),
      );
    }

    final hole = Rect.fromLTWH(
      (rect.left - _kPad).clamp(0.0, size.width),
      (rect.top - _kPad).clamp(0.0, size.height),
      rect.width + _kPad * 2,
      rect.height + _kPad * 2,
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Dim + rounded cutout.
            CustomPaint(
              size: size,
              painter: _DimPainter(hole),
            ),
            // Pulsing gold ring. The glow is clipped to the OUTSIDE of the hole
            // so it never washes over the target's interior text (mirrors the
            // web's outset CSS box-shadow, which never paints under the element).
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_pulse.value);
                return CustomPaint(
                  size: size,
                  painter: _RingPainter(hole, t),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DimPainter extends CustomPainter {
  final Rect hole;
  _DimPainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final cut = Path()
      ..addRRect(RRect.fromRectAndRadius(
          hole, const Radius.circular(_kRadius)));
    final dimmed = Path.combine(PathOperation.difference, full, cut);
    canvas.drawPath(dimmed, Paint()..color = const Color(0xAD000000));
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.hole != hole;
}

/// Paints the gold focus ring: a crisp border on the hole edge plus an outer
/// glow that is clipped to the region OUTSIDE the hole, so the target's own
/// content beneath (button label, etc.) is never dimmed or washed out.
class _RingPainter extends CustomPainter {
  final Rect hole;
  final double t;
  _RingPainter(this.hole, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect =
        RRect.fromRectAndRadius(hole, const Radius.circular(_kRadius));

    // Outer glow — restrict painting to everything OUTSIDE the rounded hole.
    canvas.save();
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(rrect),
    );
    canvas.clipPath(outside);
    final glowPaint = Paint()
      ..color = Color.lerp(
          const Color(0xB3C9A44C), const Color(0xF2FFD700), t)!
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 5 * t);
    canvas.drawRRect(rrect, glowPaint);
    canvas.restore();

    // Crisp gold border framing the element.
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 + 1.5 * t
      ..color = Color.lerp(_kGold, _kGoldBright, t)!;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.hole != hole || old.t != t;
}
