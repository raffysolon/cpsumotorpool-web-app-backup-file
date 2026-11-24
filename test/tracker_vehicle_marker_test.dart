import 'package:cpsumotorpooladmin/models/tracker_availability.dart';
import 'package:cpsumotorpooladmin/widgets/active_vehicles_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('online truck marker has a smooth double beat', (tester) async {
    await tester.pumpWidget(_host(TrackerAvailability.online));

    await tester.pump(const Duration(milliseconds: 120));
    final firstBeat = _scale(tester);
    await tester.pump(const Duration(milliseconds: 180));
    final betweenBeats = _scale(tester);
    await tester.pump(const Duration(milliseconds: 120));
    final secondBeat = _scale(tester);

    expect(firstBeat, greaterThan(1.08));
    expect(betweenBeats, closeTo(1, 0.01));
    expect(secondBeat, greaterThan(1.04));
    _expectDotStatic(tester);
  });

  testWidgets('unstable truck marker pulses slower than online', (
    tester,
  ) async {
    final online = await _scaleAfter(tester, TrackerAvailability.online);
    final unstable = await _scaleAfter(tester, TrackerAvailability.unstable);

    expect(online, greaterThan(unstable));
    expect(unstable, greaterThan(1));
  });

  testWidgets('unstable status dot stays amber over recent GPS color', (
    tester,
  ) async {
    await tester.pumpWidget(_host(TrackerAvailability.unstable));

    expect(_dotColor(tester), Colors.amber.shade900);
    expect(_truckColor(tester), const Color(0xFF1F8A3D));
    _expectDotStatic(tester);
  });

  testWidgets('unreachable truck marker stays still with a gray dot', (
    tester,
  ) async {
    await tester.pumpWidget(_host(TrackerAvailability.unreachable));
    await tester.pump(const Duration(seconds: 1));

    expect(_scale(tester), 1);
    expect(_dotColor(tester), Colors.grey.shade800);
    _expectDotStatic(tester);
  });

  testWidgets('reduced motion keeps the truck marker stationary', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(TrackerAvailability.online, disableAnimations: true),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(_scale(tester), 1);
    _expectDotStatic(tester);
  });

  testWidgets('map refresh preserves the animation phase and GPS center', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(TrackerAvailability.online, isRecent: true, key: const ValueKey(1)),
    );
    await tester.pump(const Duration(milliseconds: 120));
    final beforeRefresh = _scale(tester);

    await tester.pumpWidget(
      _host(
        TrackerAvailability.online,
        isRecent: false,
        key: const ValueKey(1),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final afterRefresh = _scale(tester);
    expect(afterRefresh, lessThan(beforeRefresh));
    expect(_truckColor(tester), Colors.grey);
    expect(_dotColor(tester), Colors.green.shade800);
    expect(
      tester
          .widget<ScaleTransition>(
            find.byKey(const Key('vehicle-marker-animation')),
          )
          .alignment,
      Alignment.center,
    );
    _expectDotStatic(tester);
  });
}

double _scale(WidgetTester tester) {
  return tester
      .widget<ScaleTransition>(
        find.byKey(const Key('vehicle-marker-animation')),
      )
      .scale
      .value;
}

Future<double> _scaleAfter(
  WidgetTester tester,
  TrackerAvailability status,
) async {
  await tester.pumpWidget(_host(status));
  await tester.pump(const Duration(milliseconds: 120));
  final value = _scale(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  return value;
}

Color? _truckColor(WidgetTester tester) {
  final marker = tester.widget<Container>(
    find.descendant(
      of: find.byKey(const Key('vehicle-marker-animation')),
      matching: find.byType(Container),
    ),
  );
  return (marker.decoration! as BoxDecoration).color;
}

Color? _dotColor(WidgetTester tester) {
  final dot = tester.widget<Container>(
    find.byKey(const Key('vehicle-connectivity-dot')),
  );
  return (dot.decoration! as BoxDecoration).color;
}

void _expectDotStatic(WidgetTester tester) {
  expect(
    find.ancestor(
      of: find.byKey(const Key('vehicle-connectivity-dot')),
      matching: find.byType(ScaleTransition),
    ),
    findsNothing,
  );
}

Widget _host(
  TrackerAvailability status, {
  bool isRecent = true,
  bool disableAnimations = false,
  Key? key,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: TrackerVehicleMarker(
          key: key,
          isRecent: isRecent,
          availabilityStatus: status,
        ),
      ),
    ),
  );
}
