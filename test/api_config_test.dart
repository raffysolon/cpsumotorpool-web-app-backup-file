import 'package:cpsumotorpooladmin/services/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds endpoint URIs under a single API prefix', () {
    expect(ApiConfig.apiUri('devices').path, '/api/devices');
    expect(ApiConfig.apiUri('/api/devices').path, '/api/devices');
    expect(ApiConfig.apiUri('api/api/devices').path, '/api/devices');
  });

  test('preserves endpoint query parameters', () {
    final uri = ApiConfig.apiUri(
      'gps/sync-logs',
      queryParameters: {'page': '2'},
    );

    expect(uri.path, '/api/gps/sync-logs');
    expect(uri.queryParameters, {'page': '2'});
  });

  test('uses the compile-time API base URL', () {
    const configuredApiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://cpsu-motorpool-backend.onrender.com/api',
    );

    expect(
      ApiConfig.apiUri('devices').origin,
      Uri.parse(configuredApiBaseUrl).origin,
    );
  });
}
