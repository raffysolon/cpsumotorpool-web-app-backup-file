import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginException implements Exception {
  const LoginException(this.message);

  final String message;
}

class AuthService {
  static const String baseUrl = 'https://cpsumotorpool-backend.onrender.com/api';
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 401) {
      throw const LoginException('Email or password was rejected by the server.');
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

    await _storage.write(key: 'auth_token', value: token);
    await _storage.write(key: 'role', value: data['role'] as String?);
    await _storage.write(key: 'name', value: data['name'] as String?);

    return data;
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<String?> getRole() async {
    return await _storage.read(key: 'role');
  }

  static Future<String?> getName() async {
    return await _storage.read(key: 'name');
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
      return {
        'role': role,
        'name': name,
      };
    }
    return null;
  }

  static Future<void> logout() async {
    await _storage.deleteAll();
  }

  static Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found');
    }

    final response = await http.put(
      Uri.parse('$baseUrl/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to change password');
    }
  }
}