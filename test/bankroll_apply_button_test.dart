import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junko_bodie/widgets/bankroll_apply_button.dart';

void main() {
  testWidgets('Apply accepts edits, updates callback and shows success', (tester) async {
    final controller = TextEditingController(text: '1000');
    double balance = 1000;
    double starting = 1000;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) => BankrollApplyButton(
        controller: controller, startingBalance: starting, balance: balance,
        enabled: true, onApply: (amount) => setState(() {
          balance = amount;
          starting = amount;
        }),
      ),
    ))));
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    controller.text = '10000';
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(balance, 10000);
    expect(starting, 10000);
    expect(find.text('APPLIED!'), findsOneWidget);
    controller.text = '500';
    await tester.pumpAndSettle();
    expect(find.text('APPLY'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('Allows restoring saved bankroll and rejects invalid or locked edits', (tester) async {
    final controller = TextEditingController(text: '10000');
    double? applied;
    Future<void> render(bool enabled) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: BankrollApplyButton(
        controller: controller, startingBalance: 10000, balance: 750,
        enabled: enabled, onApply: (amount) => applied = amount,
      ))));
    }
    await render(true);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(applied, 10000);
    for (final value in ['', '0', '-1', '1.5', '9007199254740992']) {
      controller.text = value;
      await tester.pump();
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    }
    controller.text = '20000';
    await render(false);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
