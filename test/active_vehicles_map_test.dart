import 'dart:async';

import 'package:cpsumotorpooladmin/services/gps_service.dart';
import 'package:cpsumotorpooladmin/widgets/active_vehicles_map.dart';
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
