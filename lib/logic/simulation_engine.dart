/// Dart port of the web app's `src/lib/simulation/SimulationEngine.ts`.
///
/// Drives both the Navigator/Debugger (single-step via [runChunk]) and any
/// future mass-simulation feature. Kept behaviourally 1:1 with the web engine
/// so a strategy debugged here behaves identically to the web build.
library;

import 'dart:math';

import 'package:junko_bodie/logic/bets.dart';
import 'package:junko_bodie/logic/payouts.dart';
import 'package:junko_bodie/logic/rng.dart';
import 'package:junko_bodie/models/strategy.dart';

/// Synchronous spin generator used by the high-speed engine. Mirrors
/// `generateSyncSpin` in the web engine (fast PRNG, optional forced number).
SpinResult generateSyncSpin(WheelType wheelType, {int? forcedNumber}) {
  final pockets = wheelType == WheelType.american
      ? RNG.americanWheelOrder
      : RNG.europeanWheelOrder;
  final rnd = Random();
  final int number = (forcedNumber != null && pockets.contains(forcedNumber))
      ? forcedNumber
      : pockets[rnd.nextInt(pockets.length)];

  return SpinResult(
    id: rnd.nextInt(1 << 32).toRadixString(36),
    number: number,
    displayNumber: RNG.getDisplayNumber(number),
    color: RNG.getNumberColor(number),
    parity: RNG.getParity(number),
    dozen: RNG.getDozen(number),
    column: RNG.getColumn(number),
    half: RNG.getHalf(number),
  );
}

class SimulationConfig {
  final int requestedSpins;
  final double startingBankroll;
  final bool resetBankrollOnSessionEnd;

  /// 'immediate' | 'x_misses'
  final String entryTrigger;
  final int missesRequired;

  const SimulationConfig({
    this.requestedSpins = 999999,
    required this.startingBankroll,
    this.resetBankrollOnSessionEnd = false,
    this.entryTrigger = 'immediate',
    this.missesRequired = 1,
  });
}

/// Snapshot of the engine's live internal state, consumed by the Debugger UI.
class SimulationState {
  final double activeBankroll;
  final double peakBankroll;
  final int currentStageIndex;
  final int sessionSpins;
  final double sessionProfit;
  final List<StageBet> currentActiveBets;
  final bool isSessionActive;
  final int totalSpinsExecuted;
  final int totalCompletedSessions;
  final int winningSessionsCount;
  final int losingSessionsCount;
  final double totalAggregatedProfit;

  const SimulationState({
    required this.activeBankroll,
    required this.peakBankroll,
    required this.currentStageIndex,
    required this.sessionSpins,
    required this.sessionProfit,
    required this.currentActiveBets,
    required this.isSessionActive,
    required this.totalSpinsExecuted,
    required this.totalCompletedSessions,
    required this.winningSessionsCount,
    required this.losingSessionsCount,
    required this.totalAggregatedProfit,
  });
}

class SimulationResult {
  final String strategyId;
  final String strategyName;
  final int totalSpinsRequested;
  final int totalSpinsExecuted;
  final int totalSessions;
  final double startingBankroll;
  final double endingBankroll;
  final double highestBankroll;
  final double lowestBankroll;
  final double netProfit;
  final int winningSessions;
  final int losingSessions;
  final int bankruptcyCount;
  final double maxDrawdown;
  final int maxWinStreak;
  final int maxLossStreak;
  final double averageSpinsPerSession;
  final double averageProfitPerSession;
  final double averageProfitPerSpin;
  final double systemSuccessRatio;
  final List<Point<double>> history;
  final Map<String, int> stageHits;

  const SimulationResult({
    required this.strategyId,
    required this.strategyName,
    required this.totalSpinsRequested,
    required this.totalSpinsExecuted,
    required this.totalSessions,
    required this.startingBankroll,
    required this.endingBankroll,
    required this.highestBankroll,
    required this.lowestBankroll,
    required this.netProfit,
    required this.winningSessions,
    required this.losingSessions,
    required this.bankruptcyCount,
    required this.maxDrawdown,
    required this.maxWinStreak,
    required this.maxLossStreak,
    required this.averageSpinsPerSession,
    required this.averageProfitPerSession,
    required this.averageProfitPerSpin,
    required this.systemSuccessRatio,
    required this.history,
    required this.stageHits,
  });

  Map<String, dynamic> toJson() => {
        'strategyId': strategyId,
        'strategyName': strategyName,
        'totalSpinsRequested': totalSpinsRequested,
        'totalSpinsExecuted': totalSpinsExecuted,
        'totalSessions': totalSessions,
        'startingBankroll': startingBankroll,
        'endingBankroll': endingBankroll,
        'highestBankroll': highestBankroll,
        'lowestBankroll': lowestBankroll,
        'netProfit': netProfit,
        'winningSessions': winningSessions,
        'losingSessions': losingSessions,
        'bankruptcyCount': bankruptcyCount,
        'maxDrawdown': maxDrawdown,
        'maxWinStreak': maxWinStreak,
        'maxLossStreak': maxLossStreak,
        'averageSpinsPerSession': averageSpinsPerSession,
        'averageProfitPerSession': averageProfitPerSession,
        'averageProfitPerSpin': averageProfitPerSpin,
        'systemSuccessRatio': systemSuccessRatio,
        'history': history.map((p) => {'x': p.x, 'y': p.y}).toList(),
        'stageHits': stageHits,
      };

  factory SimulationResult.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;
    return SimulationResult(
      strategyId: json['strategyId']?.toString() ?? '',
      strategyName: json['strategyName']?.toString() ?? '',
      totalSpinsRequested: i(json['totalSpinsRequested']),
      totalSpinsExecuted: i(json['totalSpinsExecuted']),
      totalSessions: i(json['totalSessions']),
      startingBankroll: d(json['startingBankroll']),
      endingBankroll: d(json['endingBankroll']),
      highestBankroll: d(json['highestBankroll']),
      lowestBankroll: d(json['lowestBankroll']),
      netProfit: d(json['netProfit']),
      winningSessions: i(json['winningSessions']),
      losingSessions: i(json['losingSessions']),
      bankruptcyCount: i(json['bankruptcyCount']),
      maxDrawdown: d(json['maxDrawdown']),
      maxWinStreak: i(json['maxWinStreak']),
      maxLossStreak: i(json['maxLossStreak']),
      averageSpinsPerSession: d(json['averageSpinsPerSession']),
      averageProfitPerSession: d(json['averageProfitPerSession']),
      averageProfitPerSpin: d(json['averageProfitPerSpin']),
      systemSuccessRatio: d(json['systemSuccessRatio']),
      history: (json['history'] as List<dynamic>? ?? [])
          .map((p) => Point<double>(
                ((p as Map)['x'] as num).toDouble(),
                (p['y'] as num).toDouble(),
              ))
          .toList(),
      stageHits: (json['stageHits'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }
}

class SimulationEngine {
  final BettingStrategy strategy;
  final SimulationConfig config;

  // Global state
  double _activeBankroll;
  double _peakBankroll;
  double _valleyBankroll;
  int _totalSpinsExecuted = 0;
  int _totalCompletedSessions = 0;

  // Stat aggregators
  double _absMaxDrawdown = 0;
  int _winningSessionsCount = 0;
  int _losingSessionsCount = 0;
  int _bankruptcyCount = 0;
  int _currentWinStreak = 0;
  int _currentLossStreak = 0;
  int _maxWinStreakCount = 0;
  int _maxLossStreakCount = 0;
  int _sumSessionSpins = 0;
  double _totalAggregatedProfit = 0;
  final List<Point<double>> _bankrollHistory = [];
  final Map<String, int> _stageHitCount = {};

  // Session state
  bool _isSessionActive = false;
  bool _isEndgameRecoveryActive = false;
  int _currentStageIndex = 0;
  int _sessionSpins = 0;
  double _sessionProfit = 0;

  // Phantom state
  int _consecutiveMisses = 0;

  // Active bets memory (mutated dynamically by rules)
  List<StageBet> _currentActiveBets = [];
  final Set<String> _sessionRemovedGroupIds = {};

  // Debugger trackers
  SpinResult? lastSpinResult;
  PayoutResult? lastPayoutResult;
  String lastBaselineAction = '';

  SimulationEngine(this.strategy, this.config)
      : _activeBankroll = config.startingBankroll,
        _peakBankroll = config.startingBankroll,
        _valleyBankroll = config.startingBankroll;

  WheelType get _wheelType =>
      strategy.wheelType.toLowerCase() == 'european'
          ? WheelType.european
          : WheelType.american;

  /// Runs [chunkSize] spins (optionally forcing the first spin's number).
  /// Returns true when the whole simulation is complete.
  bool runChunk(int chunkSize, {int? forcedNumber}) {
    int spinsThisChunk = 0;

    // `forceSpins` is always true in the web engine, so a chunk always runs its
    // requested number of spins; the request-cap check happens per-iteration.
    while (spinsThisChunk < chunkSize) {
      if (_totalSpinsExecuted >= config.requestedSpins && !_isSessionActive) {
        return true;
      }

      final spinResult = generateSyncSpin(_wheelType, forcedNumber: forcedNumber);
      _totalSpinsExecuted++;
      spinsThisChunk++;

      lastSpinResult = spinResult;

      if (!_isSessionActive) {
        // Phase A: pre-trigger phantom betting evaluation.
        lastPayoutResult = PayoutResult(
          outcomes: const [],
          totalWagered: 0,
          totalWon: 0,
          netResult: 0,
          totalReturned: 0,
        );
        lastBaselineAction = '';
        if (config.entryTrigger == 'immediate') {
          _startNewSession();
          _executeSpinPlay(spinResult);
        } else if (config.entryTrigger == 'x_misses') {
          final phantomPayout =
              _calculatePhantomPayout(spinResult, strategy.stages[0].bets);
          if (phantomPayout.netResult < 0) {
            _consecutiveMisses++;
            if (_consecutiveMisses >= config.missesRequired) {
              _startNewSession();
            }
          } else {
            _consecutiveMisses = 0;
          }
        }
      } else {
        // Phase B: active session execution.
        _executeSpinPlay(spinResult);
      }
    }

    return _totalSpinsExecuted >= config.requestedSpins && !_isSessionActive;
  }

  SimulationState getInternalState() => SimulationState(
        activeBankroll: _activeBankroll,
        peakBankroll: _peakBankroll,
        currentStageIndex: _currentStageIndex,
        sessionSpins: _sessionSpins,
        sessionProfit: _sessionProfit,
        currentActiveBets: _currentActiveBets,
        isSessionActive: _isSessionActive,
        totalSpinsExecuted: _totalSpinsExecuted,
        totalCompletedSessions: _totalCompletedSessions,
        winningSessionsCount: _winningSessionsCount,
        losingSessionsCount: _losingSessionsCount,
        totalAggregatedProfit: _totalAggregatedProfit,
      );

  SimulationResult getResults() {
    final avgSpins = _totalCompletedSessions > 0
        ? _sumSessionSpins / _totalCompletedSessions
        : 0.0;
    final avgProfit = _totalCompletedSessions > 0
        ? _totalAggregatedProfit / _totalCompletedSessions
        : 0.0;
    final totalProfit =
        _totalAggregatedProfit + (_isSessionActive ? _sessionProfit : 0);
    final avgProfitPerSpin =
        _totalSpinsExecuted > 0 ? totalProfit / _totalSpinsExecuted : 0.0;
    final successRatio = _totalCompletedSessions > 0
        ? (_winningSessionsCount / _totalCompletedSessions) * 100
        : 0.0;

    double round2(num v) => double.parse(v.toStringAsFixed(2));

    return SimulationResult(
      strategyId: strategy.id ?? '',
      strategyName: strategy.name,
      totalSpinsRequested: config.requestedSpins,
      totalSpinsExecuted: _totalSpinsExecuted,
      totalSessions: _totalCompletedSessions,
      startingBankroll: config.startingBankroll,
      endingBankroll: _activeBankroll,
      highestBankroll: _peakBankroll,
      lowestBankroll: _valleyBankroll,
      netProfit: totalProfit.toDouble(),
      winningSessions: _winningSessionsCount,
      losingSessions: _losingSessionsCount,
      bankruptcyCount: _bankruptcyCount,
      maxDrawdown: _absMaxDrawdown,
      maxWinStreak: _maxWinStreakCount,
      maxLossStreak: _maxLossStreakCount,
      averageSpinsPerSession: round2(avgSpins),
      averageProfitPerSession: round2(avgProfit),
      averageProfitPerSpin: round2(avgProfitPerSpin),
      systemSuccessRatio: round2(successRatio),
      history: _bankrollHistory,
      stageHits: _stageHitCount,
    );
  }

  void _startNewSession() {
    if (config.resetBankrollOnSessionEnd && _totalCompletedSessions > 0) {
      _activeBankroll = config.startingBankroll;
    }

    if (_activeBankroll <= 0) {
      _isSessionActive = false;
      return;
    }

    _sessionRemovedGroupIds.clear();
    _isSessionActive = true;
    _isEndgameRecoveryActive = false;
    _currentStageIndex = 0;
    _sessionSpins = 0;
    _sessionProfit = 0;
    _consecutiveMisses = 0;
    _loadStageBets(0);
  }

  /// Attempt End-Game Recovery: when every tagged group has been won and the
  /// session is still negative, deploy the configured recovery bets sized to
  /// break even.
  void _tryEndgameRecovery() {
    final cfg = strategy.endgameRecovery;
    if (cfg == null || !cfg.enabled) return;

    if (_sessionProfit >= 0) {
      _isEndgameRecoveryActive = false;
      return;
    }

    if (_currentActiveBets.isNotEmpty && !_isEndgameRecoveryActive) return;

    final positions = cfg.recoveryBets;
    if (positions.isEmpty) return;

    final deficit = _sessionProfit.abs();
    final minPayoutMult = positions
        .map((b) => (Bets.betMap[b.position]?.payout ?? 17))
        .reduce(min);
    final unitProfit = (minPayoutMult + 1) - positions.length;
    num requiredBet = cfg.fallbackAmount ?? 10;
    if (unitProfit > 0) {
      requiredBet = (deficit / unitProfit).ceil();
    }
    _currentActiveBets = positions
        .map((rb) => StageBet(position: rb.position, amount: requiredBet))
        .toList();

    _isEndgameRecoveryActive = true;
  }

  void _loadStageBets(int stageIndex) {
    if (stageIndex < 0 || stageIndex >= strategy.stages.length) return;
    final stage = strategy.stages[stageIndex];

    _currentActiveBets = stage.bets
        .where((b) =>
            b.groupId == null || !_sessionRemovedGroupIds.contains(b.groupId))
        .map((b) => b.clone())
        .toList();

    _tryEndgameRecovery();

    final stageName = 'Stage ${stageIndex + 1}';
    _stageHitCount[stageName] = (_stageHitCount[stageName] ?? 0) + 1;
  }

  PayoutResult _calculatePhantomPayout(SpinResult spinResult, List<StageBet> bets) {
    final placedBets = bets
        .map((b) => PlacedBet(
              betId: b.position,
              amount: b.amount.toDouble(),
              chips: [b.amount.toDouble()],
              playerInitial: 'S',
            ))
        .toList();
    return Payouts.calculatePayouts(placedBets, spinResult);
  }

  void _executeSpinPlay(SpinResult spinResult) {
    if (_activeBankroll <= 0) {
      _bankruptcyCount++;
      lastBaselineAction = 'stop';
      _endSession();
      return;
    }

    final totalWager =
        _currentActiveBets.fold<double>(0, (sum, b) => sum + b.amount);

    // Empty-board reset rule.
    if (_currentActiveBets.isEmpty &&
        (strategy.stages[_currentStageIndex].optionalRules?.resetOnEmptyBoard ??
            false)) {
      lastBaselineAction = 'reset';
      _endSession();
      return;
    }

    if (totalWager > _activeBankroll) {
      _activeBankroll = 0;
      _bankruptcyCount++;
      lastBaselineAction = 'stop';
      _endSession();
      return;
    }

    _sessionSpins++;
    final stage = strategy.stages[_currentStageIndex];
    final payout = _calculatePhantomPayout(spinResult, _currentActiveBets);
    lastPayoutResult = payout;

    _activeBankroll += payout.netResult;
    _sessionProfit += payout.netResult;

    if (_activeBankroll <= 0) {
      _activeBankroll = 0;
      _bankruptcyCount++;
      lastBaselineAction = 'stop';
      _endSession();
      return;
    }

    if (_activeBankroll > _peakBankroll) _peakBankroll = _activeBankroll;
    if (_activeBankroll < _valleyBankroll) _valleyBankroll = _activeBankroll;

    final currentDrawdown = _peakBankroll - _activeBankroll;
    if (currentDrawdown > _absMaxDrawdown) _absMaxDrawdown = currentDrawdown;

    // Recovery lock — bypass normal stage progression while active.
    if (_isEndgameRecoveryActive) {
      if (_sessionProfit >= 0) {
        _isEndgameRecoveryActive = false;
        lastBaselineAction = 'reset';
        _endSession();
      } else {
        lastBaselineAction = 'recovery';
        _tryEndgameRecovery();
      }
      return;
    }

    final isWin = payout.netResult > 0;
    var baselineAction = isWin ? stage.onWin : stage.onLoss;

    final rules = stage.optionalRules;
    if (rules != null) {
      if ((rules.resetOnAnyWin ?? false) && isWin) baselineAction = 'reset';
      if ((rules.resetOnProfitableSession ?? false) && _sessionProfit >= 0) {
        baselineAction = 'reset';
      }
      if ((rules.resetOnNewSessionHigh ?? false) &&
          _activeBankroll >= _peakBankroll) {
        baselineAction = 'reset';
      }
      if (rules.resetOnProfitGoal != null &&
          _sessionProfit >= rules.resetOnProfitGoal!) {
        baselineAction = 'reset';
      }
      if (rules.stopOnStopLoss != null &&
          _sessionProfit <= -(rules.stopOnStopLoss!)) {
        baselineAction = 'stop';
      }
    }

    if (stage.dynamicRules != null && stage.dynamicRules!.isNotEmpty) {
      _processDynamicRules(stage.dynamicRules!, isWin, payout);
    }

    lastBaselineAction = baselineAction;

    if (baselineAction == 'next') {
      if (_currentStageIndex + 1 < strategy.stages.length) {
        _currentStageIndex++;
        _loadStageBets(_currentStageIndex);
      } else {
        _endSession();
      }
    } else if (baselineAction == 'reset') {
      _endSession();
    } else if (baselineAction == 'stop' || baselineAction == 'manual') {
      _endSession();
    } else if (baselineAction == 'repeat') {
      // Repeat the current stage. Dynamic rules may already have adjusted bets.
    } else if (baselineAction.startsWith('jump_')) {
      final targetStageNum = int.tryParse(baselineAction.split('_')[1]) ?? 0;
      final targetIndex = targetStageNum - 1;
      if (targetIndex >= 0 && targetIndex < strategy.stages.length) {
        _currentStageIndex = targetIndex;
        _loadStageBets(targetIndex);
      } else {
        _endSession();
      }
    }
  }

  void _processDynamicRules(
      List<DynamicRule> rules, bool isWin, PayoutResult payout) {
    for (final rule in rules) {
      var conditionMet = false;
      final anyBetWon = payout.outcomes.any((o) => o.isWin);
      final isWinCond = isWin || anyBetWon;

      if (rule.condition == RuleCondition.win && isWinCond) conditionMet = true;
      if (rule.condition == RuleCondition.loss && !isWinCond) {
        conditionMet = true;
      }
      if (rule.condition == RuleCondition.winSessionLoss &&
          isWinCond &&
          _sessionProfit < 0) {
        conditionMet = true;
      }
      if (rule.condition == RuleCondition.lossSessionLoss &&
          !isWinCond &&
          _sessionProfit < 0) {
        conditionMet = true;
      }
      if (rule.condition == RuleCondition.winSessionHighNotReached &&
          isWinCond &&
          _activeBankroll < _peakBankroll) {
        conditionMet = true;
      }
      if (rule.condition == RuleCondition.any) conditionMet = true;
      if (rule.condition == RuleCondition.oneGroupRemainsAndNegativeProfit) {
        final uniqueGroups = _currentActiveBets
            .map((b) => b.groupId)
            .where((g) => g != null)
            .toSet();
        if (uniqueGroups.length == 1 && _sessionProfit < 0) conditionMet = true;
      }

      if (!conditionMet) continue;

      // Identify targets.
      List<StageBet> affectedBets = [];
      if (rule.target == RuleTarget.allBets) {
        affectedBets = _currentActiveBets;
      } else if (rule.target == RuleTarget.winningBets) {
        affectedBets = _currentActiveBets
            .where((b) => payout.outcomes
                .any((o) => o.betId == b.position && o.isWin))
            .toList();
      } else if (rule.target == RuleTarget.losingBets) {
        affectedBets = _currentActiveBets
            .where((b) => payout.outcomes
                .any((o) => o.betId == b.position && !o.isWin))
            .toList();
      } else if (rule.target == RuleTarget.winningGroup) {
        final winningGroups = _currentActiveBets
            .where((b) =>
                payout.outcomes.any((o) => o.betId == b.position && o.isWin))
            .map((b) => b.groupId)
            .where((g) => g != null)
            .toSet();
        affectedBets = _currentActiveBets
            .where((b) => b.groupId != null && winningGroups.contains(b.groupId))
            .toList();
      } else if (rule.target == RuleTarget.losingGroup) {
        final losingGroups = _currentActiveBets
            .where((b) =>
                payout.outcomes.any((o) => o.betId == b.position && !o.isWin))
            .map((b) => b.groupId)
            .where((g) => g != null)
            .toSet();
        affectedBets = _currentActiveBets
            .where((b) => b.groupId != null && losingGroups.contains(b.groupId))
            .toList();
      }

      // Apply action.
      if (rule.action == RuleActionType.remove) {
        for (final b in affectedBets) {
          if (b.groupId != null) _sessionRemovedGroupIds.add(b.groupId!);
        }
        final affectedPositions = affectedBets.map((b) => b.position).toSet();
        _currentActiveBets = _currentActiveBets
            .where((b) => !affectedPositions.contains(b.position))
            .toList();
      } else if (rule.action == RuleActionType.multiply) {
        final multiplier = rule.value ?? 1;
        for (final b in affectedBets) {
          b.amount *= multiplier;
        }
      } else if (rule.action == RuleActionType.add) {
        final units = rule.value ?? 0;
        for (final b in affectedBets) {
          b.amount += units;
        }
      } else if (rule.action == RuleActionType.set) {
        final newAmount = rule.value ?? 0;
        for (final b in affectedBets) {
          b.amount = newAmount;
        }
      } else if (rule.action == RuleActionType.setBreakEven) {
        final deficit = _sessionProfit.abs();
        if (deficit > 0 && affectedBets.isNotEmpty) {
          final minPayoutMult = affectedBets
              .map((b) => (Bets.betMap[b.position]?.payout ?? 0))
              .reduce(min);
          final unitProfit = (minPayoutMult + 1) - affectedBets.length;
          num requiredBet = rule.value ?? 10;
          if (unitProfit > 0) {
            requiredBet = (deficit / unitProfit).ceil();
          }
          for (final b in affectedBets) {
            b.amount = requiredBet;
          }
        }
      }
    }

    // Fire recovery immediately after dynamic rules remove the last group.
    _tryEndgameRecovery();
  }

  void _endSession() {
    _isSessionActive = false;
    _totalCompletedSessions++;
    _sumSessionSpins += _sessionSpins;
    _totalAggregatedProfit += _sessionProfit;

    if (_sessionProfit >= 0) {
      _winningSessionsCount++;
      _currentWinStreak++;
      _currentLossStreak = 0;
      if (_currentWinStreak > _maxWinStreakCount) {
        _maxWinStreakCount = _currentWinStreak;
      }
    } else {
      _losingSessionsCount++;
      _currentLossStreak++;
      _currentWinStreak = 0;
      if (_currentLossStreak > _maxLossStreakCount) {
        _maxLossStreakCount = _currentLossStreak;
      }
    }

    final sampleEvery = max(1, (config.requestedSpins / 50000).floor());
    if (_totalCompletedSessions % sampleEvery == 0) {
      _bankrollHistory.add(
          Point(_totalCompletedSessions.toDouble(), _activeBankroll));
    }
  }
}
