import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';

class DriverService {
  static const String baseUrl = 'https://cpsu-motorpool-backend.onrender.com/api';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found');
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static dynamic _parseResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    throw Exception(
      'Request failed (${response.statusCode}): ${response.body}',
    );
  }

  static Future<dynamic> getDrivers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/drivers'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> createDriver({
    required String name,
    required String email,
    required String contactNumber,
    required String licenseNumber,
    String? password,
  }) async {
    final payload = {
      'name': name,
      'email': email,
      'contact_number': contactNumber,
      'license_number': licenseNumber,
      if (password != null && password.isNotEmpty) 'password': password,
    };

    debugPrint('DriverService.createDriver(): POST $baseUrl/drivers');
    debugPrint('DriverService.createDriver(): payload=$payload');

    final response = await http.post(
      Uri.parse('$baseUrl/drivers'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );

    debugPrint('DriverService.createDriver(): status=${response.statusCode} body=${response.body}');
    return _parseResponse(response);
  }

  static Future<dynamic> updateDriver(
    int id, {
    required String name,
    required String email,
    required String contactNumber,
    required String licenseNumber,
    String? password,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/drivers/$id'),
      headers: await _headers(),
      body: jsonEncode({
        'name': name,
        'email': email,
        'contact_number': contactNumber,
        'license_number': licenseNumber,
        if (password != null && password.isNotEmpty) 'password': password,
      }),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> deleteDriver(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/drivers/$id'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> resetPassword(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/drivers/$id/reset-password'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }
}
