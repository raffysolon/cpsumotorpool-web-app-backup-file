import 'dart:async';

import 'package:cpsumotorpooladmin/services/gps_service.dart';
import 'package:cpsumotorpooladmin/services/api_reads.dart';
import 'package:cpsumotorpooladmin/widgets/active_vehicles_map.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

const vehicles = [
  TrackedVehicle(
    vehicleId: 7,
    deviceId: 'VEHICLE-01',
    plate: 'ABC 1234',
    name: 'Hiace',
  ),
  TrackedVehicle(
    vehicleId: 8,
    deviceId: 'VEHICLE-02',
    plate: 'XYZ 5678',
    name: 'Bus',
  ),
];

GpsLocation location(int id, {double latitude = 10.589795}) => GpsLocation(
  id: 3177,
  vehicleId: id,
  latitude: latitude,
  longitude: 123.476213,
  recordedAt: DateTime.utc(2026, 11, 17, 17, 41, 1),
  satellites: 12,
);

void main() {
  for (final state in [
    'unassigned',
    'scheduled',
    'active',
    'stale',
    'legacy',
  ]) {
    testWidgets('marker and trip tooltip reflect $state GPS', (tester) async {
      final trip = {
        'id': 42,
        'status': state == 'active' ? 'active' : 'scheduled',
        'scheduled_departure': '2026-11-18T01:00:00Z',
        'actual_departure_at': state == 'active'
            ? '2026-11-18T01:12:00Z'
            : null,
        'late_minutes': state == 'active' ? 12 : null,
        'departure_overdue': state == 'scheduled',
      };
      final gps = GpsLocation.fromJson({
        'id': 1,
        'vehicle_id': 7,
        'latitude': 10.5,
        'longitude': 123.4,
        'recorded_at': DateTime.now()
            .toUtc()
            .subtract(Duration(seconds: state == 'stale' ? 120 : 15))
            .toIso8601String(),
        if (state != 'legacy')
          'trip': ['scheduled', 'active'].contains(state) ? trip : null,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveVehiclesMap(
              loadVehicles: () async => [vehicles.first],
              loadLocation: (_) async => gps,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.local_shipping_rounded), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(
        find.descendant(
          of: find.byType(MarkerLayer),
          matching: find.byType(Tooltip),
        ),
      );
      if (state == 'active') {
        expect(tooltip.message, contains('Late: 12 minute(s)'));
      }
      if (state == 'scheduled') {
        expect(tooltip.message, contains('5-minute grace period passed'));
      }
      if (state == 'legacy') {
        expect(tooltip.message, contains('Trip assignment unavailable'));
      }
      if (state == 'unassigned') {
        expect(tooltip.message, contains('No scheduled or active trip'));
      }
      expect(
        tooltip.message,
        contains(state == 'stale' ? 'Outdated GPS' : 'Recent GPS'),
      );
      expect(
        tooltip.message,
        contains('Last heartbeat: No heartbeat recorded'),
      );
      expect(tooltip.message, contains('Last GPS update:'));
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('tracker status shows a heartbeat without a GPS fix', (
    tester,
  ) async {
    final vehicle = TrackedVehicle.fromJson({
      'vehicle_id': 7,
      'device_id': 'VEHICLE-01',
      'vehicle_name': 'Hiace',
      'vehicle_plate': 'ABC 1234',
      'last_heartbeat_received_at': '2026-11-28 01:02:03',
      'availability_status': 'online',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveVehiclesMap(
            loadVehicles: () async => [vehicle],
            loadLocation: (_) async => null,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Tracker status'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Last heartbeat: 2026-11-28 09:02:03 PHT · Online'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Last GPS update: No GPS recorded'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.local_shipping_rounded), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('retained GPS ages to gray during a rate-limit cooldown', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 18, 13);
    final gps = _ClockedLocation(now, () => now);
    var limited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveVehiclesMap(
            loadVehicles: () async {
              if (limited) {
                throw ApiRateLimitException(
                  now.add(const Duration(minutes: 1)),
                );
              }
              return [vehicles.first];
            },
            loadLocation: (_) async => gps,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('1 recent GPS / 1 registered'), findsOneWidget);
    limited = true;
    now = now.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    final markers = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers;
    expect(markers, hasLength(1));
    expect(markers.single.point, gps.position);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            (widget.message?.contains('GPS freshness: Outdated GPS') ?? false),
      ),
      findsOneWidget,
    );
    final pin = find.descendant(
      of: find.byType(MarkerLayer),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.key != const Key('vehicle-connectivity-dot') &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(
      (tester.widget<Container>(pin).decoration! as BoxDecoration).color,
      Colors.grey,
    );
    expect(find.textContaining('API request limit reached'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('covered routes and hidden app stop GPS polling', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: ActiveVehiclesMap(
            loadVehicles: () async => [vehicles.first],
            loadLocation: (_) async {
              calls++;
              return location(7);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(calls, 1);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covered')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    expect(calls, 1);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(calls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 15));
    expect(calls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('fresh GPS is green and stale GPS is gray after refresh', (
    tester,
  ) async {
    var stale = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveVehiclesMap(
            loadVehicles: () async => [vehicles.first],
            loadLocation: (_) async => GpsLocation.fromJson({
              'id': 1,
              'vehicle_id': 7,
              'latitude': 10.589795,
              'longitude': 123.476213,
              'recorded_at': DateTime.now()
                  .toUtc()
                  .subtract(Duration(seconds: stale ? 120 : 15))
                  .toIso8601String(),
            }),
          ),
        ),
      ),
    );
    await tester.pump();

    Color? markerColor() {
      final pin = find.descendant(
        of: find.byType(MarkerLayer),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.key != const Key('vehicle-connectivity-dot') &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      return (tester.widget<Container>(pin).decoration! as BoxDecoration).color;
    }

    expect(find.textContaining('1 recent GPS / 1 registered'), findsOneWidget);
    expect(markerColor(), AppColors.primary);
    stale = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.textContaining('0 recent GPS / 1 registered'), findsOneWidget);
    expect(markerColor(), Colors.grey);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty GPS state has no sample markers or invented timestamp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveVehiclesMap(
            loadVehicles: () async => [vehicles.first],
            loadLocation: (_) async => null,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      isEmpty,
    );
    expect(find.text('No GPS locations available yet.'), findsOneWidget);
    expect(find.textContaining('Latest GPS:'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'shows GPS date/time, updates healthy vehicles and retains failed ones',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var round = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveVehiclesMap(
              loadVehicles: () async => vehicles,
              loadLocation: (id) async {
                if (round > 0 && id == 7) {
                  throw Exception('Network unavailable');
                }
                return location(id, latitude: round > 0 ? 11 : 10.589795);
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Latest GPS: 2026-11-18 01:41:01 PHT'), findsOneWidget);
      expect(find.textContaining('Last successful refresh:'), findsOneWidget);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        hasLength(2),
      );
      round++;
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      expect(markers.map((m) => m.point.latitude), [10.589795, 11]);
      expect(find.textContaining('Network unavailable'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('prevents overlapping polls and stops polling after disposal', (
    tester,
  ) async {
    final pending = Completer<GpsLocation?>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveVehiclesMap(
            loadVehicles: () async => [vehicles.first],
            loadLocation: (_) {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 15));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    pending.complete(location(7));
    await tester.pump(const Duration(seconds: 10));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clears locations on authentication failure', (tester) async {
    var denied = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveVehiclesMap(
            loadVehicles: () async => [vehicles.first],
            loadLocation: (_) async {
              if (denied) {
                throw const GpsAccessException('Please log in again.');
              }
              return location(7);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    denied = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      isEmpty,
    );
    expect(find.textContaining('Latest GPS:'), findsNothing);
    expect(find.text('Please log in again.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class _ClockedLocation extends GpsLocation {
  _ClockedLocation(DateTime recorded, this.now)
    : super(
        id: 1,
        vehicleId: 7,
        latitude: 10.589795,
        longitude: 123.476213,
        recordedAt: recorded,
      );
  final DateTime Function() now;
  @override
  bool get isRecent => isRecentAt(now());
}
