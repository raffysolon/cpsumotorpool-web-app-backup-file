import 'package:cpsumotorpooladmin/widgets/trips_shell.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Unread trip badges move with status and disappear when read', (tester) async {
    final inbox = AdminNotificationsController.instance.notifications;
    addTearDown(() => inbox.value = const []);
    inbox.value = [{'id': 1, 'is_read': false, 'trip': {'status': 'pending'}}];
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TripsTabs(currentRoute: '/trip-request'))));
    expect(find.descendant(of: find.widgetWithText(ChoiceChip, 'Trip Requests'), matching: find.byType(Badge)), findsOneWidget);
    inbox.value = [{'id': 1, 'is_read': false, 'trip': {'status': 'active'}}];
    await tester.pump();
    expect(find.descendant(of: find.widgetWithText(ChoiceChip, 'Scheduled & Active'), matching: find.byType(Badge)), findsOneWidget);
    inbox.value = [{'id': 1, 'is_read': true, 'trip': {'status': 'active'}}];
    await tester.pump();
    expect(find.byType(Badge), findsNothing);
  });
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
