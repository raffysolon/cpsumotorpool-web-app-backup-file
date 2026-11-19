import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiRateLimitException implements Exception {
  const ApiRateLimitException(this.retryAt);
  final DateTime retryAt;

  @override
  String toString() =>
      'API request limit reached. '
      'GPS tracking will retry automatically.';
}

/// Shares in-flight reads and the general API cooldown within this app session.
/// No successful responses are cached here, so mutations remain visible.
class ApiReads {
  static final Map<String, DateTime> _retryAt = {};
  static final Map<String, Future<http.Response>> _pending = {};

  static Duration retryDelay(http.Response response, DateTime now) {
    final value = response.headers['retry-after']?.trim();
    final seconds = int.tryParse(value ?? '');
    if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
    if (value != null) {
      try {
        final deadline = parseHttpDate(value);
        // Use the response clock when available, avoiding browser clock drift.
        final serverDate = response.headers['date'];
        final reference = serverDate == null ? now : parseHttpDate(serverDate);
        final delay = deadline.difference(reference);
        return delay.isNegative ? Duration.zero : delay;
      } on FormatException {
        // Fall through to the JSON fallback used by this Laravel API.
      }
    }
    try {
      final body = jsonDecode(response.body);
      final fallback = body is Map
          ? int.tryParse('${body['retry_after']}')
          : null;
      if (fallback != null && fallback >= 0) return Duration(seconds: fallback);
    } on FormatException {
      // Proxies may return non-JSON errors.
    }
    return const Duration(seconds: 60);
  }

  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
  }) {
    final session = headers?['Authorization'] ?? '';
    final scope = '${uri.origin}|$session';
    final deadline = _retryAt[scope];
    if (deadline != null && DateTime.now().isBefore(deadline)) {
      return Future.error(ApiRateLimitException(deadline));
    }
    final key = '$scope|$uri';
    return _pending.putIfAbsent(key, () async {
      try {
        final response = await http.get(uri, headers: headers).timeout(timeout);
        if (response.statusCode == 429) {
          final retryAt = DateTime.now().add(
            retryDelay(response, DateTime.now()),
          );
          final previous = _retryAt[scope];
          if (previous == null || retryAt.isAfter(previous)) {
            _retryAt[scope] = retryAt;
          }
          throw ApiRateLimitException(_retryAt[scope]!);
        }
        return response;
      } finally {
        _pending.remove(key);
      }
    });
  }
}
