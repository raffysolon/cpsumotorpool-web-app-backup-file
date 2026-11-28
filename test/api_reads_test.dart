import 'package:cpsumotorpooladmin/services/api_config.dart';
import 'dart:async';

import 'package:cpsumotorpooladmin/services/api_reads.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('slow PDF downloads retain their 150-second allowance', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      '${ApiConfig.storageNamespace}:auth_token': 'slow-pdf-test',
    });
    await http.runWithClient(
      () async {
        var complete = false;
        Object? failure;
        final request = TripService.getTripTicket(99).then(
          (response) {
            expectSync(response.statusCode, 200);
            complete = true;
          },
          onError: (Object error) {
            failure = error;
          },
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 31));
        expect(failure, isNull);
        expect(complete, isFalse);
        await tester.pump(const Duration(seconds: 15));
        await request;
        expect(failure, isNull);
        expect(complete, isTrue);
      },
      () => MockClient((request) async {
        expectSync(request.headers['Accept'], 'application/pdf');
        await Future<void>.delayed(const Duration(seconds: 45));
        return http.Response(
          '%PDF-1.7 test',
          200,
          headers: {'content-type': 'application/pdf'},
        );
      }),
    );
  });
  test('concurrent notification refreshes share one inbox request', () async {
    FlutterSecureStorage.setMockInitialValues({
      '${ApiConfig.storageNamespace}:auth_token': 'notifications-test',
        '${ApiConfig.storageNamespace}:account_email': 'admin@example.test',
    });
    final paths = <String>[];
    await http.runWithClient(
      () async {
        final controller = AdminNotificationsController.instance;
        await Future.wait([
          controller.refresh(),
          controller.refresh(),
          controller.refresh(),
        ]);
        expect(paths, ['/api/notifications']);
      },
      () => MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          request.url.path.endsWith('unread-count') ? '{"count":0}' : '[]',
          200,
        );
      }),
    );
  });
  test('Retry-After supports seconds, server-relative dates and fallbacks', () {
    final now = DateTime.utc(2026, 11, 18, 13);
    expect(
      ApiReads.retryDelay(
        http.Response('', 429, headers: {'retry-after': '7'}),
        now,
      ),
      const Duration(seconds: 7),
    );
    expect(
      ApiReads.retryDelay(
        http.Response(
          '',
          429,
          headers: {
            'retry-after': 'Wed, 18 Nov 2026 13:01:30 GMT',
            'date': 'Wed, 18 Nov 2026 13:01:00 GMT',
          },
        ),
        now,
      ),
      const Duration(seconds: 30),
    );
    expect(
      ApiReads.retryDelay(
        http.Response(
          '{"retry_after":12}',
          429,
          headers: {'retry-after': 'invalid'},
        ),
        now,
      ),
      const Duration(seconds: 12),
    );
    expect(
      ApiReads.retryDelay(http.Response('html', 429), now),
      const Duration(seconds: 60),
    );
  });

  test(
    'shares concurrent reads but never serves a successful stale cache',
    () async {
      final pending = Completer<http.Response>();
      var calls = 0;
      await http.runWithClient(
        () async {
          final uri = Uri.parse('https://example.test/trips');
          final first = ApiReads.get(uri);
          final second = ApiReads.get(uri);
          await Future<void>.delayed(Duration.zero);
          expect(calls, 1);
          pending.complete(http.Response('[]', 200));
          await Future.wait([first, second]);
          await ApiReads.get(uri);
          expect(calls, 2);
        },
        () => MockClient((_) {
          calls++;
          return pending.future;
        }),
      );
    },
  );

  test('429 pauses all shared reads without affecting another user', () async {
    var calls = 0;
    final headers = {'Authorization': 'Bearer cooldown-test'};
    await http.runWithClient(
      () async {
        final first = Uri.parse('https://example.test/devices');
        final other = Uri.parse('https://example.test/gps/vehicles/7/latest');
        await expectLater(
          ApiReads.get(first, headers: headers),
          throwsA(isA<ApiRateLimitException>()),
        );
        await expectLater(
          ApiReads.get(other, headers: headers),
          throwsA(isA<ApiRateLimitException>()),
        );
        expect(calls, 1);
        // Separate users must not inherit another user's cooldown.
        await ApiReads.get(
          other,
          headers: {'Authorization': 'Bearer other-user'},
        );
        expect(calls, 2);
      },
      () => MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('', 429, headers: {'retry-after': '120'})
            : http.Response('{}', 200);
      }),
    );
  });

  test('reads resume when the server cooldown expires', () async {
    var calls = 0;
    await http.runWithClient(
      () async {
        final uri = Uri.parse('https://expiry.test/latest');
        await expectLater(
          ApiReads.get(uri),
          throwsA(isA<ApiRateLimitException>()),
        );
        await expectLater(
          ApiReads.get(uri),
          throwsA(isA<ApiRateLimitException>()),
        );
        expect(calls, 1);
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        expect((await ApiReads.get(uri)).statusCode, 200);
        expect(calls, 2);
      },
      () => MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('', 429, headers: {'retry-after': '1'})
            : http.Response('{}', 200);
      }),
    );
  });
}
