import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';

class VehicleService {
  static const String baseUrl = 'https://cpsumotorpool-backend.onrender.com/api';

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

  static Future<dynamic> getVehicles({
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

    final uri = Uri.parse('$baseUrl/vehicles').replace(queryParameters: queryParams);
    
    final response = await http.get(uri, headers: await _headers());

    return _parseResponse(response);
  }

  static Future<dynamic> createVehicle({
    required String name,
    required String plateNo,
  }) async {
    final payload = {
      'name': name,
      'plate_no': plateNo,
    };

    debugPrint('VehicleService.createVehicle(): POST $baseUrl/vehicles');
    debugPrint('VehicleService.createVehicle(): payload=$payload');

    final response = await http.post(
      Uri.parse('$baseUrl/vehicles'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );

    debugPrint('VehicleService.createVehicle(): status=${response.statusCode} body=${response.body}');
    return _parseResponse(response);
  }

  static Future<dynamic> updateVehicle(
    int id, {
    required String name,
    required String plateNo,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/vehicles/$id'),
      headers: await _headers(),
      body: jsonEncode({
        'name': name,
        'plate_no': plateNo,
      }),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> deleteVehicle(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/vehicles/$id'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }
}
