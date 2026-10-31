import 'package:flutter_test/flutter_test.dart';
import 'package:junko_bodie/logic/bets.dart';

void main() {
  Map<String, PlacedBet> sample() => {
    'straight-1': PlacedBet(
      betId: 'straight-1',
      amount: 6,
      chips: [1, 5],
      customColor: '#fff',
      playerInitial: 'A',
    ),
    'split-1-2': PlacedBet(betId: 'split-1-2', amount: 1, chips: [1]),
  };

  test('increments each chip, including multiple chips on the same zone', () {
    final original = sample();
    final result = adjustBetChips(original, 1);
    expect(result['straight-1']!.chips, [2, 6]);
    expect(result['straight-1']!.amount, 8);
    expect(result['split-1-2']!.amount, 2);
    expect(result['straight-1']!.customColor, '#fff');
    expect(result['straight-1']!.playerInitial, 'A');
    expect(original['straight-1']!.chips, [1, 5]);
    expect(original['straight-1']!.amount, 6);
  });

  test('decrements chips and removes zero chips and empty zones', () {
    final result = adjustBetChips(sample(), -1);
    expect(result['straight-1']!.chips, [4]);
    expect(result['straight-1']!.amount, 4);
    expect(result.containsKey('split-1-2'), isFalse);
    for (var i = 0; i < 4; i++) {
      final next = adjustBetChips(result, -1);
      result
        ..clear()
        ..addAll(next);
    }
    expect(result, isEmpty);
  });

  test('increment then decrement restores each chip', () {
    final result = adjustBetChips(adjustBetChips(sample(), 1), -1);
    expect(result['straight-1']!.chips, [1, 5]);
    expect(result['split-1-2']!.chips, [1]);
    expect(result['straight-1']!.amount, 6);
  });

  test('empty boards stay empty and invalid adjustments are rejected', () {
    expect(adjustBetChips({}, 1), isEmpty);
    expect(adjustBetChips({}, -1), isEmpty);
    expect(() => adjustBetChips(sample(), 2), throwsArgumentError);
  });
  test('outside bets retain their chips and amounts in mixed boards', () {
    final outside = PlacedBet(betId: 'dozen-1st', amount: 15, chips: [5, 10]);
    final board = sample()..['dozen-1st'] = outside;
    for (final delta in [1, -1]) {
      final result = adjustBetChips(board, delta);
      expect(identical(result['dozen-1st'], outside), isTrue);
      expect(result['straight-1']!.amount, delta == 1 ? 8 : 4);
    }
    for (final bet in Bets.allOutsideBets) {
      expect(isInsideBet(bet.id), isFalse);
    }
    for (final bet in Bets.betMap.values.where((bet) => isInsideBet(bet.id))) {
      final placed = PlacedBet(betId: bet.id, amount: 5, chips: [5]);
      expect(adjustBetChips({bet.id: placed}, 1)[bet.id]!.amount, 6);
    }
  });

}
