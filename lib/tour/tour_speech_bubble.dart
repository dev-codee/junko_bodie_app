/// Guide speech bubble — Dart port of the web `TourSpeechBubble`.
/// Shows brand + progress header, the guide's line (with *highlight* spans),
/// an action-hint / error / ready pill, and Skip / Back / Next(Finish)
/// controls. Pops in on mount and shakes on error.
library;

import 'package:flutter/material.dart';

const _kGold = Color(0xFFC9A44C);
const _kDarkGreen = Color(0xFF0F2E21);
const _kCream = Color(0xFFF7EAD0);

class TourSpeechBubble extends StatefulWidget {
  final String text;
  final int stepIndex;
  final int totalSteps;
  final String actionHint;
  final String? errorMessage;
  final bool isReadyToAdvance;
  final bool hideNextButton;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final String side; // 'left' | 'right'

  const TourSpeechBubble({
    super.key,
    required this.text,
    required this.stepIndex,
    required this.totalSteps,
    this.actionHint = 'Tap the highlighted element on screen',
    this.errorMessage,
    this.isReadyToAdvance = false,
    this.hideNextButton = false,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    this.side = 'left',
  });

  @override
  State<TourSpeechBubble> createState() => _TourSpeechBubbleState();
}

class _TourSpeechBubbleState extends State<TourSpeechBubble>
    with TickerProviderStateMixin {
  late final AnimationController _popIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void didUpdateWidget(TourSpeechBubble old) {
    super.didUpdateWidget(old);
    if (widget.errorMessage != null && widget.errorMessage != old.errorMessage) {
      _shake.forward(from: 0);
    }
    if (widget.text != old.text) {
      _popIn.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _popIn.dispose();
    _shake.dispose();
    super.dispose();
  }

  List<TextSpan> _formatted(String str) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*[^*]+\*)');
    int last = 0;
    for (final m in regex.allMatches(str)) {
      if (m.start > last) {
        spans.add(TextSpan(text: str.substring(last, m.start)));
      }
      final inner = m.group(0)!.replaceAll('*', '');
      spans.add(TextSpan(
        text: inner,
        style: const TextStyle(
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w800,
          color: Color(0xFF735312),
          backgroundColor: Color(0x29C9A44C),
        ),
      ));
      last = m.end;
    }
    if (last < str.length) spans.add(TextSpan(text: str.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final isLast = widget.stepIndex == widget.totalSteps - 1;

    Widget pill;
    if (widget.errorMessage != null) {
      pill = _Pill(
        bg: const Color(0x14C73C4D),
        border: const Color(0x80C73C4D),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 14, color: Color(0xFFC73C4D)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(widget.errorMessage!,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );
    } else if (widget.isReadyToAdvance) {
      pill = _Pill(
        bg: const Color(0x1F3FD1B4),
        border: const Color(0x803FD1B4),
        child: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.check, size: 14, color: Color(0xFF059669)),
          SizedBox(width: 6),
          Text('Ready! Tap Next to proceed',
              style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF065F46),
                  fontWeight: FontWeight.w800)),
        ]),
      );
    } else {
      pill = _Pill(
        bg: const Color(0x14C9A44C),
        border: const Color(0x99C9A44C),
        dashed: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
                color: _kGold, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(widget.actionHint,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF735312),
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );
    }

    final bubble = Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGold, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x47000000), blurRadius: 36, offset: Offset(0, 16)),
          BoxShadow(color: Color(0x33C9A44C), blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand + progress header
          Container(
            padding: const EdgeInsets.only(bottom: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x40C9A44C))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('JUNKO BODIE GUIDE',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Color(0xFF8C6D23))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x1FC9A44C),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0x4DC9A44C)),
                  ),
                  child: Text('${widget.stepIndex + 1} / ${widget.totalSteps}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _kDarkGreen)),
                ),
              ],
            ),
          ),
          // Speech text
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  height: 1.42,
                  fontWeight: FontWeight.w600,
                  color: _kDarkGreen,
                ),
                children: [
                  const TextSpan(text: '"'),
                  ..._formatted(widget.text),
                  const TextSpan(text: '"'),
                ],
              ),
            ),
          ),
          pill,
          const SizedBox(height: 10),
          // Footer
          Row(
            children: [
              GestureDetector(
                onTap: widget.onSkip,
                child: const Text('Skip tour',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8C6D23),
                        decoration: TextDecoration.underline)),
              ),
              const Spacer(),
              if (widget.stepIndex > 0) ...[
                _BackButton(onTap: widget.onBack),
                const SizedBox(width: 6),
              ],
              if (!widget.hideNextButton)
                _NextButton(
                  isLast: isLast,
                  ready: widget.isReadyToAdvance,
                  onTap: widget.onNext,
                ),
            ],
          ),
        ],
      ),
    );

    // Shake + pop-in transforms
    return AnimatedBuilder(
      animation: Listenable.merge([_popIn, _shake]),
      builder: (context, child) {
        final pop = Curves.easeOutBack.transform(_popIn.value.clamp(0.0, 1.0));
        double dx = 0;
        if (_shake.isAnimating) {
          dx = 6 * (1 - _shake.value) *
              (((_shake.value * 6).floor().isEven) ? 1 : -1);
        }
        return Opacity(
          opacity: _popIn.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dx, (1 - pop) * 20),
            child: Transform.scale(scale: 0.85 + 0.15 * pop, child: child),
          ),
        );
      },
      child: bubble,
    );
  }
}

class _Pill extends StatelessWidget {
  final Color bg;
  final Color border;
  final bool dashed;
  final Widget child;
  const _Pill(
      {required this.bg,
      required this.border,
      required this.child,
      this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: border, width: 1.1),
      ),
      child: child,
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0x0F0F2E21),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0x290F2E21)),
        ),
        child: const Text('BACK',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: _kDarkGreen)),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final bool isLast;
  final bool ready;
  final VoidCallback onTap;
  const _NextButton(
      {required this.isLast, required this.ready, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: _kDarkGreen,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: ready ? _kCream : _kGold, width: ready ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
                color: ready
                    ? const Color(0xF2C9A44C)
                    : const Color(0x4D0F2E21),
                blurRadius: ready ? 20 : 10),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(isLast ? 'FINISH' : 'NEXT',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: _kCream)),
          const SizedBox(width: 4),
          Icon(isLast ? Icons.check : Icons.chevron_right,
              size: 14, color: _kCream),
        ]),
      ),
    );
  }
}
