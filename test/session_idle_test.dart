import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'package:cpsumotorpooladmin/services/api_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final start = DateTime.utc(2026, 11, 27, 8);
  String key(String name) => '${ApiConfig.storageNamespace}:$name';
  void seed(String role, {bool timestamp = true}) {
    FlutterSecureStorage.setMockInitialValues({
      key('auth_token'): 'test-token',
      key('role'): role,
      if (timestamp)
        key('last_activity'): start.millisecondsSinceEpoch.toString(),
    });
  }

  for (final role in ['admin', 'driver']) {
    test(
      '$role reopening after an hour expires without a running timer',
      () async {
        seed(role);
        expect(
          await AuthService.expireIdleSession(
            now: start.add(const Duration(hours: 1)),
          ),
          isTrue,
        );
        expect(await AuthService.getToken(), isNull);
        expect(await AuthService.getRole(), isNull);
      },
    );
    test('$role expires at exactly five minutes', () async {
      seed(role);
      expect(
        await AuthService.expireIdleSession(
          now: start.add(const Duration(minutes: 5)),
        ),
        isTrue,
      );
    });
  }
  test('reopening before timeout does not extend the deadline', () async {
    seed('admin');
    expect(
      await AuthService.expireIdleSession(
        now: start.add(const Duration(minutes: 4)),
      ),
      isFalse,
    );
    expect(
      await AuthService.expireIdleSession(
        now: start.add(const Duration(minutes: 5)),
      ),
      isTrue,
    );
  });
  test('real activity extends a valid session', () async {
    seed('driver');
    expect(
      await AuthService.recordActivity(
        now: start.add(const Duration(minutes: 4)),
      ),
      isFalse,
    );
    expect(
      await AuthService.expireIdleSession(
        now: start.add(const Duration(minutes: 8)),
      ),
      isFalse,
    );
    expect(
      await AuthService.expireIdleSession(
        now: start.add(const Duration(minutes: 9)),
      ),
      isTrue,
    );
  });
  test('first input after expiry cannot revive the session', () async {
    seed('admin');
    expect(
      await AuthService.recordActivity(
        now: start.add(const Duration(hours: 1)),
      ),
      isTrue,
    );
    expect(await AuthService.getToken(), isNull);
  });
  test('old sessions without timestamps require login again', () async {
    seed('driver', timestamp: false);
    expect(await AuthService.expireIdleSession(now: start), isTrue);
  });
}
