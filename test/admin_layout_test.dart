import 'package:cpsumotorpooladmin/widgets/admin_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 600.0, 1280.0]) {
    testWidgets('Toolbar remains usable at width $width', (tester) async {
      tester.view.reset();
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: AdminToolbar(
                title: const Text('Manage vehicles and driver assignments'),
                actions: FilledButton(
                  onPressed: () => pressed = true,
                  child: const Text('Add Assignment'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Add Assignment'));
      expect(pressed, isTrue);
      final title = tester.getRect(
        find.text('Manage vehicles and driver assignments'),
      );
      final button = tester.getRect(find.byType(FilledButton));
      if (width < 624) {
        expect(button.top, greaterThan(title.bottom));
      } else {
        expect(button.left, greaterThan(title.right));
      }
    });
  }

  testWidgets('Toolbar supports large accessibility text on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: AdminToolbar(
              title: const Text('Device Registry'),
              actions: FilledButton(
                onPressed: () {},
                child: const Text('Register Device'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(FilledButton)).right,
      lessThanOrEqualTo(348),
    );
  });

  testWidgets('Wide tables scroll independently inside a vertical page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 0; i < 2; i++)
                  AdminTableScroll(
                    child: SizedBox(
                      width: 1400,
                      height: 100,
                      child: Row(
                        children: [
                          Text('Start $i'),
                          const Spacer(),
                          Text('End $i'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final first = find.byType(AdminTableScroll).first;
    final second = find.byType(AdminTableScroll).last;
    final secondBefore = tester.getTopLeft(find.text('Start 1'));
    await tester.drag(first, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Start 0')).dx, lessThan(0));
    expect(tester.getTopLeft(find.text('Start 1')), secondBefore);
    expect(
      find.descendant(of: second, matching: find.byType(Scrollbar)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
