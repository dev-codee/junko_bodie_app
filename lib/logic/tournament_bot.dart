import 'dart:math';
import '../models/tournament.dart';
import 'bets.dart';

class TournamentBot {
  static const List<String> _botNames = [
    'AceHigh', 'RoyalFlush', 'NeonRider', 'ShadowBet', 'CrimsonKing',
    'DiamondDiva', 'GoldDigger', 'MidnightWolf', 'SilverBullet', 'PhantomPro',
    'ViperVegas', 'JackpotJoy', 'RogueSpinner', 'TitanTricks', 'ZenithPlayer',
    'MysticLuck', 'IronGamble', 'ChaosCroupier', 'SolarSpin', 'LunarLuna',
    'BlazeBet', 'FrostyFold', 'OmegaWager', 'AlphaAce', 'SigmaStakes',
    'GigaGamble', 'UltraUser', 'MegaMaster', 'ProPunter', 'EliteEdge',
    'ZenMaster', 'SilentWinner', 'LuckyStriker', 'CasinoQueen', 'RouletteRebel',
    'BettingBeast', 'ProfitPirate', 'WagerWizard', 'SpinSurfer', 'GlitchGambler',
    'RandoRich', 'HighRoller', 'BrokeToRich', 'VegasVulture', 'DesertDealer',
    'NeonGlow', 'CyberSpinner', 'MatrixMistress', 'VectorVegas', 'PixelPunter'
  ];

  static const List<int> _chipValues = [1, 2, 5, 10, 25, 100, 500, 1000];

  static String getRandomBotName({List<String> exclude = const []}) {
    final available = _botNames.where((name) => !exclude.contains(name)).toList();
    final list = available.isNotEmpty ? available : _botNames;
    final random = Random();
    return list[random.nextInt(list.length)];
  }

  static int _pickRandomChip(double budget) {
    final possible = _chipValues.where((v) => v <= budget).toList();
    if (possible.isEmpty) return 0;
    final random = Random();
    return possible[random.nextInt(possible.length)];
  }

  static List<PlacedBet> generateBotBets(TournamentPlayer bot) {
    final bets = <PlacedBet>[];
    final currentChips = bot.currentChips;

    if (currentChips <= 0) return [];

    final maxWager = currentChips < 100 ? 1.0 : (currentChips * 0.1).floorToDouble();
    if (maxWager < 1) return [];

    final random = Random();
    final numZones = random.nextInt(3) + 1; // 1 to 3
    double totalWagered = 0;

    for (int i = 0; i < numZones; i++) {
      final remainingAllowed = maxWager - totalWagered;
      if (remainingAllowed < 1) break;

      final isOutside = random.nextDouble() < 0.6;
      List<BetDefinition> pool;

      if (isOutside) {
        pool = Bets.allOutsideBets;
      } else {
        final subType = random.nextDouble();
        if (subType < 0.4) {
          pool = Bets.allStraightBets;
        } else if (subType < 0.8) {
          pool = Bets.allSplitBets;
        } else {
          pool = Bets.allCornerBets;
        }
      }

      final randomDef = pool[random.nextInt(pool.length)];
      final betAmount = currentChips < 100 ? 1.0 : _pickRandomChip(remainingAllowed).toDouble();

      if (betAmount > 0) {
        if (!bets.any((b) => b.betId == randomDef.id)) {
          bets.add(PlacedBet(
            betId: randomDef.id,
            amount: betAmount,
            chips: [betAmount],
          ));
          totalWagered += betAmount;
        }
      }
    }

    return bets;
  }
}
