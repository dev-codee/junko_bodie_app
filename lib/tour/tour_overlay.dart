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
  String? _activeTargetId;
  Duration _missingSince = Duration.zero;

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

    if (!_rectsClose(_rect, newRect)) {
      setState(() => _rect = newRect);
    }
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
    final String side = _dockSide(c, pageMode, size);

    return Stack(
      children: [
        TourHighlightRing(targetRect: _rect),
        _buildDock(c, pageMode, side),
      ],
    );
  }

  String _dockSide(TourController c, bool pageMode, Size size) {
    final String? prefer =
        pageMode ? (c.currentPageStep?.side ?? c.pageTourSide) : c.currentStep?.side;

    final rect = _rect;
    if (rect != null) {
      // Avoid docking over the target: if it's in a bottom corner, use the
      // opposite side (mirrors the web dynamic dock logic, simplified).
      final centerX = (rect.left + rect.right) / 2;
      final nearBottom = rect.bottom > size.height * 0.35;
      if (nearBottom) {
        if (centerX < size.width * 0.48) return 'right';
        if (centerX > size.width * 0.52) return 'left';
      }
    }
    return prefer ?? 'left';
  }

  Widget _buildDock(TourController c, bool pageMode, String side) {
    final bool isLeft = side == 'left';

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
        side: side,
      );
    }

    return Positioned(
      bottom: 16,
      left: isLeft ? 20 : null,
      right: isLeft ? null : 20,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            bubble,
            Transform.translate(
              offset: const Offset(0, -6),
              child: TourGuideCharacter(
                  stepId: stepId, side: side, size: 104, hasError: hasError),
            ),
          ],
        ),
      ),
    );
  }
}
