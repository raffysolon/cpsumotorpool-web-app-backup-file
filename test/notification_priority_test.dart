import 'package:cpsumotorpooladmin/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('high-priority notifications are visibly labeled', (
    tester,
  ) async {
    final controller = AdminNotificationsController.instance;
    controller.notifications.value = [
      {
        'id': 1,
        'message': 'Unassigned vehicle movement detected.',
        'created_at': '',
        'priority': 'high',
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => controller.showNotificationsDialog(context),
              child: const Text('Open notifications'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open notifications'));
    await tester.pumpAndSettle();

    expect(find.text('HIGH PRIORITY'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    controller.notifications.value = const [];
  });
}
