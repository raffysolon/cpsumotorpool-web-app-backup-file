import 'package:cpsumotorpooladmin/models/tracker_availability.dart';
import 'package:cpsumotorpooladmin/widgets/heartbeat_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('connectivity indicator is a static, accessible dot', (
    tester,
  ) async {
    await tester.pumpWidget(_host(TrackerAvailability.unreachable));

    expect(find.byKey(const Key('heartbeat-status-dot')), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.byKey(const Key('heartbeat-animation')), findsNothing);
    expect(find.text('Unreachable'), findsOneWidget);
    expect(find.byTooltip('Tracker heartbeat: Unreachable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('availability dots retain independent status colors', (
    tester,
  ) async {
    for (final (status, color, label) in [
      (TrackerAvailability.online, Colors.green.shade800, 'Online'),
      (TrackerAvailability.unstable, Colors.amber.shade900, 'Unstable'),
      (TrackerAvailability.unreachable, Colors.grey.shade700, 'Unreachable'),
    ]) {
      await tester.pumpWidget(_host(status));
      final dot = tester.widget<Container>(
        find.byKey(const Key('heartbeat-status-dot')),
      );
      expect((dot.decoration! as BoxDecoration).color, color);
      expect(find.text(label), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('compact indicator fits narrow and wide layouts', (tester) async {
    for (final width in [320.0, 900.0]) {
      tester.view.physicalSize = Size(width, 300);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HeartbeatIndicator(
                status: TrackerAvailability.unstable,
                compact: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Unstable'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.reset();
    }
  });
}

Widget _host(TrackerAvailability status) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: HeartbeatIndicator(status: status)),
    ),
  );
}
