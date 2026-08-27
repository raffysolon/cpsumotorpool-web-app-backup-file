import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';

class AssignmentService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found');
    }

    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>?> getMyAssignment() async {
    final response = await http.get(
      Uri.parse('$baseUrl/my-assignment'),
      headers: await _headers(),
    );

    if (response.statusCode == 404) return null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      'Request failed (${response.statusCode}): ${response.body}',
    );
  }
}
