import 'dart:math';

enum WheelType { american, european }

class SpinResult {
  final String id;
  final int number;
  final String displayNumber; // e.g., "00" or "17"
  final String color; // 'red', 'black', or 'green'
  final String parity; // 'odd', 'even', or 'none'
  final String dozen; // '1st', '2nd', '3rd', or 'none'
  final String column; // '1st', '2nd', '3rd', or 'none'
  final String half; // '1-18', '19-36', or 'none'

  SpinResult({
    required this.id,
    required this.number,
    required this.displayNumber,
    required this.color,
    required this.parity,
    required this.dozen,
    required this.column,
    required this.half,
  });
}

class RNG {
  static final Set<int> redNumbers = {
    1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36
  };

  static const List<int> americanWheelOrder = [
    0, 28, 9, 26, 30, 11, 7, 20, 32, 17, 5, 22, 34, 15, 3, 24, 36,
    13, 1, 37, 27, 10, 25, 29, 12, 8, 19, 31, 18, 6, 21, 33, 16,
    4, 23, 35, 14, 2,
  ];

  static const List<int> europeanWheelOrder = [
    0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36,
    11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9,
    22, 18, 29, 7, 28, 12, 35, 3, 26,
  ];

  static String getNumberColor(int num) {
    if (num == 0 || num == 37) return 'green';
    return redNumbers.contains(num) ? 'red' : 'black';
  }

  static String getDisplayNumber(int num) {
    if (num == 37) return '00';
    return num.toString();
  }

  static String getDozen(int num) {
    if (num == 0 || num == 37) return 'none';
    if (num <= 12) return '1st';
    if (num <= 24) return '2nd';
    return '3rd';
  }

  static String getColumn(int num) {
    if (num == 0 || num == 37) return 'none';
    final mod = num % 3;
    if (mod == 1) return '1st';
    if (mod == 2) return '2nd';
    return '3rd'; // mod == 0
  }

  static String getHalf(int num) {
    if (num == 0 || num == 37) return 'none';
    return num <= 18 ? '1-18' : '19-36';
  }

  static String getParity(int num) {
    if (num == 0 || num == 37) return 'none';
    return num % 2 == 0 ? 'even' : 'odd';
  }

  static SpinResult spinWheel({WheelType wheelType = WheelType.american}) {
    final pockets = wheelType == WheelType.american
        ? americanWheelOrder
        : europeanWheelOrder;
    final totalPockets = pockets.length;

    final random = Random.secure();
    final index = random.nextInt(totalPockets);
    final number = pockets[index];

    // Generate a simple 9-char random ID for the spin
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final id = String.fromCharCodes(Iterable.generate(
      9, (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ));

    return SpinResult(
      id: id,
      number: number,
      displayNumber: getDisplayNumber(number),
      color: getNumberColor(number),
      parity: getParity(number),
      dozen: getDozen(number),
      column: getColumn(number),
      half: getHalf(number),
    );
  }

  static int getWheelIndex(int number, {WheelType wheelType = WheelType.american}) {
    final order = wheelType == WheelType.american
        ? americanWheelOrder
        : europeanWheelOrder;
    return order.indexOf(number);
  }
}
