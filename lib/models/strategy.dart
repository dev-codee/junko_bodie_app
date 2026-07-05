/// Dart model for BettingStrategy — matches the web app's Strategy.ts.
///
/// Used by the Strategy Library screen and strategy-related API calls.
library;

class StageBet {
  final String position;
  final num amount;

  const StageBet({required this.position, required this.amount});

  factory StageBet.fromJson(Map<String, dynamic> json) {
    return StageBet(
      position: json['position']?.toString() ?? '',
      amount: json['amount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'position': position,
        'amount': amount,
      };
}

class StageOptionalRules {
  final bool? resetOnAnyWin;
  final bool? resetOnProfitableSession;
  final num? resetOnProfitGoal;
  final bool? resetOnNewSessionHigh;
  final num? resetOnRecoveryAmount;
  final num? stopOnProfitGoal;
  final num? stopOnStopLoss;

  const StageOptionalRules({
    this.resetOnAnyWin,
    this.resetOnProfitableSession,
    this.resetOnProfitGoal,
    this.resetOnNewSessionHigh,
    this.resetOnRecoveryAmount,
    this.stopOnProfitGoal,
    this.stopOnStopLoss,
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
    return map;
  }
}

class StrategyStage {
  final int stageNumber;
  final List<StageBet> bets;
  final num totalWager;
  final String? notes;
  final String onWin;
  final String onLoss;
  final StageOptionalRules? optionalRules;

  const StrategyStage({
    required this.stageNumber,
    required this.bets,
    required this.totalWager,
    this.notes,
    required this.onWin,
    required this.onLoss,
    this.optionalRules,
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
      };
}

class BettingStrategy {
  final String? id;
  final String? playerId;
  final String name;
  final String wheelType;
  final String? description;
  final bool isActive;
  final int maxStages;
  final String defaultMode;
  final List<StrategyStage> stages;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BettingStrategy({
    this.id,
    this.playerId,
    required this.name,
    required this.wheelType,
    this.description,
    required this.isActive,
    required this.maxStages,
    required this.defaultMode,
    required this.stages,
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
      isActive: json['is_active'] == true,
      maxStages: json['max_stages'] ?? 10,
      defaultMode: json['default_mode']?.toString() ?? 'Manual',
      stages: (json['stages'] as List<dynamic>?)
              ?.map((s) => StrategyStage.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
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
        'is_active': isActive,
        'max_stages': maxStages,
        'default_mode': defaultMode,
        'stages': stages.map((s) => s.toJson()).toList(),
      };
}
