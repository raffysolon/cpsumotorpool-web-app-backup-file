class ApiConfig {
  static const String _defaultApiBaseUrl =
      'https://cpsu-motorpool-backend.onrender.com/api';
  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );

  static final Uri _apiBaseUri = _normalizeBaseUri(_configuredApiBaseUrl);

  static String get apiBaseUrl =>
      _apiBaseUri.toString().replaceFirst(RegExp(r'/$'), '');

  static String get storageNamespace => Uri.encodeComponent(apiBaseUrl);

  static Uri apiUri(String endpoint, {Map<String, String>? queryParameters}) {
    var relativePath = endpoint.replaceFirst(RegExp(r'^/+'), '');
    while (relativePath.toLowerCase() == 'api' ||
        relativePath.toLowerCase().startsWith('api/')) {
      relativePath = relativePath.length == 3 ? '' : relativePath.substring(4);
    }
    final path = relativePath.isEmpty
        ? _apiBaseUri.path
        : '${_apiBaseUri.path}/$relativePath';
    final uri = _apiBaseUri.replace(path: path, query: null, fragment: null);
    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }

  static Uri _normalizeBaseUri(String value) {
    final uri = Uri.parse(value.trim());
    if ((uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'API_BASE_URL must be an absolute HTTP(S) URL without credentials, '
        'a query, or a fragment.',
      );
    }

    var path = uri.path.replaceAll(RegExp(r'/+$'), '');
    path = path.replaceAll(RegExp(r'(?:/api)+$', caseSensitive: false), '/api');
    if (!path.toLowerCase().endsWith('/api')) {
      path = '$path/api';
    }

    return uri.replace(path: path);
  }
}
