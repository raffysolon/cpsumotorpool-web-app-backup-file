import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unmocked network clients are blocked in the test harness', () {
    expect(
      () => HttpClient(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Network access is disabled'),
        ),
      ),
    );
  });
}
