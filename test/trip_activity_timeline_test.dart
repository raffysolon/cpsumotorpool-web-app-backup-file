import 'dart:convert';

import 'package:cpsumotorpooladmin/services/api_config.dart';
import 'package:cpsumotorpooladmin/widgets/trip_activity_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('timeline displays recorded actors and labels missing history', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      '${ApiConfig.storageNamespace}:auth_token': 'activity-test',
    });
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: TripActivityTimeline(tripId: 42)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Trip request submitted'), findsOneWidget);
        expect(find.text('Driver name not recorded'), findsOneWidget);
        expect(find.text('Driver Santos (Driver)'), findsOneWidget);
        expect(find.text('Nov 28, 2026 8:35 AM PHT'), findsOneWidget);
        expect(find.text('5 min late'), findsOneWidget);
        expect(
          find.text('The approval or denial time was not recorded.'),
          findsOneWidget,
        );
      },
      () => MockClient((request) async {
        expect(request.url.path, '/api/trips/42/activity');
        return http.Response(
          jsonEncode({
            'events': [
              {
                'action': 'submitted',
                'actor_name': null,
                'actor_role': 'driver',
                'occurred_at': '2026-11-28T00:00:00Z',
              },
              {
                'action': 'outbound_started',
                'actor_name': 'Driver Santos',
                'actor_role': 'driver',
                'occurred_at': '2026-11-28T00:35:00Z',
                'late_minutes': 5,
              },
            ],
            'decision_time_missing': true,
          }),
          200,
        );
      }),
    );
  });
}
