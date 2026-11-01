import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:junko_bodie/logic/bets.dart';
import 'package:junko_bodie/logic/simulation_engine.dart';
import 'package:junko_bodie/models/strategy.dart';

BettingStrategy fixture(String name, {bool reset = true, int anchor = 3}) {
  final strategy = BettingStrategy.fromJson(
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  for (final stage in strategy.stages) {
    if (!reset) {
      stage.optionalRules!.resetOnProfitableSession = false;
      stage.optionalRules!.resetOnNewSessionHigh = false;
    }
    for (final rule in stage.dynamicRules!) {
      if (rule.target == RuleTarget.specificGroup) {
        rule.winCountThreshold = anchor;
      }
    }
  }
  return strategy;
}

SimulationEngine engine(BettingStrategy strategy) => SimulationEngine(
  strategy,
  const SimulationConfig(startingBankroll: 100000),
);
SimulationState spin(SimulationEngine engine, int number) {
  engine.runChunk(1, forcedNumber: number);
  return engine.getInternalState();
}

Set<String> positions(SimulationState state) =>
    state.currentActiveBets.map((b) => b.position).toSet();

void main() {
  test('new rule fields survive JSON and stage cloning', () {
    final data = <String, dynamic>{
      'id': 'r',
      'condition': 'group_win_threshold',
      'target': 'specific_group',
      'action': 'remove',
      'exempt_group': 'A',
      'target_group': 'E',
      'win_count_threshold': 6,
      'dozen_number': 2,
    };
    expect(DynamicRule.fromJson(data).clone().toJson(), data);
    final strategy = fixture('moneyball');
    expect(
      strategy.stages.first.clone().toJson(),
      strategy.stages.first.toJson(),
    );
  });
  test('dozen mapping excludes zeros, crossing bets and unknown IDs', () {
    expect(getBetDozen('dozen-2nd'), 2);
    expect(getBetDozen('split-1-2'), 1);
    expect(getBetDozen('straight-36'), 3);
    for (final id in [
      'split-0-00',
      'straight-0',
      'straight-00',
      'split-10-13',
      'unknown',
    ]) {
      expect(getBetDozen(id), isNull);
    }
  });
  for (final entry in {
    'moneyball': [14, 4],
    'spin_2_win': [1, 37],
  }.entries) {
    for (final number in entry.value) {
      test(
        '${entry.key}: opening $number payout, reset, full next session',
        () {
          final e = engine(fixture(entry.key));
          final state = spin(e, number);
          final profit = entry.key == 'moneyball' ? (number == 14 ? 4 : 10) : 5;
          expect(state.sessionProfit, profit);
          expect(state.activeBankroll, 100000 + profit);
          expect(state.totalCompletedSessions, 1);
          expect(state.isSessionActive, false);
          expect(e.lastBaselineAction, 'reset');
          final next = spin(e, entry.key == 'moneyball' ? 2 : 3);
          expect(
            next.currentActiveBets.length,
            entry.key == 'moneyball' ? 17 : 13,
          );
          expect(next.currentStageIndex, 1);
        },
      );
    }
  }
  for (final name in ['moneyball', 'spin_2_win']) {
    test('$name: full twelve-stage loss ladder and final reset', () {
      final e = engine(fixture(name));
      const ladder = [1, 2, 3, 4, 6, 8, 10, 15, 20, 25, 30, 40];
      for (var stage = 1; stage < 12; stage++) {
        final state = spin(e, name == 'moneyball' ? 2 : 3);
        expect(state.currentStageIndex, stage);
        for (final bet in state.currentActiveBets) {
          expect(bet.amount, bet.position == 'dozen-2nd' ? 10 : ladder[stage]);
        }
      }
      expect(spin(e, name == 'moneyball' ? 2 : 3).isSessionActive, false);
    });
  }
  test('Moneyball retires entire group and preserves retirement on loss', () {
    final e = engine(fixture('moneyball', reset: false));
    expect(spin(e, 4).currentActiveBets.length, 13);
    final state = spin(e, 2);
    expect(state.currentActiveBets.length, 13);
    expect(state.currentActiveBets.any((b) => b.groupId == 'A'), false);
    expect(state.currentStageIndex, 1);
  });
  for (final threshold in [3, 6]) {
    test(
      'Moneyball anchor retires after $threshold own hits across stages',
      () {
        final e = engine(fixture('moneyball', reset: false, anchor: threshold));
        spin(e, 1); // Other group must not count toward E.
        for (var hit = 1; hit <= threshold; hit++) {
          final state = spin(e, 14);
          expect(positions(state).contains('dozen-2nd'), hit < threshold);
          if (hit < threshold) spin(e, 2);
        }
        expect(positions(spin(e, 2)).contains('dozen-2nd'), false);
      },
    );
  }
  test('STW removes one split then whole dozen, persistent after a loss', () {
    final e = engine(fixture('spin_2_win', reset: false));
    expect(spin(e, 1).currentActiveBets.length, 12);
    spin(e, 3);
    final state = spin(e, 4);
    expect(state.currentStageIndex, 1);
    expect(state.currentActiveBets.length, 9);
    expect(
      state.currentActiveBets.any((b) => getBetDozen(b.position) == 1),
      false,
    );
    expect(spin(e, 3).currentActiveBets.length, 9);
  });
  test('STW uncovered result does not increment dozen hit count', () {
    final e = engine(fixture('spin_2_win', reset: false));
    spin(e, 3);
    expect(spin(e, 1).currentActiveBets.length, 12);
    expect(spin(e, 1).currentActiveBets.length, 12); // Retired split is a miss.
    expect(spin(e, 4).currentActiveBets.length, 9);
  });
  test('STW double zero retirement does not count as a dozen hit', () {
    final e = engine(fixture('spin_2_win', reset: false));
    expect(spin(e, 37).currentActiveBets.length, 12);
    expect(spin(e, 1).currentActiveBets.length, 11);
  });
  test(
    'Moneyball net-negative anchor hit repeats stage without raising bets',
    () {
      final e = engine(fixture('moneyball', reset: false));
      spin(e, 2);
      final state = spin(e, 14);
      expect(e.lastPayoutResult!.netResult, -12);
      expect(state.currentStageIndex, 1);
      expect(e.lastBaselineAction, 'repeat');
    },
  );
  test(
    'deduplicated normalized group hits; rule order cannot hide a winner',
    () {
      final s = fixture('spin_2_win', reset: false);
      for (final stage in s.stages) {
        stage.bets = [
          StageBet(position: 'straight-1', amount: 1, groupId: 'Group A'),
          StageBet(position: 'split-1-2', amount: 1, groupId: 'A'),
          StageBet(position: 'straight-3', amount: 1, groupId: 'A'),
          StageBet(position: 'straight-4', amount: 1, groupId: 'B'),
        ];
        stage.dynamicRules = [
          DynamicRule(
            id: 'one',
            condition: 'win',
            target: 'winning_bets',
            action: 'remove',
          ),
          DynamicRule(
            id: 'two',
            condition: 'group_win_threshold',
            target: 'specific_group',
            targetGroup: 'Group A',
            winCountThreshold: 2,
            action: 'remove',
          ),
        ];
      }
      final e = engine(s);
      expect(positions(spin(e, 1)), {'straight-3', 'straight-4'});
      expect(positions(spin(e, 3)), {'straight-4'});
    },
  );
  test('individual removal does not retire other bets sharing a tag', () {
    final s = fixture('spin_2_win', reset: false);
    for (final stage in s.stages) {
      for (final bet in stage.bets) {
        bet.groupId = 'A';
      }
      stage.dynamicRules!.removeLast();
    }
    final e = engine(s);
    spin(e, 1);
    final state = spin(e, 3);
    expect(state.currentActiveBets.length, 12);
    expect(positions(state).contains('split-1-2'), false);
  });
  test(
    'empty board resets immediately and counters clear for next session',
    () {
      final e = engine(fixture('moneyball', reset: false));
      for (final n in [1, 3, 27, 25, 14, 14, 14]) {
        spin(e, n);
      }
      expect(e.lastBaselineAction, 'reset');
      expect(e.getInternalState().totalCompletedSessions, 1);
      final next = spin(e, 14);
      expect(next.currentActiveBets.length, 17);
      expect(next.isSessionActive, true);
      expect(positions(next).contains('dozen-2nd'), true);
    },
  );
  test('dozen counters are independent across all three dozens', () {
    final e = engine(fixture('spin_2_win', reset: false));
    for (final n in [1, 13, 25]) {
      spin(e, n);
    }
    expect(e.getInternalState().currentActiveBets.length, 10);
    for (final n in [4, 16, 28]) {
      spin(e, n);
    }
    expect(positions(e.getInternalState()), {'split-0-00'});
    expect(spin(e, 0).isSessionActive, false);
  });
  test('new high requires exceeding the previous peak', () {
    final strategy = fixture('moneyball', reset: false);
    for (final stage in strategy.stages) {
      stage.dynamicRules = [];
      stage.optionalRules!.resetOnNewSessionHigh = true;
      stage.bets = [StageBet(position: 'straight-1', amount: 1)];
    }
    strategy.stages.first.bets = [StageBet(position: 'straight-2', amount: 35)];
    final e = engine(strategy);
    spin(e, 3);
    final recovered = spin(e, 1);
    expect(recovered.sessionProfit, 0);
    expect(recovered.isSessionActive, true);
    expect(spin(e, 1).isSessionActive, false);
  });
  test('winning-group threshold survives stage transitions and removes whole tag', () {
    final strategy = fixture('moneyball', reset: false);
    for (final stage in strategy.stages) {
      stage.dynamicRules = [DynamicRule(id: 'group', condition: 'win',
        target: 'winning_group', winCountThreshold: 2, action: 'remove')];
      for (final b in stage.bets) {
        if (b.groupId == 'A') b.groupId = 'Group A';
      }
    }
    final e = engine(strategy);
    expect(spin(e,1).currentActiveBets.length,17);
    spin(e,2);
    expect(spin(e,4).currentActiveBets.length,13);
    expect(spin(e,2).currentActiveBets.length,13);
  });

}
