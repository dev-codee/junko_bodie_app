import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junko_bodie/logic/bets.dart';
import 'package:junko_bodie/logic/rng.dart';
import 'package:junko_bodie/logic/payouts.dart';
import 'package:junko_bodie/logic/game_phases.dart';
import 'package:junko_bodie/services/user_service.dart';
import 'package:junko_bodie/services/session_history_service.dart';
import 'package:junko_bodie/audio/audio_engine.dart';

/// GameProvider — State management for the roulette game.
/// Ported from React useGameState.ts hook using the Provider (ChangeNotifier) pattern.
class GameProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  final SessionHistoryService _sessionService = SessionHistoryService();

  // Session-history tracking (mirrors the web's useSessionTracking).
  String? _sessionId;
  bool _sessionStarting = false;
  int _sessionSpinCount = 0;

  double _balance = 0.0;
  Map<String, PlacedBet> _bets = {};
  double _selectedChip = 5.0;
  WheelType _wheelType = WheelType.american;
  GamePhase _phase = GamePhase.betting;
  SpinResult? _currentResult;
  PayoutResult? _lastPayout;
  List<SpinResult> _history = [];

  Map<String, PlacedBet> _lastSpinBets = {};
  final List<Map<String, dynamic>> _betPlacementHistory = [];
  bool _deleteMode = false;
  String? _deleteModeTarget;
  String? _fundError;
  bool _loading = false;
  bool _isTimerEnabled = true;

  final Map<String, double> _sessionStats = {
    'lastBet': 0.0,
    'lastWin': 0.0,
    'sessionWin': 0.0,
  };

  // Getters
  double get balance => _balance;
  Map<String, PlacedBet> get bets => _bets;
  double get selectedChip => _selectedChip;
  WheelType get wheelType => _wheelType;
  GamePhase get phase => _phase;
  SpinResult? get currentResult => _currentResult;
  PayoutResult? get lastPayout => _lastPayout;
  List<SpinResult> get history => _history;
  bool get hasLastSpin => _lastSpinBets.isNotEmpty;
  bool get deleteMode => _deleteMode;
  String? get deleteModeTarget => _deleteModeTarget;
  String? get fundError => _fundError;
  bool get loading => _loading;
  bool get isTimerEnabled => _isTimerEnabled;
  Map<String, double> get sessionStats => _sessionStats;

  double get totalBet => _bets.values.fold(0.0, (sum, b) => sum + b.amount);

  GameProvider() {
    _loadHistory();
  }

  /// Initialize and fetch the user's latest balance from the backend.
  Future<void> loadProfileBalance() async {
    _loading = true;
    notifyListeners();
    try {
      final profile = await _userService.getProfile();
      _balance = profile.balance;
      _isTimerEnabled = profile.isTimerEnabled;
    } catch (e) {
      debugPrint('GameProvider: Error loading profile balance: $e');
      // Fallback balance so development/testing is not blocked by 401 Unauthorized
      if (_balance == 0.0) {
        _balance = 10000.0;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Session-history recording ───────────────────────────────────────────
  /// Begin a solo session for analytics/history. Safe to call once on entry.
  Future<void> startGameSession() async {
    if (_sessionId != null || _sessionStarting) return;
    _sessionStarting = true;
    _sessionSpinCount = 0;
    try {
      _sessionId = await _sessionService.createSession(
        sessionType: 'solo',
        startingBankroll: _balance,
      );
    } catch (e) {
      debugPrint('GameProvider: Could not start session: $e');
    } finally {
      _sessionStarting = false;
    }
  }

  /// End the current session (finalizes end_time + profit_loss).
  Future<void> endGameSession() async {
    final id = _sessionId;
    if (id == null) return;
    _sessionId = null; // prevent double-send
    try {
      await _sessionService.endSession(id, endingBankroll: _balance);
    } catch (e) {
      debugPrint('GameProvider: Could not end session: $e');
    }
  }

  void _logSpinToSession(double betTotal, double netResult, double bankrollAfter) {
    final id = _sessionId;
    if (id == null) return;
    _sessionSpinCount++;
    unawaited(
      _sessionService
          .logSpin(id, betTotal: betTotal, netResult: netResult, bankrollAfter: bankrollAfter)
          .catchError((e) => debugPrint('GameProvider: logSpin failed: $e')),
    );
  }

  /// Helper to trigger a temporary funds error
  void triggerFundError([String message = 'Insufficient funds for this bet']) {
    _fundError = message;
    soundEngine.playDeniedSound();
    notifyListeners();
  }

  void setFundError(String? error) {
    _fundError = error;
    notifyListeners();
  }

  /// Place a chip on a bet zone.
  void placeBet(String betId) {
    if (_phase != GamePhase.betting) return;

    final definition = Bets.betMap[betId];
    if (definition == null) return;

    if (_balance - totalBet < _selectedChip) {
      triggerFundError();
      return;
    }

    final existing = _bets[betId];
    if (existing != null) {
      _bets[betId] = PlacedBet(
        betId: betId,
        amount: existing.amount + _selectedChip,
        chips: [...existing.chips, _selectedChip],
      );
    } else {
      _bets[betId] = PlacedBet(
        betId: betId,
        amount: _selectedChip,
        chips: [_selectedChip],
      );
    }

    _betPlacementHistory.add({'betId': betId, 'amount': _selectedChip});
    notifyListeners();
  }

  /// Remove last chip from a bet zone (manual right-click/long-press).
  void removeBet(String betId) {
    if (_phase != GamePhase.betting) return;

    final existing = _bets[betId];
    if (existing == null || existing.chips.isEmpty) return;

    final chips = List<double>.from(existing.chips);
    final removedChip = chips.removeLast();
    final newAmount = existing.amount - removedChip;

    if (chips.isEmpty) {
      _bets.remove(betId);
    } else {
      _bets[betId] = PlacedBet(
        betId: betId,
        amount: newAmount,
        chips: chips,
      );
    }

    if (_deleteMode && _bets.isEmpty) {
      _deleteMode = false;
    }
    notifyListeners();
  }

  /// Clear only the most recently placed chip (Undo).
  void clearLastBet() {
    if (_phase != GamePhase.betting || _betPlacementHistory.isEmpty) return;

    final lastAction = _betPlacementHistory.removeLast();
    final String betId = lastAction['betId'];
    final double amount = lastAction['amount'];

    final existing = _bets[betId];
    if (existing == null) return;

    final chips = List<double>.from(existing.chips);
    final lastChipIndex = chips.lastIndexOf(amount);
    if (lastChipIndex == -1) return;

    chips.removeAt(lastChipIndex);
    final newAmount = existing.amount - amount;

    if (chips.isEmpty) {
      _bets.remove(betId);
    } else {
      _bets[betId] = PlacedBet(
        betId: betId,
        amount: newAmount,
        chips: chips,
      );
    }

    if (_deleteMode && _bets.isEmpty) {
      _deleteMode = false;
    }
    notifyListeners();
  }

  /// Clear all placed bets.
  void clearBets() {
    if (_phase != GamePhase.betting) return;
    _bets.clear();
    _betPlacementHistory.clear();
    _deleteMode = false;
    notifyListeners();
  }

  /// Double all bets.
  /// Returns false if insufficient funds.
  bool doubleAllBets() {
    if (_phase != GamePhase.betting || _bets.isEmpty) return true;

    final double currentTotal = totalBet;
    final double newTotal = currentTotal * 2;

    if (_balance < newTotal) {
      triggerFundError();
      return false;
    }

    final nextBets = <String, PlacedBet>{};
    _bets.forEach((betId, bet) {
      nextBets[betId] = PlacedBet(
        betId: betId,
        amount: bet.amount * 2,
        chips: bet.chips.map((c) => c * 2).toList(),
      );
    });
    _bets = nextBets;

    // Double the amounts in history
    for (var entry in _betPlacementHistory) {
      entry['amount'] = (entry['amount'] as double) * 2;
    }

    soundEngine.play2XClick();
    notifyListeners();
    return true;
  }

  /// Toggle delete mode.
  void toggleDeleteMode() {
    _deleteMode = !_deleteMode;
    _deleteModeTarget = null;
    notifyListeners();
  }

  void setDeleteModeTarget(String? target) {
    _deleteModeTarget = target;
    notifyListeners();
  }

  /// Pop the last (highest value) chip from a specific bet zone.
  void popLastChip(String betId) {
    if (_phase != GamePhase.betting) return;

    final existing = _bets[betId];
    if (existing == null || existing.chips.isEmpty) return;

    final chips = List<double>.from(existing.chips);
    final removedChip = chips.removeLast();
    final newAmount = existing.amount - removedChip;

    if (chips.isEmpty) {
      _bets.remove(betId);
    } else {
      _bets[betId] = PlacedBet(
        betId: betId,
        amount: newAmount,
        chips: chips,
      );
    }

    soundEngine.playSwoosh();
    if (_deleteMode && _bets.isEmpty) {
      _deleteMode = false;
    }
    notifyListeners();
  }

  /// Clear all chips from a specific bet zone.
  void clearZone(String betId) {
    if (_phase != GamePhase.betting) return;

    _bets.remove(betId);
    soundEngine.playSwoosh();

    if (_deleteMode && _bets.isEmpty) {
      _deleteMode = false;
    }
    notifyListeners();
  }

  /// Re-apply the bets from the previous spin.
  void rebet() {
    if (_phase != GamePhase.betting || _lastSpinBets.isEmpty) return;

    final double lastTotal = _lastSpinBets.values.fold(0.0, (sum, b) => sum + b.amount);
    if (_balance < lastTotal) {
      triggerFundError('Insufficient funds to re-bet');
      return;
    }

    _bets = Map.from(_lastSpinBets).map((key, value) => MapEntry(
      key,
      PlacedBet(
        betId: value.betId,
        amount: value.amount,
        chips: List.from(value.chips),
      ),
    ));

    _betPlacementHistory.clear();
    _lastSpinBets.forEach((id, bet) {
      for (var c in bet.chips) {
        _betPlacementHistory.add({'betId': id, 'amount': c});
      }
    });

    notifyListeners();
  }

  /// Set the phase.
  void setPhase(GamePhase nextPhase) {
    _phase = nextPhase;
    notifyListeners();
  }

  /// Set wheel type.
  void setWheelType(WheelType type) {
    _wheelType = type;
    notifyListeners();
  }

  /// Set selected chip denomination.
  void setSelectedChip(double value) {
    _selectedChip = value;
    notifyListeners();
  }

  /// Toggle or update the betting timer enabled status locally
  void setTimerEnabled(bool enabled) {
    _isTimerEnabled = enabled;
    notifyListeners();
  }

  /// Execute a spin. Returns the result for animation purposes.
  ///
  /// Spins even when no bets are placed (the auto-timeout path always spins,
  /// matching the web app — an empty-bet spin just yields a $0 payout).
  Future<SpinResult?> executeSpin() async {
    // Archive current bets for Rebet
    _lastSpinBets = Map.from(_bets).map((key, value) => MapEntry(
      key,
      PlacedBet(
        betId: value.betId,
        amount: value.amount,
        chips: List.from(value.chips),
      ),
    ));

    final double betTotal = totalBet;
    _balance -= betTotal;
    _phase = GamePhase.spinning;
    _deleteMode = false;

    // Compute the spin result up-front so the wheel animation can begin
    // immediately. Mirrors the web app's useGameState.executeSpin order.
    final result = RNG.spinWheel(wheelType: _wheelType);
    _currentResult = result;
    notifyListeners();

    // Sync deduction with server in the background — do not block the spin
    // animation on the network round-trip.
    unawaited(
      _userService
          .updateBalance(amount: betTotal, action: 'decrement')
          .catchError((e) {
        debugPrint('GameProvider: Error decrementing balance on server: $e');
        return _balance;
      }),
    );

    return result;
  }

  /// Called when spin animation completes. Resolves payouts.
  void resolveResult() async {
    if (_currentResult == null) return;

    _phase = GamePhase.result;

    final betList = _bets.values.toList();
    final payout = Payouts.calculatePayouts(betList, _currentResult!);
    _lastPayout = payout;

    _balance += payout.totalReturned;
    notifyListeners();

    // Sync payout/return with server in the background
    if (payout.totalReturned > 0) {
      unawaited(
        _userService
            .updateBalance(amount: payout.totalReturned, action: 'increment')
            .catchError((e) {
          debugPrint('GameProvider: Error incrementing balance on server: $e');
          return _balance;
        }),
      );
    }

    // Update session stats
    final double spinBetTotal = betList.fold(0.0, (sum, b) => sum + b.amount);
    final double winAmount = payout.totalReturned - spinBetTotal;

    // Record this spin in the session history (net result + balance after).
    _logSpinToSession(spinBetTotal, winAmount, _balance);

    // Play sounds
    if (winAmount > 0) {
      soundEngine.playWinSound();
    } else if (spinBetTotal > 0) {
      soundEngine.playLossSound();
    }

    _sessionStats['lastBet'] = spinBetTotal;
    _sessionStats['lastWin'] = winAmount;
    _sessionStats['sessionWin'] = (_sessionStats['sessionWin'] ?? 0.0) + winAmount;

    // Add to history
    _history.insert(0, _currentResult!);
    if (_history.length > 25) {
      _history = _history.sublist(0, 25);
    }
    await _saveHistory();
    notifyListeners();
  }

  /// Move back to betting phase after result display.
  void startNewRound() {
    _phase = GamePhase.betting;
    _bets.clear();
    _betPlacementHistory.clear();
    _currentResult = null;
    _lastPayout = null;
    _deleteMode = false;
    notifyListeners();
  }

  void resetSessionStats() {
    _sessionStats['lastBet'] = 0.0;
    _sessionStats['lastWin'] = 0.0;
    _sessionStats['sessionWin'] = 0.0;
    notifyListeners();
  }

  // Helper storage operations
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('roulette_history');
      if (saved != null) {
        final List<dynamic> decoded = jsonDecode(saved);
        _history = decoded.map((item) => SpinResult(
          id: item['id'] ?? '',
          number: item['number'] ?? 0,
          displayNumber: item['displayNumber'] ?? '',
          color: item['color'] ?? '',
          parity: item['parity'] ?? '',
          dozen: item['dozen'] ?? '',
          column: item['column'] ?? '',
          half: item['half'] ?? '',
        )).toList();
      }
    } catch (e) {
      debugPrint('GameProvider: Error loading history: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_history.map((item) => {
        'id': item.id,
        'number': item.number,
        'displayNumber': item.displayNumber,
        'color': item.color,
        'parity': item.parity,
        'dozen': item.dozen,
        'column': item.column,
        'half': item.half,
      }).toList());
      await prefs.setString('roulette_history', encoded);
    } catch (e) {
      debugPrint('GameProvider: Error saving history: $e');
    }
  }
}
