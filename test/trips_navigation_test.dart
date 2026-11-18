import 'package:cpsumotorpooladmin/widgets/trips_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('Trip tabs navigate without overflow at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: TripsTabs(currentRoute: '/active-trips')),
          routes: {
            '/trip-request': (_) =>
                const Scaffold(body: Text('Requests destination')),
            '/approval-letter': (_) =>
                const Scaffold(body: Text('Tickets destination')),
          },
        ),
      );
      expect(tester.takeException(), isNull);
      final active = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Scheduled & Active'),
      );
      expect(active.selected, isTrue);
      await tester.tap(find.text('Scheduled & Active'));
      await tester.pumpAndSettle();
      expect(find.byType(TripsTabs), findsOneWidget);
      await tester.tap(find.text('Trip Requests'));
      await tester.pumpAndSettle();
      expect(find.text('Requests destination'), findsOneWidget);
    });
  }
  testWidgets('Tickets tab opens the ticket route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: TripsTabs(currentRoute: '/trip-request')),
        routes: {
          '/approval-letter': (_) =>
              const Scaffold(body: Text('Tickets destination')),
        },
      ),
    );
    await tester.tap(find.text('Trip Tickets'));
    await tester.pumpAndSettle();
    expect(find.text('Tickets destination'), findsOneWidget);
  });
}
