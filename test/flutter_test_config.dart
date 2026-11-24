import 'dart:async';
import 'dart:io';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  HttpOverrides.global = _NoNetworkHttpOverrides();
  await testMain();
}

class _NoNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError(
      'Network access is disabled during Flutter tests; inject a MockClient.',
    );
  }
}
