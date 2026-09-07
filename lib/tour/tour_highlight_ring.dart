/// Spotlight overlay — Dart port of the web `TourHighlightRing`.
/// Dims the whole screen, punches a rounded cutout around the target so the
/// real widget beneath stays tappable, and frames it with a pulsing gold ring.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const _kGold = Color(0xFFC9A44C);
const _kGoldBright = Color(0xFFFFD700);
const double _kPad = 8.0;
const double _kRadius = 14.0;

class TourHighlightRing extends StatefulWidget {
  /// Target rect in global coords, or null while the target is being measured.
  final Rect? targetRect;

  /// Extra rects to spotlight alongside [targetRect] (e.g. the toolbar buttons
  /// referenced by a "place your bets" step). Each gets its own cutout + ring.
  final List<Rect> extraRects;

  const TourHighlightRing(
      {super.key, required this.targetRect, this.extraRects = const []});

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

    Rect padHole(Rect r) => Rect.fromLTWH(
          (r.left - _kPad).clamp(0.0, size.width),
          (r.top - _kPad).clamp(0.0, size.height),
          r.width + _kPad * 2,
          r.height + _kPad * 2,
        );

    final holes = <Rect>[padHole(rect), for (final r in widget.extraRects) padHole(r)];

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Dim + rounded cutouts.
            CustomPaint(
              size: size,
              painter: _DimPainter(holes),
            ),
            // Pulsing gold rings. The glow is clipped to the OUTSIDE of the
            // holes so it never washes over the targets' interior text (mirrors
            // the web's outset CSS box-shadow, which never paints under it).
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_pulse.value);
                return CustomPaint(
                  size: size,
                  painter: _RingPainter(holes, t),
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
  final List<Rect> holes;
  _DimPainter(this.holes);

  @override
  void paint(Canvas canvas, Size size) {
    final cut = Path();
    for (final hole in holes) {
      cut.addRRect(
          RRect.fromRectAndRadius(hole, const Radius.circular(_kRadius)));
    }
    final full = Path()..addRect(Offset.zero & size);
    final dimmed = Path.combine(PathOperation.difference, full, cut);
    canvas.drawPath(dimmed, Paint()..color = const Color(0xAD000000));
  }

  @override
  bool shouldRepaint(_DimPainter old) => !listEquals(old.holes, holes);
}

/// Paints the gold focus ring: a crisp border on the hole edge plus an outer
/// glow that is clipped to the region OUTSIDE the hole, so the target's own
/// content beneath (button label, etc.) is never dimmed or washed out.
class _RingPainter extends CustomPainter {
  final List<Rect> holes;
  final double t;
  _RingPainter(this.holes, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Outer glow — restrict painting to everything OUTSIDE all rounded holes.
    final allHoles = Path();
    for (final hole in holes) {
      allHoles
          .addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(_kRadius)));
    }
    canvas.save();
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      allHoles,
    );
    canvas.clipPath(outside);
    final glowPaint = Paint()
      ..color = Color.lerp(
          const Color(0xB3C9A44C), const Color(0xF2FFD700), t)!
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 5 * t);
    for (final hole in holes) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(hole, const Radius.circular(_kRadius)),
          glowPaint);
    }
    canvas.restore();

    // Crisp gold border framing each element.
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 + 1.5 * t
      ..color = Color.lerp(_kGold, _kGoldBright, t)!;
    for (final hole in holes) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(hole, const Radius.circular(_kRadius)),
          borderPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.t != t || !listEquals(old.holes, holes);
}
