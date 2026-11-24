import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cpsumotorpooladmin/services/api_config.dart';

class LoginException implements Exception {
  const LoginException(this.message);

  final String message;
}

class PasswordResetResult {
  const PasswordResetResult({this.attemptsRemaining, this.retryAfter = 0});
  final int? attemptsRemaining;
  final int retryAfter;

  factory PasswordResetResult.fromJson(Map<String, dynamic> data) {
    return PasswordResetResult(
      attemptsRemaining: (data['attempts_remaining'] as num?)?.toInt(),
      retryAfter: (data['retry_after'] as num?)?.toInt() ?? 0,
    );
  }
}

class PasswordResetLimitException implements Exception {
  const PasswordResetLimitException(this.message, this.retryAfter);
  final String message;
  final int retryAfter;
}

class AuthService {
  static String get baseUrl => ApiConfig.apiBaseUrl;
  static const _storage = FlutterSecureStorage();
  static Future<String?>? _accountScopeRequest;

  static String _storageKey(String key) => '${ApiConfig.storageNamespace}:$key';

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      ApiConfig.apiUri('login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 401) {
      throw const LoginException(
        'Email or password was rejected by the server.',
      );
    }
    if (response.statusCode == 422) {
      throw const LoginException('The email or password format is invalid.');
    }
    if (response.statusCode == 429) {
      throw const LoginException(
        'Too many login attempts. Wait a minute, then try again.',
      );
    }
    if (response.statusCode >= 500) {
      throw LoginException(
        'The server returned an error (${response.statusCode}).',
      );
    }
    if (response.statusCode != 200) {
      throw LoginException('Login request failed (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const LoginException('The server returned no login token.');
    }

    await _storage.write(key: _storageKey('auth_token'), value: token);
    await _storage.write(
      key: _storageKey('role'),
      value: data['role'] as String?,
    );
    await _storage.write(
      key: _storageKey('name'),
      value: data['name'] as String?,
    );
    await _storage.write(
      key: _storageKey('account_email'),
      value: email.trim().toLowerCase(),
    );
    _accountScopeRequest = null;

    return data;
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _storageKey('auth_token'));
  }

  static Future<String?> getRole() async {
    return await _storage.read(key: _storageKey('role'));
  }

  static Future<String?> getName() async {
    return await _storage.read(key: _storageKey('name'));
  }

  static Future<String?> getNotificationAccountScope() async {
    final storedEmail = await _storage.read(key: _storageKey('account_email'));
    if (storedEmail != null && storedEmail.trim().isNotEmpty) {
      return storedEmail.trim().toLowerCase();
    }

    final pending = _accountScopeRequest;
    if (pending != null) return pending;
    return _accountScopeRequest = _loadNotificationAccountScope();
  }

  static Future<String?> _loadNotificationAccountScope() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;

    final response = await http.get(
      ApiConfig.apiUri('user'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw const LoginException(
        'Unable to verify the signed-in account for notification preferences.',
      );
    }

    final profile = jsonDecode(response.body);
    if (profile is! Map || profile['email'] is! String) {
      throw const FormatException(
        'The account response did not include email.',
      );
    }
    final email = (profile['email'] as String).trim().toLowerCase();
    if (email.isEmpty) {
      throw const FormatException(
        'The account response did not include email.',
      );
    }
    await _storage.write(key: _storageKey('account_email'), value: email);
    return email;
  }

  /// Check if user is currently logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Get stored user data
  static Future<Map<String, dynamic>?> getUserData() async {
    final role = await getRole();
    final name = await getName();

    if (role != null) {
      return {'role': role, 'name': name};
    }
    return null;
  }

  static Future<void> logout() async {
    await Future.wait([
      _storage.delete(key: _storageKey('auth_token')),
      _storage.delete(key: _storageKey('role')),
      _storage.delete(key: _storageKey('name')),
      _storage.delete(key: _storageKey('account_email')),
    ]);
    _accountScopeRequest = null;
  }

  static Future<void> changePassword(String currentPassword) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found');
    }

    final response = await http.put(
      ApiConfig.apiUri('change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'current_password': currentPassword}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Unable to send the password reset email.';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['message'] is String) {
          message = data['message'] as String;
        }
      } catch (_) {}
      throw LoginException(message);
    }
  }

  static Future<PasswordResetResult> requestPasswordReset(String email) async {
    late final http.Response response;
    try {
      response = await http
          .post(
            ApiConfig.apiUri('password/forgot'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const LoginException(
        'The request timed out. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const LoginException(
        'Cannot connect to the server. Check your connection and try again.',
      );
    }

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      // A proxy may return a non-JSON error.
    }
    if (response.statusCode == 429) {
      final seconds =
          (data['retry_after'] as num?)?.toInt() ??
          int.tryParse(response.headers['retry-after'] ?? '') ??
          300;
      throw PasswordResetLimitException(
        data['message'] as String? ??
            'Too many attempts. Please wait before trying again.',
        seconds > 0 ? seconds : 1,
      );
    }
    if (response.statusCode != 200) {
      throw const LoginException(
        'Unable to send the request. Please try again later.',
      );
    }
    return PasswordResetResult.fromJson(data);
  }
}
