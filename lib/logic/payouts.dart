import 'rng.dart';
import 'bets.dart';

class BetOutcome {
  final String betId;
  final double wagered;
  final double won;
  final bool isWin;

  BetOutcome({
    required this.betId,
    required this.wagered,
    required this.won,
    required this.isWin,
  });
}

class PayoutResult {
  final List<BetOutcome> outcomes;
  final double totalWagered;
  final double totalWon;
  final double netResult;
  final double totalReturned;

  PayoutResult({
    required this.outcomes,
    required this.totalWagered,
    required this.totalWon,
    required this.netResult,
    required this.totalReturned,
  });
}

class Payouts {
  static bool doesBetWin(String betId, SpinResult spinResult) {
    final definition = Bets.betMap[betId];
    if (definition == null) return false;

    return definition.numbers.contains(spinResult.number);
  }

  static PayoutResult calculatePayouts(List<PlacedBet> bets, SpinResult spinResult) {
    final outcomes = <BetOutcome>[];
    double totalWagered = 0;
    double totalWon = 0;
    double totalReturned = 0;

    for (final bet in bets) {
      final definition = Bets.betMap[bet.betId];
      if (definition == null) continue;

      final isWin = doesBetWin(bet.betId, spinResult);
      final won = isWin ? bet.amount * definition.payout : 0.0;
      final returned = isWin ? bet.amount + won : 0.0;

      outcomes.add(BetOutcome(
        betId: bet.betId,
        wagered: bet.amount,
        won: won,
        isWin: isWin,
      ));

      totalWagered += bet.amount;
      totalWon += won;
      totalReturned += returned;
    }

    return PayoutResult(
      outcomes: outcomes,
      totalWagered: totalWagered,
      totalWon: totalWon,
      netResult: totalReturned - totalWagered,
      totalReturned: totalReturned,
    );
  }
}
