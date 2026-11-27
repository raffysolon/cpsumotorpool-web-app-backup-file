import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cpsumotorpooladmin/widgets/notification_dialog.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    required Future<void> Function(int) read,
    required Future<void> Function(int) delete,
    bool isRead = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationDialog(
            notifications: [
              {'id': 7, 'message': 'Trip approved', 'is_read': isRead},
            ],
            onAcknowledge: read,
            onDelete: delete,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('unread indicator clears only after successful mark as read', (
    tester,
  ) async {
    final done = Completer<void>();
    var calls = 0;
    await open(
      tester,
      read: (_) {
        calls++;
        return done.future;
      },
      delete: (_) async {},
    );
    expect(find.text('NEW'), findsOneWidget);
    await tester.tap(find.byTooltip('Notification actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as read'));
    await tester.pump();
    expect(find.text('NEW'), findsOneWidget);
    expect(calls, 1);
    done.complete();
    await tester.pumpAndSettle();
    expect(find.text('NEW'), findsNothing);
    expect(find.text('Trip approved'), findsOneWidget);
  });

  testWidgets(
    'delete requires confirmation and removes the item after success',
    (tester) async {
      var calls = 0;
      await open(
        tester,
        read: (_) async {},
        delete: (_) async {
          calls++;
        },
      );
      Future<void> chooseDelete() async {
        await tester.tap(find.byTooltip('Notification actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
      }

      await chooseDelete();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Trip approved'), findsOneWidget);
      await chooseDelete();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Trip approved'), findsNothing);
      expect(find.text('No notifications yet'), findsOneWidget);
    },
  );

  testWidgets(
    'failed actions retain unread notification and show a retry message',
    (tester) async {
      await open(
        tester,
        read: (_) async => throw Exception('offline'),
        delete: (_) async => throw Exception('offline'),
      );
      await tester.tap(find.text('Trip approved'));
      await tester.pumpAndSettle();
      expect(find.text('NEW'), findsOneWidget);
      expect(
        find.text('Unable to mark as read. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Notification actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Trip approved'), findsOneWidget);
      expect(
        find.text('Unable to delete notification. Please try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('read notifications do not show NEW or mark-as-read action', (
    tester,
  ) async {
    await open(tester, read: (_) async {}, delete: (_) async {}, isRead: true);
    expect(find.text('NEW'), findsNothing);
    await tester.tap(find.byTooltip('Notification actions'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as read'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
  });
}
