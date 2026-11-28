import 'dart:convert';

import 'package:cpsumotorpooladmin/services/api_config.dart';
import 'package:cpsumotorpooladmin/widgets/recorded_trip_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('recorded route leaves GPS gaps and trip legs disconnected', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      '${ApiConfig.storageNamespace}:auth_token': 'route-test',
    });
    Map<String, Object> point(double latitude, int minutes) => {
      'latitude': latitude,
      'longitude': 123.4,
      'recorded_at': DateTime.utc(2026, 11, 28, 1, minutes).toIso8601String(),
    };

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: RecordedTripRoute(tripId: 42)),
          ),
        );
        await tester.pumpAndSettle();

        final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
        expect(layer.polylines.map((line) => line.points.length), [2, 2, 2]);
        expect(find.text('Outbound'), findsOneWidget);
        expect(find.text('Return'), findsOneWidget);
      },
      () => MockClient((request) async {
        expect(request.url.path, '/api/trips/42/recorded-route');
        return http.Response(
          jsonEncode({
            'legs': [
              {
                'movement_no': 1,
                'points': [
                  point(10.1, 0),
                  point(10.2, 1),
                  point(10.3, 6),
                  point(10.4, 7),
                ],
              },
              {
                'movement_no': 2,
                'points': [point(10.4, 8), point(10.1, 9)],
              },
            ],
          }),
          200,
        );
      }),
    );
  });
}
