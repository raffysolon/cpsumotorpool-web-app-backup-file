import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';

class CoordinatorAssignmentService {
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

  static Future<dynamic> _parseResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    throw Exception(
      'Request failed (${response.statusCode}): ${response.body}',
    );
  }

  static Future<dynamic> getAssignments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/coordinator-assignments'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> createAssignment({
    required String campusName,
    required String coordinatorName,
    required int driverId,
    required int vehicleId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/coordinator-assignments'),
      headers: await _headers(),
      body: jsonEncode({
        'campus_name': campusName,
        'coordinator_name': coordinatorName,
        'driver_id': driverId,
        'vehicle_id': vehicleId,
      }),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> updateAssignment(
    int id, {
    required String campusName,
    required String coordinatorName,
    required int driverId,
    required int vehicleId,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/coordinator-assignments/$id'),
      headers: await _headers(),
      body: jsonEncode({
        'campus_name': campusName,
        'coordinator_name': coordinatorName,
        'driver_id': driverId,
        'vehicle_id': vehicleId,
      }),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> deleteAssignment(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/coordinator-assignments/$id'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }
}
