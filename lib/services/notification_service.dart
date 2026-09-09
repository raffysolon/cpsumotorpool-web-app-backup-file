import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';

class NotificationService {
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

  static Future<dynamic> _parseResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    throw Exception(
      'Request failed (${response.statusCode}): ${response.body}',
    );
  }

  static Future<dynamic> getNotifications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> getUnreadCount() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications/unread-count'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> markAsRead(int id) async {
    final response = await http.put(
      Uri.parse('$baseUrl/notifications/$id/read'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }
}
