import 'dart:convert';

import 'package:cpsumotorpooladmin/services/api_config.dart';
import 'package:cpsumotorpooladmin/services/gps_service.dart';
import 'package:cpsumotorpooladmin/widgets/active_trip_eta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('missing pin offers an action and ETA appears after refresh', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      '${ApiConfig.storageNamespace}:auth_token': 'eta-test',
    });
    final now = DateTime.now().toUtc();
    var pinSaved = false;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActiveTripEta(
                vehicleName: 'Van',
                location: GpsLocation(
                  id: 1,
                  vehicleId: 1,
                  latitude: 10.1,
                  longitude: 123.2,
                  recordedAt: now,
                  trip: GpsTrip(
                    id: 42,
                    status: 'active',
                    scheduledDeparture: now,
                    destination: 'Campus B',
                  ),
                ),
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Set pin'), findsOneWidget);

        pinSaved = true;
        await tester.pump(const Duration(seconds: 30));
        await tester.pumpAndSettle();
        expect(find.text('Set pin'), findsNothing);
        expect(find.textContaining('Estimated arrival'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      () => MockClient((request) async {
        expect(request.url.path, '/api/trips/42/eta');
        return http.Response(
          jsonEncode({
            'status': pinSaved ? 'available' : 'pin_missing',
            if (pinSaved) ...{
              'arrival_at': now
                  .add(const Duration(minutes: 15))
                  .toIso8601String(),
              'gps_recorded_at': now.toIso8601String(),
            },
          }),
          200,
        );
      }),
    );
  });
}
