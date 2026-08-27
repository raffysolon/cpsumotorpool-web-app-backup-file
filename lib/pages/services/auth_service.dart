import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Save token and role locally
      await _storage.write(key: 'auth_token', value: data['token']);
      await _storage.write(key: 'role', value: data['role']);
      await _storage.write(key: 'name', value: data['name']);

      return data;
    } else {
      throw Exception('Invalid credentials');
    }
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

  static Future<void> logout() async {
    await _storage.deleteAll();
  }
}