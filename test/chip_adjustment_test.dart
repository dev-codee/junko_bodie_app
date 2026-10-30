import 'package:flutter_test/flutter_test.dart';
import 'package:junko_bodie/logic/bets.dart';

void main() {
  Map<String, PlacedBet> sample() => {
    'red': PlacedBet(
      betId: 'red',
      amount: 6,
      chips: [1, 5],
      customColor: '#fff',
      playerInitial: 'A',
    ),
    'black': PlacedBet(betId: 'black', amount: 1, chips: [1]),
  };

  test('increments each chip, including multiple chips on the same zone', () {
    final original = sample();
    final result = adjustBetChips(original, 1);
    expect(result['red']!.chips, [2, 6]);
    expect(result['red']!.amount, 8);
    expect(result['black']!.amount, 2);
    expect(result['red']!.customColor, '#fff');
    expect(result['red']!.playerInitial, 'A');
    expect(original['red']!.chips, [1, 5]);
    expect(original['red']!.amount, 6);
  });

  test('decrements chips and removes zero chips and empty zones', () {
    final result = adjustBetChips(sample(), -1);
    expect(result['red']!.chips, [4]);
    expect(result['red']!.amount, 4);
    expect(result.containsKey('black'), isFalse);
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
    expect(result['red']!.chips, [1, 5]);
    expect(result['black']!.chips, [1]);
    expect(result['red']!.amount, 6);
  });

  test('empty boards stay empty and invalid adjustments are rejected', () {
    expect(adjustBetChips({}, 1), isEmpty);
    expect(adjustBetChips({}, -1), isEmpty);
    expect(() => adjustBetChips(sample(), 2), throwsArgumentError);
  });
}
