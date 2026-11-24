import 'package:cpsumotorpooladmin/widgets/notification_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _longMessage =
    'LOCAL-SCENARIO-NEAR-DEPARTURE Local Test Vehicle 9 tracker has no recent '
    'heartbeat before the approved trip scheduled for 9:33 PM Philippine time. '
    'Please check connectivity and confirm the assigned vehicle before departure.';

void main() {
  testWidgets('notification dialog fits desktop, tablet, and mobile layouts', (
    tester,
  ) async {
    final notifications = List.generate(
      18,
      (index) => {
        'id': index + 1,
        'message': index == 0 ? _longMessage : 'Notification update $index',
        'created_at': '2026-11-24T13:33:41Z',
        'priority': index == 0 ? 'high' : 'normal',
      },
    );

    for (final size in [
      const Size(1440, 900),
      const Size(900, 1024),
      const Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_notificationLauncher(notifications));
      await tester.tap(find.text('Open notifications'));
      await tester.pumpAndSettle();

      final dialogRect = tester.getRect(
        find.byKey(const Key('notification-dialog-surface')),
      );
      if (size.width > 1024) {
        expect(dialogRect.width, 920);
      } else {
        expect(dialogRect.width / size.width, inInclusiveRange(0.90, 0.95));
      }
      expect(dialogRect.height / size.height, lessThanOrEqualTo(0.85));
      expect(find.text(_longMessage), findsOneWidget);
      expect(find.text('HIGH PRIORITY'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byTooltip('2026-11-24T13:33:41Z'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byKey(const Key('notification-list')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      tester.view.reset();
    }
  });

  testWidgets('empty notifications show a clear empty state', (tester) async {
    await tester.pumpWidget(_notificationLauncher(const []));
    await tester.tap(find.text('Open notifications'));
    await tester.pumpAndSettle();

    expect(find.text('No notifications yet'), findsOneWidget);
    expect(find.text('New updates will appear here.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('acknowledging a notification calls the existing callback', (
    tester,
  ) async {
    int? acknowledgedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => NotificationDialog(
                    notifications: const [
                      {
                        'id': 42,
                        'message': 'Acknowledgment test notification',
                        'created_at': '',
                        'priority': 'normal',
                      },
                    ],
                    onAcknowledge: (id) async => acknowledgedId = id,
                  ),
                );
              },
              child: const Text('Open notifications'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acknowledgment test notification'));
    await tester.pumpAndSettle();

    expect(acknowledgedId, 42);
    expect(find.byType(Dialog), findsNothing);
  });
}

Widget _notificationLauncher(List<Map<String, dynamic>> notifications) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (_) => NotificationDialog(
                notifications: notifications,
                onAcknowledge: (_) async {},
              ),
            );
          },
          child: const Text('Open notifications'),
        ),
      ),
    ),
  );
}
