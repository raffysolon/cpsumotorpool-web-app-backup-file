import 'api_reads.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'api_config.dart';

class DriverService {
  static String get baseUrl => ApiConfig.apiBaseUrl;

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

    // Handle specific error codes with user-friendly messages
    if (response.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }

    if (response.statusCode == 403) {
      throw Exception('You do not have permission to perform this action.');
    }

    if (response.statusCode == 429) {
      throw Exception('Too many requests. Please wait a moment and try again.');
    }

    throw Exception(
      'Request failed (${response.statusCode}): ${response.body}',
    );
  }

  static Future<dynamic> getDrivers({
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final uri = ApiConfig.apiUri('drivers', queryParameters: queryParams);

    final response = await ApiReads.get(uri, headers: await _headers());

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
      ApiConfig.apiUri('drivers'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );

    debugPrint(
      'DriverService.createDriver(): status=${response.statusCode} body=${response.body}',
    );
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
      ApiConfig.apiUri('drivers/$id'),
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
      ApiConfig.apiUri('drivers/$id'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> resetPassword(int id) async {
    final response = await http.post(
      ApiConfig.apiUri('drivers/$id/reset-password'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }
}
