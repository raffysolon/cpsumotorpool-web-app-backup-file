import 'dart:async';
import 'package:cpsumotorpooladmin/services/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'package:cpsumotorpooladmin/services/session_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final role in ['admin', 'driver']) {
    test('$role is signed out after token revocation', () async {
      FlutterSecureStorage.setMockInitialValues({
        '${ApiConfig.storageNamespace}:last_activity': DateTime.now()
            .millisecondsSinceEpoch
            .toString(),
        '${ApiConfig.storageNamespace}:auth_token': role,
        '${ApiConfig.storageNamespace}:role': role,
      });
      await http.runWithClient(() async {
        expect(await SessionMonitor().check(), isTrue);
        expect(await AuthService.getToken(), isNull);
        expect(await AuthService.getRole(), isNull);
      }, () => MockClient((_) async => http.Response('{}', 401)));
    });
  }
  for (final status in [200, 403, 429, 500]) {
    test('HTTP $status does not sign out the user', () async {
      FlutterSecureStorage.setMockInitialValues({
        '${ApiConfig.storageNamespace}:last_activity': DateTime.now()
            .millisecondsSinceEpoch
            .toString(),
        '${ApiConfig.storageNamespace}:auth_token': 'status-$status',
      });
      await http.runWithClient(() async {
        expect(await SessionMonitor().check(), isFalse);
        expect(await AuthService.getToken(), 'status-$status');
      }, () => MockClient((_) async => http.Response('{}', status)));
    });
  }
  test('offline keeps session', () async {
    FlutterSecureStorage.setMockInitialValues({
      '${ApiConfig.storageNamespace}:last_activity': DateTime.now()
          .millisecondsSinceEpoch
          .toString(),
      '${ApiConfig.storageNamespace}:auth_token': 'offline',
    });
    await http.runWithClient(() async {
      expect(await SessionMonitor().check(), isFalse);
      expect(await AuthService.getToken(), 'offline');
    }, () => MockClient((_) async => throw http.ClientException('offline')));
  });
  test(
    'overlapping checks and stale responses cannot sign out new login',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        '${ApiConfig.storageNamespace}:last_activity': DateTime.now()
            .millisecondsSinceEpoch
            .toString(),
        '${ApiConfig.storageNamespace}:auth_token': 'old',
      });
      final result = Completer<http.Response>();
      final started = Completer<void>();
      final monitor = SessionMonitor();
      var calls = 0;
      await http.runWithClient(
        () async {
          final pending = monitor.check();
          await started.future;
          expect(await monitor.check(), isFalse);
          FlutterSecureStorage.setMockInitialValues({
            '${ApiConfig.storageNamespace}:last_activity': DateTime.now()
                .millisecondsSinceEpoch
                .toString(),
            '${ApiConfig.storageNamespace}:auth_token': 'new',
          });
          result.complete(http.Response('{}', 401));
          expect(await pending, isFalse);
          expect(await AuthService.getToken(), 'new');
          expect(calls, 1);
        },
        () => MockClient((_) {
          calls++;
          started.complete();
          return result.future;
        }),
      );
    },
  );
}
