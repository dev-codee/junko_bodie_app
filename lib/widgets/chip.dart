import 'package:flutter/material.dart';
import 'package:junko_bodie/config/theme.dart';

/// Helper to lighten a color using HSL light adjustment.
Color lighten(Color color, [double amount = 0.15]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

/// Helper to darken a color using HSL light adjustment.
Color darken(Color color, [double amount = 0.25]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

/// A CustomPainter that draws the premium 3D roulette chip design.
/// Matches the web app's design with segmented stripes, brass ring, and hub.
class ChipPainter extends CustomPainter {
  final Color color;
  final bool isSelected;

  ChipPainter({
    required this.color,
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Draw 3D Radial Gradient Base (light source at 35%/35%)
    final basePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [
          lighten(color, 0.15),
          color,
          darken(color, 0.25),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, basePaint);

    // 1b. Inset depth — top highlight + bottom shadow (mirrors the web's
    // inset box-shadows for a rounded, 3D plastic look).
    final insetPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.22),
          Colors.transparent,
          Colors.black.withOpacity(0.30),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, insetPaint);

    // 2. Draw Outer Border
    final borderPaint = Paint()
      ..color = darken(color, 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 0.5, borderPaint);

    // 3. Draw Segmented Casino Edge Stripes (12 stripes around the rim)
    final stripePaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 12; i++) {
      if (i % 2 == 0) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(i * 30 * 3.14159265 / 180);
        // Draw small segment rectangle at the top edge of the circle
        final segmentRect = Rect.fromLTWH(
          -size.width * 0.04,
          -radius,
          size.width * 0.08,
          size.width * 0.15,
        );
        canvas.drawRect(segmentRect, stripePaint);
        canvas.restore();
      }
    }

    // 4. Draw Brass / Gold Inlaid Ring (inset 12%)
    final brassPaint = Paint()
      ..color = isSelected ? AppColors.gold : Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius * 0.76, brassPaint);

    // 5. Draw Dashed Decorative Ring (inset 22%)
    final dashedPaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, radius * 0.56, dashedPaint);

    // 6. Draw Inner Hub (inset 28%)
    final hubRect = Rect.fromCircle(center: center, radius: radius * 0.44);
    final hubPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          lighten(color, 0.05),
          darken(color, 0.10),
        ],
      ).createShader(hubRect)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.44, hubPaint);

    // Hub border
    final hubBorderPaint = Paint()
      ..color = darken(color, 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.44, hubBorderPaint);
  }

  @override
  bool shouldRepaint(covariant ChipPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isSelected != isSelected;
  }
}

/// Premium individual roulette chip widget.
class ChipWidget extends StatelessWidget {
  final double value;
  final Color color;
  final Color textColor;
  final String label;
  final bool isSelected;
  final double size;
  final VoidCallback? onClick;

  const ChipWidget({
    super.key,
    required this.value,
    required this.color,
    required this.textColor,
    required this.label,
    this.isSelected = false,
    this.size = 56,
    this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClick,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Dynamic Glow Backdrop (Selected Only)
          if (isSelected)
            Positioned(
              child: Container(
                width: size * 1.3,
                height: size * 1.3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),

          // 2. Chip Body Canvas
          CustomPaint(
            size: Size(size, size),
            painter: ChipPainter(
              color: color,
              isSelected: isSelected,
            ),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                // 3. Denomination Text inside Inner Hub
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: playfairDisplay(
                        fontSize: size * 0.22,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ).copyWith(
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.6),
                            offset: const Offset(0, 1.5),
                            blurRadius: 2.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. External Selected Gold Indicator Ring
          if (isSelected)
            Positioned(
              left: -4,
              top: -4,
              right: -4,
              bottom: -4,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold,
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
