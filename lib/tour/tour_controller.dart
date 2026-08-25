/// Tour state controller — Dart port of the web `FunnelTourContext` (global
/// onboarding funnel) fused with `TourManager` (per-page "?" guides).
///
/// Screens interact with it through a Provider. Element targeting is done via
/// [TourRegistry] / [TourTarget] (the `data-tour` equivalent).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tour_models.dart';

/// Result of a step validator. Mirrors the web `StepValidatorResult`.
class ValidatorResult {
  final bool valid;
  final String? errorMsg;
  const ValidatorResult(this.valid, [this.errorMsg]);

  static const ok = ValidatorResult(true);
  static ValidatorResult fail([String? msg]) => ValidatorResult(false, msg);
}

typedef StepValidator = ValidatorResult Function();

class TourController extends ChangeNotifier {
  static const _storageKey = 'junko_master_funnel_state';
  static const _completedKey = 'junko_master_funnel_completed';

  SharedPreferences? _prefs;
  Future<void>? _initFuture;

  /// Completes once persisted state has been loaded.
  Future<void> get ready => _initFuture ??= init();

  // ── Global funnel state ──
  bool isActive = false;
  bool isTourPaused = false;
  int currentStepIndex = 0;
  String? errorMessage;
  bool isStepActionCompleted = false;
  StepValidator? _validator;

  // ── Per-page ("?") guide state ──
  TourDefinition? _pageTour;
  List<TourStep> _pageSteps = const [];
  int _pageIndex = 0;
  bool pageTourActive = false;

  // ── App hooks ──
  /// Navigates to a route (wired to go_router by the app shell).
  void Function(String route)? navigator;

  /// Returns the current route path (wired to go_router by the app shell).
  String Function()? routeGetter;

  bool isAdmin = false;

  String get _currentRoute => routeGetter?.call() ?? '';

  Future<void> init() {
    return _initFuture ??= _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final saved = _prefs!.getString(_storageKey);
      if (saved != null) {
        final parsed = jsonDecode(saved) as Map<String, dynamic>;
        if (parsed['isActive'] == true && parsed['stepIndex'] is int) {
          isActive = true;
          currentStepIndex = parsed['stepIndex'] as int;
        }
      }
    } catch (_) {
      // ignore corrupt state
    }
    notifyListeners();
  }

  // ─────────────────────────── Global funnel ───────────────────────────

  FunnelStep? get currentStep {
    if (!isActive ||
        currentStepIndex < 0 ||
        currentStepIndex >= kFunnelSteps.length) {
      return null;
    }
    return kFunnelSteps[currentStepIndex];
  }

  int get totalSteps => kFunnelSteps.length;

  bool get isReadyToAdvance {
    final step = currentStep;
    if (step == null) return false;
    if (!step.requireAction) return true;
    return isStepActionCompleted;
  }

  /// Whether the current funnel step belongs to the given route.
  bool isStepVisibleOn(String route) =>
      currentStep != null && currentStep!.route == route;

  void _save(bool active, int index) {
    try {
      _prefs?.setString(
          _storageKey, jsonEncode({'isActive': active, 'stepIndex': index}));
    } catch (_) {}
  }

  /// Auto-start the funnel the first time the user lands on /strategies
  /// (unless they have already completed or are mid-tour). Mirrors the web
  /// auto-start useEffect.
  void maybeAutoStart(String route) {
    if (isActive) return;
    if (route != '/strategies') return;
    final completed = _prefs?.getString(_completedKey);
    if (completed == 'true') return;
    currentStepIndex = 0;
    isActive = true;
    _save(true, 0);
    notifyListeners();
  }

  void startTour() {
    currentStepIndex = 0;
    isActive = true;
    isTourPaused = false;
    errorMessage = null;
    _validator = null;
    isStepActionCompleted = false;
    _save(true, 0);
    try {
      _prefs?.remove(_completedKey);
    } catch (_) {}
    if (_currentRoute != '/strategies') {
      navigator?.call('/strategies');
    }
    notifyListeners();
  }

  void skipTour() {
    isActive = false;
    errorMessage = null;
    _validator = null;
    try {
      _prefs?.setString(_completedKey, 'true');
      _prefs?.remove(_storageKey);
    } catch (_) {}
    notifyListeners();
  }

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  void setTourPaused(bool paused) {
    if (isTourPaused == paused) return;
    isTourPaused = paused;
    notifyListeners();
  }

  /// Registers the live validator for the active step, with an optional live
  /// completion flag. Call from initState / event handlers — never build().
  void setStepValidator(StepValidator? validator, {bool? isCompleted}) {
    _validator = validator;
    if (isCompleted != null && isCompleted != isStepActionCompleted) {
      isStepActionCompleted = isCompleted;
      notifyListeners();
    }
  }

  void _completeFunnel() {
    isActive = false;
    try {
      _prefs?.setString(_completedKey, 'true');
      _prefs?.remove(_storageKey);
    } catch (_) {}
    notifyListeners();
  }

  /// Advances to the next funnel step. When [stepIdToComplete] equals the
  /// current step id, this is a click-through from the spotlighted element and
  /// bypasses validation (mirrors the web `advanceStep`).
  void advanceStep([String? stepIdToComplete]) {
    final step = currentStep;
    if (step == null) return;

    final isElementClickThrough =
        stepIdToComplete != null && stepIdToComplete == step.id;

    if (!isElementClickThrough && _validator != null) {
      final result = _validator!();
      if (!result.valid) {
        errorMessage = result.errorMsg ??
            step.fallbackErrorMsg ??
            'Please complete the requested task first!';
        notifyListeners();
        return;
      }
    } else if (step.requireAction && !isElementClickThrough) {
      if (!step.clickAdvances) {
        errorMessage = step.fallbackErrorMsg ??
            'Please complete the requested action first!';
        notifyListeners();
        return;
      }
    }

    errorMessage = null;
    _validator = null;
    isStepActionCompleted = false;

    final nextIndex = currentStepIndex + 1;
    if (nextIndex >= kFunnelSteps.length) {
      _completeFunnel();
      return;
    }

    final nextStep = kFunnelSteps[nextIndex];
    currentStepIndex = nextIndex;
    _save(true, nextIndex);

    // Auto-navigate if the next step lives on another route AND the advance was
    // not driven by an element click (the element's own handler navigates).
    if (nextStep.route != _currentRoute && !isElementClickThrough) {
      navigator?.call(nextStep.route);
    }
    notifyListeners();
  }

  void prevStep() {
    errorMessage = null;
    _validator = null;
    isStepActionCompleted = false;
    if (currentStepIndex <= 0) return;
    final prevIndex = currentStepIndex - 1;
    currentStepIndex = prevIndex;
    _save(true, prevIndex);
    final prevStepObj = kFunnelSteps[prevIndex];
    if (prevStepObj.route != _currentRoute) {
      navigator?.call(prevStepObj.route);
    }
    notifyListeners();
  }

  // ─────────────────────────── Per-page guides ───────────────────────────

  TourStep? get currentPageStep {
    if (!pageTourActive || _pageIndex < 0 || _pageIndex >= _pageSteps.length) {
      return null;
    }
    return _pageSteps[_pageIndex];
  }

  int get pageStepIndex => _pageIndex;
  int get pageTotalSteps => _pageSteps.length;
  String get pageTourSide => _pageTour?.side ?? 'left';

  /// Starts a per-page guide (the "?" Tour button). Mirrors `TourManager`
  /// manual trigger.
  void startPageTour(String tourId) {
    final def = kPageTours[tourId];
    if (def == null) return;
    _pageTour = def;
    _pageSteps =
        def.steps.where((s) => !s.requireAdmin || isAdmin).toList(growable: false);
    _pageIndex = 0;
    pageTourActive = _pageSteps.isNotEmpty;
    notifyListeners();
  }

  void pageNext() {
    if (_pageIndex >= _pageSteps.length - 1) {
      closePageTour();
    } else {
      _pageIndex++;
      notifyListeners();
    }
  }

  void pageBack() {
    if (_pageIndex > 0) {
      _pageIndex--;
      notifyListeners();
    }
  }

  void pageTargetMissing() {
    if (_pageIndex < _pageSteps.length - 1) {
      _pageIndex++;
      notifyListeners();
    } else {
      closePageTour();
    }
  }

  void closePageTour() {
    final key = _pageTour?.storageKey;
    if (key != null) {
      try {
        _prefs?.setString(key, 'true');
      } catch (_) {}
    }
    pageTourActive = false;
    _pageTour = null;
    _pageSteps = const [];
    notifyListeners();
  }
}
