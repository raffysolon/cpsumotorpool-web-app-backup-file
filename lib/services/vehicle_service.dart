import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';

class VehicleService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

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

  static Future<dynamic> getVehicles() async {
    final response = await http.get(
      Uri.parse('$baseUrl/vehicles'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> createVehicle({
    required String name,
    required String plateNo,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/vehicles'),
      headers: await _headers(),
      body: jsonEncode({
        'name': name,
        'plate_no': plateNo,
      }),
    );

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
