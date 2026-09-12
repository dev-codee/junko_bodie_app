import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:junko_bodie/tour/tour_highlight_ring.dart';
import 'package:junko_bodie/tour/tour_models.dart';

void main() {
  group('Tour Screen 7 & Highlight Tests', () {
    test('Step 7 (builder_place_bet) targets funnel-table-area', () {
      final step7 = kFunnelSteps.firstWhere((s) => s.id == 'builder_place_bet');
      expect(step7.targetId, equals('funnel-table-area'));
    });

    testWidgets('TourHighlightRing renders correctly with negative top offset (scrolled)',
        (WidgetTester tester) async {
      // Simulate target rect scrolled so its top is negative (-100)
      const scrolledRect = Rect.fromLTWH(100, -100, 500, 300);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: const [
                TourHighlightRing(
                  targetRect: scrolledRect,
                ),
              ],
            ),
          ),
        ),
      );

      // Verify TourHighlightRing renders without error
      expect(find.byType(TourHighlightRing), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
