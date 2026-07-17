enum BetType {
  straight,
  split,
  street,
  corner,
  sixline,
  dozen,
  column,
  red,
  black,
  odd,
  even,
  low,
  high,
  trio,
  basket,
}

class BetDefinition {
  final String id;
  final BetType type;
  final String label;
  final List<int> numbers;
  final int payout;

  const BetDefinition({
    required this.id,
    required this.type,
    required this.label,
    required this.numbers,
    required this.payout,
  });
}

class PlacedBet {
  final String betId;
  final double amount;
  final List<double> chips;
  final String? customColor;
  final String? playerInitial;

  PlacedBet({
    required this.betId,
    required this.amount,
    required this.chips,
    this.customColor,
    this.playerInitial,
  });
}

class Bets {
  static const Map<BetType, int> payoutMultipliers = {
    BetType.straight: 35,
    BetType.split: 17,
    BetType.street: 11,
    BetType.corner: 8,
    BetType.sixline: 5,
    BetType.dozen: 2,
    BetType.column: 2,
    BetType.red: 1,
    BetType.black: 1,
    BetType.odd: 1,
    BetType.even: 1,
    BetType.low: 1,
    BetType.high: 1,
    BetType.trio: 11,
    BetType.basket: 6,
  };

  static List<BetDefinition> _buildStraightBets() {
    final bets = [
      const BetDefinition(id: 'straight-0', type: BetType.straight, label: '0', numbers: [0], payout: 35),
      const BetDefinition(id: 'straight-00', type: BetType.straight, label: '00', numbers: [37], payout: 35),
    ];
    for (int i = 1; i <= 36; i++) {
      bets.add(BetDefinition(
        id: 'straight-$i',
        type: BetType.straight,
        label: i.toString(),
        numbers: [i],
        payout: 35,
      ));
    }
    return bets;
  }

  static List<BetDefinition> _buildSplitBets() {
    final bets = <BetDefinition>[];

    // Horizontal splits
    for (int i = 1; i <= 33; i++) {
      bets.add(BetDefinition(
        id: 'split-$i-${i + 3}',
        type: BetType.split,
        label: '$i|${i + 3}',
        numbers: [i, i + 3],
        payout: 17,
      ));
    }

    // Vertical splits
    for (int row = 0; row < 12; row++) {
      final base = row * 3 + 1;
      bets.add(BetDefinition(
        id: 'split-$base-${base + 1}',
        type: BetType.split,
        label: '$base|${base + 1}',
        numbers: [base, base + 1],
        payout: 17,
      ));
      bets.add(BetDefinition(
        id: 'split-${base + 1}-${base + 2}',
        type: BetType.split,
        label: '${base + 1}|${base + 2}',
        numbers: [base + 1, base + 2],
        payout: 17,
      ));
    }

    // Zero splits
    bets.add(const BetDefinition(id: 'split-0-00', type: BetType.split, label: '0|00', numbers: [0, 37], payout: 17));
    bets.add(const BetDefinition(id: 'split-0-1', type: BetType.split, label: '0|1', numbers: [0, 1], payout: 17));
    bets.add(const BetDefinition(id: 'split-0-2', type: BetType.split, label: '0|2', numbers: [0, 2], payout: 17));
    bets.add(const BetDefinition(id: 'split-0-3', type: BetType.split, label: '0|3', numbers: [0, 3], payout: 17));
    bets.add(const BetDefinition(id: 'split-00-2', type: BetType.split, label: '00|2', numbers: [37, 2], payout: 17));
    bets.add(const BetDefinition(id: 'split-00-3', type: BetType.split, label: '00|3', numbers: [37, 3], payout: 17));

    return bets;
  }

  static List<BetDefinition> _buildStreetBets() {
    final bets = <BetDefinition>[];
    for (int row = 0; row < 12; row++) {
      final base = row * 3 + 1;
      bets.add(BetDefinition(
        id: 'street-$base-${base + 1}-${base + 2}',
        type: BetType.street,
        label: '$base-${base + 2}',
        numbers: [base, base + 1, base + 2],
        payout: 11,
      ));
    }
    return bets;
  }

  static List<BetDefinition> _buildCornerBets() {
    final bets = <BetDefinition>[];
    for (int row = 0; row < 11; row++) {
      final base = row * 3 + 1;
      bets.add(BetDefinition(
        id: 'corner-$base-${base + 1}-${base + 3}-${base + 4}',
        type: BetType.corner,
        label: '$base,${base + 1},${base + 3},${base + 4}',
        numbers: [base, base + 1, base + 3, base + 4],
        payout: 8,
      ));
      bets.add(BetDefinition(
        id: 'corner-${base + 1}-${base + 2}-${base + 4}-${base + 5}',
        type: BetType.corner,
        label: '${base + 1},${base + 2},${base + 4},${base + 5}',
        numbers: [base + 1, base + 2, base + 4, base + 5],
        payout: 8,
      ));
    }
    return bets;
  }

  static List<BetDefinition> _buildSixLineBets() {
    final bets = <BetDefinition>[];
    for (int row = 0; row < 11; row++) {
      final base = row * 3 + 1;
      bets.add(BetDefinition(
        id: 'sixline-$base-${base + 5}',
        type: BetType.sixline,
        label: '$base-${base + 5}',
        numbers: [base, base + 1, base + 2, base + 3, base + 4, base + 5],
        payout: 5,
      ));
    }
    return bets;
  }

  static List<BetDefinition> _buildTrioBets() {
    return [
      const BetDefinition(id: 'trio-0-1-2', type: BetType.trio, label: '0,1,2', numbers: [0, 1, 2], payout: 11),
      const BetDefinition(id: 'trio-0-2-3', type: BetType.trio, label: '0,2,3', numbers: [0, 2, 3], payout: 11),
      const BetDefinition(id: 'trio-00-2-3', type: BetType.trio, label: '00,2,3', numbers: [37, 2, 3], payout: 11),
      const BetDefinition(id: 'trio-0-00-2', type: BetType.trio, label: '0,00,2', numbers: [0, 37, 2], payout: 11),
    ];
  }

  static List<BetDefinition> _buildBasketBets() {
    return [
      const BetDefinition(id: 'basket-0-1-2-3', type: BetType.basket, label: '0-3', numbers: [0, 1, 2, 3], payout: 8),
      const BetDefinition(id: 'basket-0-00-1-2-3', type: BetType.basket, label: 'Top Line', numbers: [0, 37, 1, 2, 3], payout: 5),
    ];
  }

  static List<BetDefinition> _buildOutsideBets() {
    final col1 = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34];
    final col2 = [2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35];
    final col3 = [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36];
    final redNums = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36];
    final blackNums = [2, 4, 6, 8, 10, 11, 13, 15, 17, 20, 22, 24, 26, 28, 29, 31, 33, 35];

    return [
      BetDefinition(id: 'dozen-1st', type: BetType.dozen, label: '1st 12', numbers: List.generate(12, (i) => i + 1), payout: 2),
      BetDefinition(id: 'dozen-2nd', type: BetType.dozen, label: '2nd 12', numbers: List.generate(12, (i) => i + 13), payout: 2),
      BetDefinition(id: 'dozen-3rd', type: BetType.dozen, label: '3rd 12', numbers: List.generate(12, (i) => i + 25), payout: 2),

      BetDefinition(id: 'column-1st', type: BetType.column, label: '2 to 1', numbers: col1, payout: 2),
      BetDefinition(id: 'column-2nd', type: BetType.column, label: '2 to 1', numbers: col2, payout: 2),
      BetDefinition(id: 'column-3rd', type: BetType.column, label: '2 to 1', numbers: col3, payout: 2),

      BetDefinition(id: 'red', type: BetType.red, label: 'RED', numbers: redNums, payout: 1),
      BetDefinition(id: 'black', type: BetType.black, label: 'BLACK', numbers: blackNums, payout: 1),
      BetDefinition(id: 'odd', type: BetType.odd, label: 'ODD', numbers: List.generate(18, (i) => i * 2 + 1), payout: 1),
      BetDefinition(id: 'even', type: BetType.even, label: 'EVEN', numbers: List.generate(18, (i) => (i + 1) * 2), payout: 1),
      BetDefinition(id: 'low', type: BetType.low, label: '1-18', numbers: List.generate(18, (i) => i + 1), payout: 1),
      BetDefinition(id: 'high', type: BetType.high, label: '19-36', numbers: List.generate(18, (i) => i + 19), payout: 1),
    ];
  }

  static final List<BetDefinition> allStraightBets = _buildStraightBets();
  static final List<BetDefinition> allSplitBets = _buildSplitBets();
  static final List<BetDefinition> allStreetBets = _buildStreetBets();
  static final List<BetDefinition> allCornerBets = _buildCornerBets();
  static final List<BetDefinition> allSixLineBets = _buildSixLineBets();
  static final List<BetDefinition> allTrioBets = _buildTrioBets();
  static final List<BetDefinition> allBasketBets = _buildBasketBets();
  static final List<BetDefinition> allOutsideBets = _buildOutsideBets();

  static final Map<String, BetDefinition> betMap = {
    for (var b in [
      ...allStraightBets,
      ...allSplitBets,
      ...allStreetBets,
      ...allCornerBets,
      ...allSixLineBets,
      ...allTrioBets,
      ...allBasketBets,
      ...allOutsideBets,
    ])
      b.id: b
  };

  static List<BetDefinition> getBetsForNumber(int num) {
    return betMap.values.where((bet) => bet.numbers.contains(num)).toList();
  }
}
