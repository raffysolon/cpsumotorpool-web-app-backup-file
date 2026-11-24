import 'package:cpsumotorpooladmin/widgets/driver_trip_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('trip details stack on mobile and align on desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(_host());

    final vehicleMobile = tester.getRect(find.text('VEHICLE'));
    final departureMobile = tester.getRect(find.text('DEPARTURE'));
    expect(departureMobile.top, greaterThan(vehicleMobile.bottom));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1000, 800);
    await tester.pumpWidget(_host());
    final vehicleDesktop = tester.getRect(find.text('VEHICLE'));
    final departureDesktop = tester.getRect(find.text('DEPARTURE'));
    expect(departureDesktop.top, vehicleDesktop.top);
    expect(tester.takeException(), isNull);
    tester.view.reset();
  });
}

Widget _host() => MaterialApp(
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: DriverTripDetails(
        vehicle: 'Local Test Vehicle 9',
        departure: 'Nov 24, 2026 • 9:33 PM',
        status: 'Scheduled',
      ),
    ),
  ),
);
