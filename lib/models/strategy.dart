/// Dart model for BettingStrategy — matches the web app's Strategy.ts.
///
/// Used by the Strategy Library screen, the Strategy Builder, the Navigator /
/// Debugger and the simulation engine. Kept 1:1 with the web JSON shape so the
/// same documents round-trip through the shared `/api/strategies` endpoints.
library;

// ─── Result actions ─────────────────────────────────────────────────────────
// String-typed to mirror the web's `StageResultAction`, which includes the
// dynamic `jump_<n>` variants. Helpers below keep usage consistent.
class StageResultAction {
  static const String next = 'next';
  static const String repeat = 'repeat';
  static const String reset = 'reset';
  static const String stop = 'stop';
  static const String manual = 'manual';

  /// `jump_3` → jump to stage 3.
  static String jump(int stageNumber) => 'jump_$stageNumber';
  static bool isJump(String action) => action.startsWith('jump_');
  static int? jumpTarget(String action) =>
      isJump(action) ? int.tryParse(action.split('_')[1]) : null;
}

// ─── Dynamic (advanced) rules ───────────────────────────────────────────────
/// Condition that must be met for a dynamic rule to fire.
class RuleCondition {
  static const String win = 'win';
  static const String loss = 'loss';
  static const String winSessionLoss = 'win_session_loss';
  static const String winSessionProfit = 'win_session_profit';
  static const String lossSessionLoss = 'loss_session_loss';
  static const String lossSessionProfit = 'loss_session_profit';
  static const String any = 'any';
  static const String winSessionHighNotReached = 'win_session_high_not_reached';
  static const String oneGroupRemainsAndNegativeProfit =
      '1_group_remains_and_negative_profit';
}

/// Which placed bets a dynamic rule targets.
class RuleTarget {
  static const String winningBets = 'winning_bets';
  static const String losingBets = 'losing_bets';
  static const String allBets = 'all_bets';
  static const String winningGroup = 'winning_group';
  static const String losingGroup = 'losing_group';
}

/// What the dynamic rule does to the targeted bets.
class RuleActionType {
  static const String remove = 'remove';
  static const String multiply = 'multiply';
  static const String add = 'add';
  static const String set = 'set';
  static const String setBreakEven = 'set_break_even';
}

class DynamicRule {
  final String id;
  String condition;
  String target;
  String action;
  num? value;

  DynamicRule({
    required this.id,
    required this.condition,
    required this.target,
    required this.action,
    this.value,
  });

  factory DynamicRule.fromJson(Map<String, dynamic> json) => DynamicRule(
        id: json['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        condition: json['condition']?.toString() ?? RuleCondition.win,
        target: json['target']?.toString() ?? RuleTarget.allBets,
        action: json['action']?.toString() ?? RuleActionType.multiply,
        value: json['value'] as num?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'condition': condition,
        'target': target,
        'action': action,
        if (value != null) 'value': value,
      };

  DynamicRule clone() => DynamicRule(
        id: id,
        condition: condition,
        target: target,
        action: action,
        value: value,
      );
}

// ─── Stage bet ──────────────────────────────────────────────────────────────
class StageBet {
  final String position;
  num amount;

  /// Optional tag (e.g. "A", "B") used by group-based dynamic rules and the
  /// End-Game Recovery engine.
  String? groupId;

  StageBet({required this.position, required this.amount, this.groupId});

  factory StageBet.fromJson(Map<String, dynamic> json) {
    return StageBet(
      position: json['position']?.toString() ?? '',
      amount: json['amount'] ?? 0,
      groupId: json['groupId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'position': position,
        'amount': amount,
        if (groupId != null && groupId!.isNotEmpty) 'groupId': groupId,
      };

  StageBet clone() =>
      StageBet(position: position, amount: amount, groupId: groupId);
}

// ─── Optional safety / profit rules ─────────────────────────────────────────
class StageOptionalRules {
  bool? resetOnAnyWin;
  bool? resetOnProfitableSession;
  num? resetOnProfitGoal;
  bool? resetOnNewSessionHigh;
  num? resetOnRecoveryAmount;
  num? stopOnProfitGoal;
  num? stopOnStopLoss;
  bool? resetOnEmptyBoard;

  StageOptionalRules({
    this.resetOnAnyWin,
    this.resetOnProfitableSession,
    this.resetOnProfitGoal,
    this.resetOnNewSessionHigh,
    this.resetOnRecoveryAmount,
    this.stopOnProfitGoal,
    this.stopOnStopLoss,
    this.resetOnEmptyBoard,
  });

  factory StageOptionalRules.fromJson(Map<String, dynamic> json) {
    return StageOptionalRules(
      resetOnAnyWin: json['reset_on_any_win'] as bool?,
      resetOnProfitableSession: json['reset_on_profitable_session'] as bool?,
      resetOnProfitGoal: json['reset_on_profit_goal'] as num?,
      resetOnNewSessionHigh: json['reset_on_new_session_high'] as bool?,
      resetOnRecoveryAmount: json['reset_on_recovery_amount'] as num?,
      stopOnProfitGoal: json['stop_on_profit_goal'] as num?,
      stopOnStopLoss: json['stop_on_stop_loss'] as num?,
      resetOnEmptyBoard: json['reset_on_empty_board'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (resetOnAnyWin != null) map['reset_on_any_win'] = resetOnAnyWin;
    if (resetOnProfitableSession != null) {
      map['reset_on_profitable_session'] = resetOnProfitableSession;
    }
    if (resetOnProfitGoal != null) {
      map['reset_on_profit_goal'] = resetOnProfitGoal;
    }
    if (resetOnNewSessionHigh != null) {
      map['reset_on_new_session_high'] = resetOnNewSessionHigh;
    }
    if (resetOnRecoveryAmount != null) {
      map['reset_on_recovery_amount'] = resetOnRecoveryAmount;
    }
    if (stopOnProfitGoal != null) map['stop_on_profit_goal'] = stopOnProfitGoal;
    if (stopOnStopLoss != null) map['stop_on_stop_loss'] = stopOnStopLoss;
    if (resetOnEmptyBoard != null) {
      map['reset_on_empty_board'] = resetOnEmptyBoard;
    }
    return map;
  }

  StageOptionalRules clone() => StageOptionalRules(
        resetOnAnyWin: resetOnAnyWin,
        resetOnProfitableSession: resetOnProfitableSession,
        resetOnProfitGoal: resetOnProfitGoal,
        resetOnNewSessionHigh: resetOnNewSessionHigh,
        resetOnRecoveryAmount: resetOnRecoveryAmount,
        stopOnProfitGoal: stopOnProfitGoal,
        stopOnStopLoss: stopOnStopLoss,
        resetOnEmptyBoard: resetOnEmptyBoard,
      );
}

// ─── Strategy stage ─────────────────────────────────────────────────────────
class StrategyStage {
  int stageNumber;
  List<StageBet> bets;
  num totalWager;
  String? notes;
  String onWin;
  String onLoss;
  StageOptionalRules? optionalRules;
  List<DynamicRule>? dynamicRules;

  StrategyStage({
    required this.stageNumber,
    required this.bets,
    required this.totalWager,
    this.notes,
    required this.onWin,
    required this.onLoss,
    this.optionalRules,
    this.dynamicRules,
  });

  factory StrategyStage.fromJson(Map<String, dynamic> json) {
    return StrategyStage(
      stageNumber: json['stage_number'] ?? 1,
      bets: (json['bets'] as List<dynamic>?)
              ?.map((b) => StageBet.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      totalWager: json['total_wager'] ?? 0,
      notes: json['notes']?.toString(),
      onWin: json['on_win']?.toString() ?? 'reset',
      onLoss: json['on_loss']?.toString() ?? 'next',
      optionalRules: json['optional_rules'] != null
          ? StageOptionalRules.fromJson(
              json['optional_rules'] as Map<String, dynamic>)
          : null,
      dynamicRules: (json['dynamic_rules'] as List<dynamic>?)
          ?.map((r) => DynamicRule.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'stage_number': stageNumber,
        'bets': bets.map((b) => b.toJson()).toList(),
        'total_wager': totalWager,
        if (notes != null) 'notes': notes,
        'on_win': onWin,
        'on_loss': onLoss,
        if (optionalRules != null) 'optional_rules': optionalRules!.toJson(),
        if (dynamicRules != null && dynamicRules!.isNotEmpty)
          'dynamic_rules': dynamicRules!.map((r) => r.toJson()).toList(),
      };

  StrategyStage clone() => StrategyStage(
        stageNumber: stageNumber,
        bets: bets.map((b) => b.clone()).toList(),
        totalWager: totalWager,
        notes: notes,
        onWin: onWin,
        onLoss: onLoss,
        optionalRules: optionalRules?.clone(),
        dynamicRules: dynamicRules?.map((r) => r.clone()).toList(),
      );
}

// ─── Global End-Game Recovery config ────────────────────────────────────────
/// Set ONCE for the entire strategy. When every tagged group has been won but
/// session profit is still negative, the engine auto-deploys `recoveryBets` at a
/// calculated break-even amount.
class EndgameRecoveryConfig {
  bool enabled;
  List<StageBet> recoveryBets;
  num? fallbackAmount;

  EndgameRecoveryConfig({
    this.enabled = false,
    List<StageBet>? recoveryBets,
    this.fallbackAmount = 10,
  }) : recoveryBets = recoveryBets ?? [];

  factory EndgameRecoveryConfig.fromJson(Map<String, dynamic> json) {
    return EndgameRecoveryConfig(
      enabled: json['enabled'] == true,
      recoveryBets: (json['recovery_bets'] as List<dynamic>?)
              ?.map((b) => StageBet.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      fallbackAmount: json['fallback_amount'] as num? ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'recovery_bets': recoveryBets.map((b) => b.toJson()).toList(),
        if (fallbackAmount != null) 'fallback_amount': fallbackAmount,
      };
}

// ─── Betting strategy ───────────────────────────────────────────────────────
class BettingStrategy {
  final String? id;
  final String? playerId;
  final String name;

  /// 'American' | 'European' | 'Both'
  final String wheelType;
  final String? description;
  final String? strategyNotes;
  final bool isActive;
  final bool isGlobal;
  final int maxStages;
  final String defaultMode;
  final List<StrategyStage> stages;
  final EndgameRecoveryConfig? endgameRecovery;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BettingStrategy({
    this.id,
    this.playerId,
    required this.name,
    required this.wheelType,
    this.description,
    this.strategyNotes,
    required this.isActive,
    this.isGlobal = false,
    required this.maxStages,
    required this.defaultMode,
    required this.stages,
    this.endgameRecovery,
    this.createdAt,
    this.updatedAt,
  });

  factory BettingStrategy.fromJson(Map<String, dynamic> json) {
    return BettingStrategy(
      id: json['_id']?.toString(),
      playerId: json['player_id']?.toString(),
      name: json['name']?.toString() ?? 'Untitled',
      wheelType: json['wheel_type']?.toString() ?? 'American',
      description: json['description']?.toString(),
      strategyNotes: json['strategy_notes']?.toString(),
      isActive: json['is_active'] == true,
      isGlobal: json['is_global'] == true,
      maxStages: json['max_stages'] ?? 10,
      defaultMode: json['default_mode']?.toString() ?? 'Manual',
      stages: (json['stages'] as List<dynamic>?)
              ?.map((s) => StrategyStage.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      endgameRecovery: json['endgame_recovery'] != null
          ? EndgameRecoveryConfig.fromJson(
              json['endgame_recovery'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) '_id': id,
        'name': name,
        'wheel_type': wheelType,
        'description': description ?? '',
        'strategy_notes': strategyNotes ?? '',
        'is_active': isActive,
        'is_global': isGlobal,
        'max_stages': maxStages,
        'default_mode': defaultMode,
        'stages': stages.map((s) => s.toJson()).toList(),
        if (endgameRecovery != null)
          'endgame_recovery': endgameRecovery!.toJson(),
      };
}
