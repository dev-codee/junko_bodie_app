/// Global tour overlay — Dart port of the rendering half of the web
/// `FunnelTourContext` + `TourManager`. Mounted once (above the router) via
/// `MaterialApp.router`'s builder. Shows the spotlight ring plus the docked
/// mascot + speech bubble for whichever tour is active.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'tour_character.dart';
import 'tour_controller.dart';
import 'tour_highlight_ring.dart';
import 'tour_registry.dart';
import 'tour_speech_bubble.dart';

class TourOverlay extends StatefulWidget {
  const TourOverlay({super.key});

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Rect? _rect;
  List<Rect> _extraRects = const [];
  String? _activeTargetId;
  Duration _missingSince = Duration.zero;

  // ── Manual drag ──
  /// When the user drags the guide, this holds its top-left in global coords
  /// and overrides the automatic corner docking. Reset to null on each new
  /// step so every step starts from a sensible auto position.
  final GlobalKey _dockKey = GlobalKey();
  Offset? _dragPos;
  Size? _dockSize;

  /// When true, the speech card is collapsed and only Junko's face shows.
  /// Tapping the face toggles it. Reset on each new step.
  bool _bubbleHidden = false;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final controller = context.read<TourController>();
    final targetId = _resolveTargetId(controller);

    if (targetId != _activeTargetId) {
      _activeTargetId = targetId;
      _missingSince = elapsed;
      // A new step gets a fresh auto position (discard any manual drag) and
      // re-shows the card if the user had collapsed it on the previous step.
      _dragPos = null;
      _bubbleHidden = false;
      // Bring the new target into view on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible(targetId));
    }

    final newRect = targetId == null ? null : TourRegistry.instance.rectFor(targetId);
    if (newRect != null) _missingSince = elapsed;

    // Auto-advance a page guide whose target never mounts (mirrors web).
    if (controller.pageTourActive &&
        newRect == null &&
        targetId != null &&
        elapsed - _missingSince > const Duration(milliseconds: 1400)) {
      controller.pageTargetMissing();
    }

    // Resolve any additional funnel-step targets to spotlight together.
    List<Rect> newExtra = const [];
    if (targetId != null && !controller.pageTourActive) {
      final extras = controller.currentStep?.alsoHighlight ?? const [];
      if (extras.isNotEmpty) {
        final rects = <Rect>[];
        for (final id in extras) {
          final r = TourRegistry.instance.rectFor(id);
          if (r != null) rects.add(r);
        }
        newExtra = rects;
      }
    }

    bool changed = false;
    if (!_rectsClose(_rect, newRect)) {
      _rect = newRect;
      changed = true;
    }
    if (!_extraRectsClose(_extraRects, newExtra)) {
      _extraRects = newExtra;
      changed = true;
    }
    if (changed) setState(() {});
  }

  bool _extraRectsClose(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_rectsClose(a[i], b[i])) return false;
    }
    return true;
  }

  void _ensureVisible(String? targetId) {
    if (targetId == null) return;
    final ctx = TourRegistry.instance.keyFor(targetId)?.currentContext;
    if (ctx == null) return;
    try {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350),
          alignment: 0.5,
          curve: Curves.easeInOut);
    } catch (_) {}
  }

  String? _resolveTargetId(TourController c) {
    if (c.pageTourActive) return c.currentPageStep?.id;
    final route = c.routeGetter?.call() ?? '';
    if (c.isActive && !c.isTourPaused && c.isStepVisibleOn(route)) {
      return c.currentStep?.targetId;
    }
    return null;
  }

  bool _rectsClose(Rect? a, Rect? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return (a.left - b.left).abs() < 1 &&
        (a.top - b.top).abs() < 1 &&
        (a.width - b.width).abs() < 1 &&
        (a.height - b.height).abs() < 1;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TourController>();

    final bool pageMode = c.pageTourActive && c.currentPageStep != null;
    final route = c.routeGetter?.call() ?? '';
    final bool funnelMode = !pageMode &&
        c.isActive &&
        !c.isTourPaused &&
        c.currentStep != null &&
        c.isStepVisibleOn(route);

    if (!pageMode && !funnelMode) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final String side = _horizontalSide(c, pageMode, size);
    final String vSide = _dockVertical(c, pageMode, size);

    return Stack(
      children: [
        TourHighlightRing(targetRect: _rect, extraRects: _extraRects),
        _buildDock(c, pageMode, side, vSide, size),
      ],
    );
  }

  String _horizontalSide(TourController c, bool pageMode, Size size) {
    if (!pageMode) {
      final step = c.currentStep;
      // Explicit pin wins (e.g. step 21 kept bottom-left "the default way").
      if (step != null && step.pinSide) return step.side;
      // Otherwise dock OPPOSITE the highlighted target so the card never sits
      // on top of what it's demonstrating (symmetric with the vertical dock).
      final rect = _rect;
      if (rect != null) {
        return rect.center.dx < size.width / 2 ? 'right' : 'left';
      }
      return step?.side ?? 'left';
    }
    return c.currentPageStep?.side ?? c.pageTourSide;
  }

  /// Chooses whether to dock the bubble at the top or bottom of the screen.
  /// Picks the band with the most clearance from the highlighted target so the
  /// guide never sits on top of the element it is describing — this is the
  /// mobile fix for the bubble covering rules dropdowns, the spin log, metrics,
  /// sim config rows, grade cards, etc.
  String _dockVertical(TourController c, bool pageMode, Size size) {
    // A step may force its dock band (e.g. keep the guide bottom-left the
    // "default way" even when there's more clearance above the target).
    if (!pageMode) {
      final forced = c.currentStep?.dock;
      if (forced == 'top' || forced == 'bottom') return forced!;
    }
    final rect = _rect;
    if (rect == null) return 'bottom';
    final spaceAbove = rect.top;
    final spaceBelow = size.height - rect.bottom;
    return spaceAbove > spaceBelow ? 'top' : 'bottom';
  }

  Widget _buildDock(
      TourController c, bool pageMode, String side, String vSide, Size size) {
    final bool isLeft = side == 'left';
    final bool atTop = vSide == 'top';

    // Cap the card so it never overflows the viewport. Reserve room for the
    // face (~90), drag handle (~30), edge padding and gaps (~44). The card's
    // text scrolls internally past this, keeping the footer/NEXT reachable.
    final mqPad = MediaQuery.of(context).padding;
    final double bubbleMaxHeight =
        (size.height - mqPad.top - mqPad.bottom - 164).clamp(180.0, 640.0);

    final Widget bubble;
    final String stepId;
    final bool hasError = !pageMode && c.errorMessage != null;
    if (pageMode) {
      final step = c.currentPageStep!;
      stepId = step.id;
      bubble = TourSpeechBubble(
        key: ValueKey('page-${step.id}'),
        text: step.text,
        stepIndex: c.pageStepIndex,
        totalSteps: c.pageTotalSteps,
        actionHint: 'Tap Next to continue',
        isReadyToAdvance: true,
        onNext: c.pageNext,
        onBack: c.pageBack,
        onSkip: c.closePageTour,
        side: side,
        maxHeight: bubbleMaxHeight,
      );
    } else {
      final step = c.currentStep!;
      stepId = step.id;
      bubble = TourSpeechBubble(
        key: ValueKey('funnel-${step.id}'),
        text: step.text,
        stepIndex: c.currentStepIndex,
        totalSteps: c.totalSteps,
        actionHint: step.actionHint,
        errorMessage: c.errorMessage,
        isReadyToAdvance: c.isReadyToAdvance,
        hideNextButton: step.hideNextButton,
        onNext: () => c.advanceStep(),
        onBack: c.prevStep,
        onSkip: c.skipTour,
        maxHeight: bubbleMaxHeight,
        side: side,
      );
    }

    final mq = MediaQuery.of(context);
    // A smaller mascot on mobile so the guide takes up less of the screen.
    // Tapping the face collapses the card so nothing on screen is covered;
    // tapping again brings it back. A small eye badge signals it's tappable.
    final character = GestureDetector(
      onTap: () => setState(() => _bubbleHidden = !_bubbleHidden),
      behavior: HitTestBehavior.opaque,
      child: Transform.translate(
        offset: Offset(0, atTop ? 6 : -6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            TourGuideCharacter(
                stepId: stepId, side: side, size: 82, hasError: hasError),
            Positioned(
              right: isLeft ? 0 : null,
              left: isLeft ? null : 0,
              bottom: 2,
              child: _visBadge(_bubbleHidden),
            ),
          ],
        ),
      ),
    );

    // Grab handle — drag the whole guide anywhere (left/right/top/bottom).
    final bubbleWithHandle = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [_dragHandle(), bubble],
    );

    // Keep the mascot on the outer edge (nearest the screen edge) so the
    // bubble body sits toward the screen interior. When collapsed, only the
    // face shows so the user can read whatever the card was covering.
    final List<Widget> children = _bubbleHidden
        ? [character]
        : atTop
            ? [character, bubbleWithHandle]
            : [bubbleWithHandle, character];

    final bool dragging = _dragPos != null;

    return Positioned(
      top: dragging ? _dragPos!.dy : (atTop ? mq.padding.top + 8 : null),
      bottom: dragging ? null : (atTop ? null : mq.padding.bottom + 16),
      left: dragging ? _dragPos!.dx : (isLeft ? 20 : null),
      right: dragging ? null : (isLeft ? null : 20),
      child: ConstrainedBox(
        key: _dockKey,
        constraints: BoxConstraints(maxWidth: size.width - 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: children,
        ),
      ),
    );
  }

  /// Little eye badge on Junko's face signalling that a tap hides/shows the
  /// guide card. Shows an open eye when the card is hidden (tap to reveal) and
  /// a struck-through eye when it's visible (tap to collapse).
  Widget _visBadge(bool hidden) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xF20F2E21),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFC9A44C), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 13,
        color: const Color(0xFFF7EAD0),
      ),
    );
  }

  /// Small draggable pill above the bubble. Dragging it repositions the whole
  /// guide; a double-tap snaps back to the automatic position.
  Widget _dragHandle() {
    return GestureDetector(
      onPanStart: _onDragStart,
      onPanUpdate: _onDragUpdate,
      onDoubleTap: () => setState(() => _dragPos = null),
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xF20F2E21),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC9A44C), width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_with, size: 13, color: Color(0xFFF7EAD0)),
            SizedBox(width: 5),
            Text('Drag to move',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: Color(0xFFF7EAD0))),
          ],
        ),
      ),
    );
  }

  void _onDragStart(DragStartDetails d) {
    final box = _dockKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() {
      _dockSize = box.size;
      _dragPos = box.localToGlobal(Offset.zero);
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final screen = MediaQuery.of(context).size;
    final sz = _dockSize ?? Size.zero;
    final cur = _dragPos ?? Offset.zero;
    final maxX = (screen.width - sz.width).clamp(0.0, screen.width);
    final maxY = (screen.height - sz.height).clamp(0.0, screen.height);
    setState(() {
      _dragPos = Offset(
        (cur.dx + d.delta.dx).clamp(0.0, maxX),
        (cur.dy + d.delta.dy).clamp(0.0, maxY),
      );
    });
  }
}
