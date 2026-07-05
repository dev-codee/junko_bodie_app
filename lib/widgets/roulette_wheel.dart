import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:junko_bodie/audio/audio_engine.dart';
import 'package:junko_bodie/logic/rng.dart';

class RouletteWheel extends StatefulWidget {
  final WheelType wheelType;
  final SpinResult? spinResult;
  final bool isSpinning;
  final VoidCallback onSpinComplete;
  final double size;
  final bool tournamentMode;

  const RouletteWheel({
    Key? key,
    required this.wheelType,
    required this.spinResult,
    required this.isSpinning,
    required this.onSpinComplete,
    this.size = 320.0,
    this.tournamentMode = false,
  }) : super(key: key);

  @override
  State<RouletteWheel> createState() => _RouletteWheelState();
}

// Physics constants
const double BALL_ORBIT_START = 0.88;
const double BALL_ORBIT_END = 0.50;
const double SPIN_DURATION = 4000.0;
const double BALL_SETTLE_AT = 0.68;

class _RouletteWheelState extends State<RouletteWheel> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  late Stopwatch _stopwatch;

  // Physics state variables
  double _wheelAngle = 0.0;
  double _ballAngle = 0.0;
  double _ballRadius = BALL_ORBIT_START;
  double _ballZ = 0.0;

  bool _spinning = false;
  bool _ballSettled = false;
  double _spinStartTime = 0.0;
  double _targetAngle = 0.0;
  double _startWheelAngle = 0.0;
  double _startBallAngle = 0.0;
  double _targetBallAngle = 0.0;
  double _wobble = 0.0;

  double _lastTickTime = 0.0;
  String? _lastTriggeredResultId;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();

    _ticker = createTicker(_onTick);
    _ticker.start();

    // If this wheel is created already in the spinning state (e.g. the widget
    // tree was rebuilt when we switched to the full-screen spin layout), kick
    // off the spin here — otherwise only didUpdateWidget would trigger it and
    // the wheel would sit stuck at the result.
    if (widget.isSpinning && widget.spinResult != null) {
      _ballRadius = BALL_ORBIT_START;
      _ballSettled = false;
      _lastTriggeredResultId = widget.spinResult!.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _triggerSpin(widget.spinResult!.number);
      });
    } else {
      // Otherwise place the ball at the result (settled) or in idle orbit.
      _initializeBallPosition();
    }
  }

  void _initializeBallPosition() {
    if (widget.spinResult != null) {
      final pockets = widget.wheelType == WheelType.american
          ? RNG.americanWheelOrder
          : RNG.europeanWheelOrder;
      final sectorAngle = (math.pi * 2) / pockets.length;
      final pocketIndex = pockets.indexOf(widget.spinResult!.number);
      if (pocketIndex != -1) {
        final double pocketAngle = pocketIndex * sectorAngle + sectorAngle / 2.0;
        _wheelAngle = 0.0;
        _ballAngle = pocketAngle - math.pi / 2.0;
        _ballRadius = BALL_ORBIT_END;
        _ballSettled = true;
        _lastTriggeredResultId = widget.spinResult!.id;
      }
    } else {
      _ballRadius = BALL_ORBIT_START;
      _ballSettled = false;
    }
  }

  @override
  void didUpdateWidget(covariant RouletteWheel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If wheel type changes, re-init ball position
    if (widget.wheelType != oldWidget.wheelType) {
      _initializeBallPosition();
    }

    final resultKey = widget.spinResult?.id;
    if (widget.isSpinning && widget.spinResult != null && _lastTriggeredResultId != resultKey) {
      _lastTriggeredResultId = resultKey;
      _triggerSpin(widget.spinResult!.number);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _mod(double value, double modulus) {
    return ((value % modulus) + modulus) % modulus;
  }

  double _easeOutQuad(double t) {
    return 1.0 - (1.0 - t) * (1.0 - t);
  }

  double _easeOutCubic(double t) {
    return 1.0 - math.pow(1.0 - t, 3).toDouble();
  }

  void _triggerSpin(int targetPocket) {
    final pockets = widget.wheelType == WheelType.american
        ? RNG.americanWheelOrder
        : RNG.europeanWheelOrder;
    final sectorAngle = (math.pi * 2) / pockets.length;
    final pocketIndex = pockets.indexOf(targetPocket);
    if (pocketIndex == -1) return;

    final double pocketAngle = pocketIndex * sectorAngle + sectorAngle / 2.0;
    final double targetWheelStop = _wheelAngle + (math.pi * 2) * 5.0 + math.Random().nextDouble() * (math.pi * 2);
    final double finalPocketScreenAngle = pocketAngle - math.pi / 2.0 + targetWheelStop;

    double targetBallAngleVal = finalPocketScreenAngle;
    while (targetBallAngleVal > _ballAngle - (math.pi * 2) * 3.0) {
      targetBallAngleVal -= (math.pi * 2);
    }

    setState(() {
      _spinning = true;
      _ballSettled = false;
      _spinStartTime = _stopwatch.elapsedMilliseconds.toDouble();
      _startWheelAngle = _wheelAngle;
      _targetAngle = targetWheelStop;
      _startBallAngle = _ballAngle;
      _targetBallAngle = targetBallAngleVal;
      _ballRadius = BALL_ORBIT_START;
      _ballZ = 0.0;
      _wobble = 0.0;
      _lastTickTime = 0.0;
    });

    soundEngine.startSpinSound();
  }

  void _onTick(Duration elapsed) {
    final double now = _stopwatch.elapsedMilliseconds.toDouble();
    final pockets = widget.wheelType == WheelType.american
        ? RNG.americanWheelOrder
        : RNG.europeanWheelOrder;
    final double sectorAngle = (math.pi * 2) / pockets.length;

    if (_spinning) {
      final double timeElapsed = now - _spinStartTime;
      final double t = (timeElapsed / SPIN_DURATION).clamp(0.0, 1.0);

      // Sound effect adjustments
      final double baseVol = 0.25 - (t * 0.2);
      final double endFade = t > 0.96 ? (1.0 - t) / 0.04 : 1.0;
      final double soundVol = math.max(0.0, baseVol * endFade);
      final double soundRate = 1.0 - (t * 0.5);
      soundEngine.setSpinEffect(soundVol, soundRate);

      // Track relative movement for sector crossing sounds (wheel ticks)
      final double prevRelative = _mod(_ballAngle - _wheelAngle, math.pi * 2);
      final int prevIdx = (prevRelative / sectorAngle).floor();

      // Update angles
      _wheelAngle = _startWheelAngle + (_targetAngle - _startWheelAngle) * _easeOutQuad(t);
      _ballAngle = _startBallAngle + (_targetBallAngle - _startBallAngle) * _easeOutQuad(t);

      final double newRelative = _mod(_ballAngle - _wheelAngle, math.pi * 2);
      final int newIdx = (newRelative / sectorAngle).floor();

      // Play tick sounds when ball crosses a divider
      final double tickThreshold = 40.0 + (t * 160.0);
      if (prevIdx != newIdx && t > 0.02 && t < 0.94) {
        if (now - _lastTickTime > tickThreshold) {
          soundEngine.playWheelTick();
          _lastTickTime = now;
        }
      }

      // Settle phase
      if (t > BALL_SETTLE_AT) {
        final double dropT = (t - BALL_SETTLE_AT) / (1.0 - BALL_SETTLE_AT);
        final double spiralT = _easeOutCubic(dropT);
        _ballRadius = BALL_ORBIT_START - (BALL_ORBIT_START - BALL_ORBIT_END) * spiralT;

        if (dropT < 0.85) {
          final double bounceFreq = dropT * 18.0;
          final double decay = math.pow(1.0 - dropT * 0.9, 2.5).toDouble();
          final double bounceHeight = (math.sin(bounceFreq * math.pi)).abs() * decay * 28.0;
          _ballZ = bounceHeight;

          // Wobble effect
          if (bounceHeight > 2.0) {
            final double wobbleAmount = bounceHeight * 0.003;
            _ballRadius += math.sin(bounceFreq * 3.0) * wobbleAmount;
          }

          if (bounceHeight < 2.0 && _ballZ < 3.0) {
            _wobble = (math.Random().nextDouble() - 0.5) * 0.01;
            _ballAngle += _wobble;
            if (now - _lastTickTime > 150.0 && math.Random().nextDouble() > 0.6) {
              soundEngine.playWheelTick();
              _lastTickTime = now;
            }
          } else {
            _wobble *= 0.85;
          }
        } else {
          // Lock final position
          final double settleT = (dropT - 0.85) / 0.15;
          _ballZ *= (1.0 - settleT);
          if (_ballZ < 0.05) _ballZ = 0.0;
          _wobble = 0.0;
          _ballRadius = BALL_ORBIT_END;
          final double lockStrength = _easeOutCubic(settleT) * 0.15;
          _ballAngle = _ballAngle * (1.0 - lockStrength) + _targetBallAngle * lockStrength;
        }
      } else {
        _ballRadius = BALL_ORBIT_START;
        _ballZ = 0.0;
        _wobble = 0.0;
      }

      // Spin end
      if (t >= 1.0) {
        setState(() {
          _spinning = false;
          _ballSettled = true;
          _wheelAngle = _targetAngle;
          _ballAngle = _targetBallAngle;
          _ballRadius = BALL_ORBIT_END;
          _ballZ = 0.0;
        });

        // stopSpinSound() already unducks the background music. Restarting the
        // track here (as the old code did for solo) caused the loop to jump
        // back to the start after every spin, so we just let it resume.
        soundEngine.stopSpinSound();
        if (widget.tournamentMode) {
          soundEngine.resumeTourneyBackgroundMusic();
        }
        widget.onSpinComplete();
      } else {
        setState(() {}); // repaint
      }
    } else {
      // Idle slow spin
      setState(() {
        if (!_ballSettled) {
          _wheelAngle += 0.0008;
          _ballAngle -= 0.0005;
        } else {
          _wheelAngle += 0.0008;
          _ballAngle += 0.0008;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 3D Shadow Backdrop
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(widget.size * 0.03),
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0007)
                  ..rotateX(80.0 * math.pi / 180.0)
                  ..translate(0.0, 0.0, -12.0),
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.4),
                      radius: 0.5,
                      colors: [
                        Color(0xFF935A2D),
                        Color(0xFF5F351B),
                        Color(0xFF2C140A),
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.48),
                        blurRadius: 28,
                        offset: const Offset(0, 28),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Rotating Wheel Canvas
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0007)
              ..rotateX(14.0 * math.pi / 180.0)
              ..translate(0.0, 0.0, 8.0),
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 60,
                  ),
                  BoxShadow(
                    color: const Color(0xFFB48C00).withOpacity(0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: CustomPaint(
                size: Size(widget.size, widget.size),
                painter: RouletteWheelPainter(
                  wheelType: widget.wheelType,
                  wheelAngle: _wheelAngle,
                  ballAngle: _ballAngle,
                  ballRadius: _ballRadius,
                  ballZ: _ballZ,
                  isSpinning: _spinning,
                  spinStartTime: _spinStartTime,
                  stopwatch: _stopwatch,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RouletteWheelPainter extends CustomPainter {
  final WheelType wheelType;
  final double wheelAngle;
  final double ballAngle;
  final double ballRadius;
  final double ballZ;
  final bool isSpinning;
  final double spinStartTime;
  final Stopwatch stopwatch;

  RouletteWheelPainter({
    required this.wheelType,
    required this.wheelAngle,
    required this.ballAngle,
    required this.ballRadius,
    required this.ballZ,
    required this.isSpinning,
    required this.spinStartTime,
    required this.stopwatch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double S = size.width;
    final double cx = S / 2.0;
    final double cy = S / 2.0;
    final double R = S * 0.44;

    // Constants radii
    final double outerR = R * 1.02;
    final double wallR = R * 0.94;
    final double wallInnerR = R * 0.86;
    final double deflectorR = R * 0.895;
    final double trackOuter = R * 0.885;
    final double trackInner = R * 0.868;

    final pockets = wheelType == WheelType.american
        ? RNG.americanWheelOrder
        : RNG.europeanWheelOrder;
    final double sectorAngle = (math.pi * 2) / pockets.length;

    // 1. Draw static base bowl
    final basePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        outerR + 2,
        [
          Colors.black,
          Colors.black.withOpacity(0.8),
        ],
        [0.7, 1.0],
      );
    canvas.drawCircle(Offset(cx, cy), outerR + 2, basePaint);

    // 2. Draw Mahogany Outer Rim
    final rimPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        outerR,
        [
          const Color(0xFF662615),
          const Color(0xFF48170B),
          const Color(0xFF2A0A03),
          const Color(0xFF150300),
        ],
        [0.0, 0.4, 0.8, 1.0],
        ui.TileMode.clamp,
        null,
        Offset(cx - outerR * 0.2, cy - outerR * 0.2),
        outerR * 0.1,
      );
    
    final rimPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: outerR))
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: wallR));
    rimPath.fillType = PathFillType.evenOdd;
    canvas.drawPath(rimPath, rimPaint);

    // 3. Gleaming Wood Track
    final trackPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        wallR,
        [
          const Color(0xFF1C0C08),
          const Color(0xFF4A2215),
          const Color(0xFF6B3320),
          const Color(0xFF2F150D),
        ],
        [0.0, 0.4, 0.8, 1.0],
        ui.TileMode.clamp,
        null,
        Offset(cx, cy),
        wallInnerR,
      );
    final trackPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: wallR))
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: wallInnerR));
    trackPath.fillType = PathFillType.evenOdd;
    canvas.drawPath(trackPath, trackPaint);

    // 4. Metallic lip
    final lipPaint = Paint()
      ..color = const Color(0xFFD4AF37).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(cx, cy), wallInnerR, lipPaint);

    // 5. Draw Deflectors (8 brass pins)
    for (int i = 0; i < 8; i++) {
      final double a = (i / 8.0) * (math.pi * 2);
      final double x = cx + math.cos(a) * deflectorR;
      final double y = cy + math.sin(a) * deflectorR;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(a + math.pi / 2.0);

      final defGrad = ui.Gradient.linear(
        const Offset(-4, -6),
        const Offset(4, 6),
        [
          const Color(0xFFFFFFFF),
          const Color(0xFFA0A0A0),
          const Color(0xFF606060),
        ],
        [0.0, 0.4, 1.0],
      );
      final defPaint = Paint()..shader = defGrad;
      canvas.drawRect(const Rect.fromLTRB(-3, -5, 3, 5), defPaint);
      canvas.restore();
    }

    // 6. Ball track groove shadow
    final groovePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        trackOuter,
        [
          const Color(0xFF220E08).withOpacity(0.9),
          const Color(0xFF5A2A18).withOpacity(0.55),
          const Color(0xFF1E0C06).withOpacity(0.95),
        ],
        [0.0, 0.5, 1.0],
        ui.TileMode.clamp,
        null,
        Offset(cx, cy),
        trackInner,
      );
    final groovePath = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: trackOuter))
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: trackInner));
    groovePath.fillType = PathFillType.evenOdd;
    canvas.drawPath(groovePath, groovePaint);

    // 7. Rotating Sectors (Pockets)
    final double innerR = R * 0.65;
    final double outerRSectors = R * 0.85;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(wheelAngle);

    final double now = stopwatch.elapsedMilliseconds.toDouble();
    final bool isFastSpin = isSpinning && (now - spinStartTime) / SPIN_DURATION < 0.9;

    for (int i = 0; i < pockets.length; i++) {
      final num = pockets[i];
      final double startA = i * sectorAngle - math.pi / 2.0;
      final double endA = startA + sectorAngle;

      final colorName = RNG.getNumberColor(num);
      Color colorHex = const Color(0xFF1A1A1A);
      if (colorName == 'red') colorHex = const Color(0xFFBD222E);
      if (colorName == 'green') colorHex = const Color(0xFF197A3D);

      Color outerDark = const Color(0xFF090909);
      if (colorName == 'red') outerDark = const Color(0xFF6E1017);
      if (colorName == 'green') outerDark = const Color(0xFF0E4A23);

      // Radial wedge shader
      final pocketShader = ui.Gradient.radial(
        Offset.zero,
        outerRSectors,
        [colorHex, outerDark],
        [innerR / outerRSectors, 1.0],
      );

      final pocketPaint = Paint()..shader = pocketShader;

      final path = Path()
        ..moveTo(math.cos(startA) * innerR, math.sin(startA) * innerR)
        ..lineTo(math.cos(startA) * outerRSectors, math.sin(startA) * outerRSectors)
        ..arcTo(Rect.fromCircle(center: Offset.zero, radius: outerRSectors), startA, sectorAngle, false)
        ..lineTo(math.cos(endA) * innerR, math.sin(endA) * innerR)
        ..arcTo(Rect.fromCircle(center: Offset.zero, radius: innerR), endA, -sectorAngle, false)
        ..close();

      canvas.drawPath(path, pocketPaint);

      // Draw Gold dividers between sectors
      final dividerPaint = Paint()
        ..color = const Color(0xFFD4AF37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawPath(path, dividerPaint);

      // Draw text
      final double midA = (startA + endA) / 2.0;
      final double labelR = outerRSectors * 0.94;
      final double lx = math.cos(midA) * labelR;
      final double ly = math.sin(midA) * labelR;

      canvas.save();
      canvas.translate(lx, ly);
      canvas.rotate(midA + math.pi / 2.0);

      final String text = RNG.getDisplayNumber(num);
      final textStyle = TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: R * 0.08,
        fontFamily: 'Georgia',
      );

      final textPainter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      if (!isFastSpin) {
        // Draw drop shadow for text
        final shadowPainter = TextPainter(
          text: TextSpan(
            text: text,
            style: textStyle.copyWith(color: Colors.black.withOpacity(0.9)),
          ),
          textDirection: TextDirection.ltr,
        );
        shadowPainter.layout();
        shadowPainter.paint(canvas, Offset(-textPainter.width / 2.0 + 1.0, -textPainter.height / 2.0 + 1.0));
      }

      textPainter.paint(canvas, Offset(-textPainter.width / 2.0, -textPainter.height / 2.0));
      canvas.restore();
    }

    // Outer & Inner Gold circular rims around sectors
    final sectorRimPaint = Paint()
      ..color = const Color(0xFFB8942B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(Offset.zero, outerRSectors, sectorRimPaint);
    canvas.drawCircle(Offset.zero, innerR, sectorRimPaint);
    canvas.restore();

    // 8. Rotating Wood Rotor
    final double rotorOuter = R * 0.64;
    final double rotorInner = R * 0.38;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(wheelAngle);

    final woodShader = ui.Gradient.radial(
      Offset.zero,
      rotorOuter,
      [
        const Color(0xFF5B2416),
        const Color(0xFF3B140B),
        const Color(0xFF1C0703),
      ],
      [0.0, 0.5, 1.0],
      ui.TileMode.clamp,
      null,
      Offset(-rotorOuter * 0.2, -rotorOuter * 0.2),
      rotorOuter * 0.1,
    );

    final woodPaint = Paint()..shader = woodShader;
    canvas.drawCircle(Offset.zero, rotorOuter, woodPaint);

    // Draw wood grain sector lines
    final grainPaint = Paint()..strokeWidth = 1.0;
    for (int i = 0; i < 16; i++) {
      final double a = (i / 16.0) * (math.pi * 2);
      grainPaint.color = i % 2 == 0 ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.15);
      final double b = ((i + 1) / 16.0) * (math.pi * 2);

      final path = Path()
        ..moveTo(0, 0)
        ..arcTo(Rect.fromCircle(center: Offset.zero, radius: rotorOuter), a, b - a, false)
        ..lineTo(0, 0)
        ..close();
      canvas.drawPath(path, grainPaint);
    }

    // Brass inner rotor hub ring
    final brassShader = ui.Gradient.radial(
      Offset.zero,
      rotorInner,
      [
        const Color(0xFFF9DF9F),
        const Color(0xFFD4AF37),
        const Color(0xFF8B6B22),
        const Color(0xFF4A360C),
      ],
      [0.0, 0.3, 0.7, 1.0],
      ui.TileMode.clamp,
      null,
      Offset(-rotorInner * 0.2, -rotorInner * 0.2),
      rotorInner * 0.1,
    );
    final brassPaint = Paint()..shader = brassShader;
    canvas.drawCircle(Offset.zero, rotorInner, brassPaint);

    final brassStroke = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(Offset.zero, rotorInner, brassStroke);
    canvas.restore();

    // 9. Draw Ball
    final double trackMid = R * 0.885;
    final double pocketBottom = R * 0.68;
    final double t = ((ballRadius - BALL_ORBIT_END) / (BALL_ORBIT_START - BALL_ORBIT_END)).clamp(0.0, 1.0);
    final double orbitR = pocketBottom + t * (trackMid - pocketBottom);

    final double bx = cx + math.cos(ballAngle) * orbitR;
    final double by = cy + math.sin(ballAngle) * orbitR - ballZ.abs() * 0.55;
    final double br = R * 0.032;

    // Draw ball shadow
    final shadowPaint = Paint()..color = Colors.black.withOpacity(0.4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bx + 2.0, by + 4.0),
        width: br * 1.25 * 2.0,
        height: br * 0.62 * 2.0,
      ),
      shadowPaint,
    );

    // Draw Ivory Ball
    final ballShader = ui.Gradient.radial(
      Offset(bx, by),
      br,
      [
        const Color(0xFFFFFFFF),
        const Color(0xFFE8E0D0),
        const Color(0xFFA09070),
      ],
      [0.0, 0.4, 1.0],
      ui.TileMode.clamp,
      null,
      Offset(bx - br * 0.35, by - br * 0.35),
      br * 0.05,
    );
    final ballPaint = Paint()..shader = ballShader;
    canvas.drawCircle(Offset(bx, by), br, ballPaint);

    // Specular highlight
    final highlightPaint = Paint()..color = Colors.white.withOpacity(0.85);
    canvas.drawCircle(Offset(bx - br * 0.3, by - br * 0.3), br * 0.22, highlightPaint);

    // 10. Rotating Center Spindle Boss (Hub)
    final double hubR = R * 0.18;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(wheelAngle);

    final socketShader = ui.Gradient.radial(
      Offset.zero,
      hubR,
      [
        const Color(0xFF4A5568),
        const Color(0xFF2D3748),
        const Color(0xFF1A202C),
      ],
      [0.0, 0.5, 1.0],
    );
    final socketPaint = Paint()..shader = socketShader;
    canvas.drawCircle(Offset.zero, hubR, socketPaint);

    final socketStroke = Paint()
      ..color = Colors.black.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(Offset.zero, hubR, socketStroke);

    // Spindle Handles (4 handles)
    final double armStart = R * 0.10;
    final double armEnd = R * 0.36;
    final double tipRadius = R * 0.045;

    for (int i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * (math.pi / 2.0));

      final handleShader = ui.Gradient.linear(
        Offset(0.0, -R * 0.06),
        Offset(0.0, R * 0.06),
        [
          const Color(0xFF75541C),
          const Color(0xFFD4AF37),
          const Color(0xFFFEF1A6),
          const Color(0xFFD4AF37),
          const Color(0xFF3B2605),
        ],
        [0.0, 0.2, 0.5, 0.8, 1.0],
      );

      final handlePaint = Paint()..shader = handleShader;

      final path = Path()
        ..moveTo(armStart, -R * 0.02)
        ..cubicTo(
          armStart + (armEnd - armStart) * 0.3, -R * 0.02,
          armStart + (armEnd - armStart) * 0.6, -R * 0.05,
          armEnd, -R * 0.04,
        )
        ..lineTo(armEnd, R * 0.04)
        ..cubicTo(
          armStart + (armEnd - armStart) * 0.6, R * 0.05,
          armStart + (armEnd - armStart) * 0.3, R * 0.02,
          armStart, R * 0.02,
        )
        ..close();

      // Shadow
      if (!isFastSpin) {
        final handleShadowPaint = Paint()
          ..color = Colors.black.withOpacity(0.6)
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0);
        canvas.save();
        canvas.translate(3.0, 5.0);
        canvas.drawPath(path, handleShadowPaint);
        canvas.restore();
      }

      canvas.drawPath(path, handlePaint);

      // Handle Tip Ball
      final double tipX = armEnd + R * 0.02;
      final tipShader = ui.Gradient.radial(
        Offset(tipX, 0.0),
        tipRadius,
        [
          const Color(0xFFFFFFFF),
          const Color(0xFFFEF1A6),
          const Color(0xFFCCAA42),
          const Color(0xFF4A330A),
        ],
        [0.0, 0.3, 0.7, 1.0],
        ui.TileMode.clamp,
        null,
        Offset(tipX - tipRadius * 0.3, -tipRadius * 0.3),
        tipRadius * 0.1,
      );
      final tipPaint = Paint()..shader = tipShader;
      canvas.drawCircle(Offset(tipX, 0.0), tipRadius, tipPaint);

      canvas.restore();
    }

    // Center Spoke Cap
    final double capR = R * 0.09;
    final capShader = ui.Gradient.radial(
      Offset.zero,
      capR,
      [
        const Color(0xFF3F4552),
        const Color(0xFF2D333E),
        const Color(0xFF171A21),
      ],
      [0.0, 0.5, 1.0],
      ui.TileMode.clamp,
      null,
      Offset(-capR * 0.2, -capR * 0.2),
      capR * 0.1,
    );
    final capPaint = Paint()..shader = capShader;
    canvas.drawCircle(Offset.zero, capR, capPaint);

    final capStroke = Paint()
      ..color = Colors.black.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset.zero, capR, capStroke);
    canvas.restore();

    // 11. Gloss reflection overlay
    final glossShader = ui.Gradient.radial(
      Offset(cx, cy),
      R,
      [
        const Color(0x0FFFFFC8),
        const Color(0x05FFFC8),
        const Color(0x2E000000),
      ],
      [0.0, 0.5, 1.0],
      ui.TileMode.clamp,
      null,
      Offset(cx, cy - R * 0.2),
      R * 0.1,
    );
    final glossPaint = Paint()..shader = glossShader;
    canvas.drawCircle(Offset(cx, cy), R, glossPaint);
  }

  @override
  bool shouldRepaint(covariant RouletteWheelPainter oldDelegate) {
    return oldDelegate.wheelAngle != wheelAngle ||
        oldDelegate.ballAngle != ballAngle ||
        oldDelegate.ballRadius != ballRadius ||
        oldDelegate.ballZ != ballZ ||
        oldDelegate.isSpinning != isSpinning;
  }
}
