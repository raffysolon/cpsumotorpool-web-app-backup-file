import 'dart:async';
import 'dart:convert';

import 'package:cpsumotorpooladmin/services/gps_service.dart';
import 'package:cpsumotorpooladmin/services/api_reads.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';
import 'package:cpsumotorpooladmin/services/notification_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> locationJson({int vehicleId = 7}) => {
  'id': 3177,
  'vehicle_id': vehicleId,
  'latitude': '10.589795',
  'longitude': '123.476213',
  'satellites': 12,
  'recorded_at': '2026-11-17T17:41:01.000000Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    GpsService.clearCache();
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-session'});
  });
  tearDown(GpsService.clearCache);

  test('parses Laravel decimal strings and UTC recording time', () {
    final location = GpsLocation.fromJson(locationJson());
    expect(location.latitude, 10.589795);
    expect(location.longitude, 123.476213);
    expect(location.recordedAt, DateTime.utc(2026, 11, 17, 17, 41, 1));
    expect(location.vehicleId, 7);
  });

  test('rejects invalid and out-of-range coordinates', () {
    for (final value in ['NaN', 'Infinity', 'bad', 91, -91]) {
      expect(
        () => GpsLocation.fromJson({...locationJson(), 'latitude': value}),
        throwsFormatException,
      );
    }
  });

  test('UTC, Philippine offsets and unzoned backend UTC are equivalent', () {
    final now = DateTime.utc(2026, 11, 18, 2, 0, 15);
    for (final timestamp in [
      '2026-11-18T02:00:00Z',
      '2026-11-18T10:00:00+08:00',
      '2026-11-18T10:00:00+0800',
      '2026-11-18 02:00:00',
      '2026-11-18T02:00:00.000000',
    ]) {
      final location = GpsLocation.fromJson({
        ...locationJson(),
        'recorded_at': timestamp,
      });
      expect(location.recordedAt, DateTime.utc(2026, 11, 18, 2));
      expect(location.recordedAt.isUtc, isTrue);
      expect(location.isRecentAt(now), isTrue, reason: timestamp);
      expect(location.isRecentAt(now.toLocal()), isTrue);
      expect(location.isRecentAt(now.add(const Duration(minutes: 1))), isFalse);
    }
  });

  test('freshness covers upload delays but expires and bounds clock skew', () {
    final location = GpsLocation.fromJson(locationJson());
    for (final seconds in [-5, 0, 15, 20, 30, 45, 60]) {
      expect(
        location.isRecentAt(
          location.recordedAt.add(Duration(seconds: seconds)),
        ),
        isTrue,
        reason: 'age $seconds seconds',
      );
    }
    for (final seconds in [-28800, -6, 61, 300, 28800]) {
      expect(
        location.isRecentAt(
          location.recordedAt.add(Duration(seconds: seconds)),
        ),
        isFalse,
        reason: 'age $seconds seconds',
      );
    }
  });

  test('rate limiting pauses subsequent GPS requests', () async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'limited-session',
    });
    var requests = 0;
    await http.runWithClient(
      () async {
        await expectLater(GpsService.getLatestLocation(7), throwsException);
        await expectLater(GpsService.getLatestLocation(8), throwsException);
        expect(requests, 1);
      },
      () => MockClient((_) async {
        requests++;
        return http.Response('{}', 429, headers: {'retry-after': '120'});
      }),
    );
  });

  test(
    'registry 429 pauses GPS, trip and notification reads together',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'registry-limited',
      });
      var requests = 0;
      await http.runWithClient(
        () async {
          await expectLater(
            GpsService.getTrackedVehicles(),
            throwsA(isA<ApiRateLimitException>()),
          );
          await expectLater(
            GpsService.getLatestLocation(7),
            throwsA(isA<ApiRateLimitException>()),
          );
          await expectLater(
            TripService.getAllTrips(),
            throwsA(isA<ApiRateLimitException>()),
          );
          await expectLater(
            NotificationService.getUnreadCount(),
            throwsA(isA<ApiRateLimitException>()),
          );
          expect(requests, 1);
        },
        () => MockClient((_) async {
          requests++;
          return http.Response('{}', 429, headers: {'retry-after': '120'});
        }),
      );
    },
  );

  test(
    'uses authenticated GET and shares concurrent and cached requests',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(request.method, 'GET');
        expect(request.url.path, '/api/gps/vehicles/7/latest');
        expect(request.headers['Authorization'], 'Bearer test-session');
        expect(request.headers.containsKey('X-Gateway-Key'), isFalse);
        return http.Response(jsonEncode(locationJson()), 200);
      });
      await http.runWithClient(() async {
        final results = await Future.wait([
          GpsService.getLatestLocation(7),
          GpsService.getLatestLocation(7),
        ]);
        expect(results.first!.id, 3177);
        await GpsService.getLatestLocation(7);
        expect(requests, 1);
      }, () => client);
    },
  );

  test('only explicit no-location response is treated as empty', () async {
    for (final body in [
      '{"message":"No GPS location found."}',
      '<html>404</html>',
    ]) {
      GpsService.clearCache();
      await http.runWithClient(() async {
        final result = GpsService.getLatestLocation(7);
        if (body.startsWith('{')) {
          expect(await result, isNull);
        } else {
          await expectLater(result, throwsException);
        }
      }, () => MockClient((_) async => http.Response(body, 404)));
    }
  });

  test('rejects another vehicle and denied access', () async {
    for (final status in [200, 401, 403]) {
      GpsService.clearCache();
      await http.runWithClient(
        () async {
          await expectLater(
            GpsService.getLatestLocation(7),
            status == 200
                ? throwsFormatException
                : throwsA(isA<GpsAccessException>()),
          );
        },
        () => MockClient(
          (_) async =>
              http.Response(jsonEncode(locationJson(vehicleId: 8)), status),
        ),
      );
    }
  });

  test('old-session response cannot populate the new-session cache', () async {
    final started = Completer<void>();
    final delayed = Completer<http.Response>();
    var requests = 0;
    await http.runWithClient(
      () async {
        final oldRequest = GpsService.getLatestLocation(7);
        final rejected = expectLater(
          oldRequest,
          throwsA(isA<GpsAccessException>()),
        );
        await started.future;
        FlutterSecureStorage.setMockInitialValues({
          'auth_token': 'new-test-session',
        });
        final current = await GpsService.getLatestLocation(7);
        delayed.complete(
          http.Response(jsonEncode({...locationJson(), 'id': 1}), 200),
        );
        await rejected;
        expect(current!.id, 3177);
        expect((await GpsService.getLatestLocation(7))!.id, 3177);
        expect(requests, 2);
      },
      () => MockClient((_) {
        requests++;
        if (requests == 1) {
          started.complete();
          return delayed.future;
        }
        return Future.value(http.Response(jsonEncode(locationJson()), 200));
      }),
    );
  });
}
