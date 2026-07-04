import 'package:flutter_test/flutter_test.dart';
import 'package:junko_bodie/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JunkoBodieApp());
    // Basic smoke test — app renders without crashing
    expect(find.byType(JunkoBodieApp), findsOneWidget);
  });
}
