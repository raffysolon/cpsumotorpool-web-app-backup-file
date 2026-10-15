import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';

class NotificationService {
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

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    debugPrint('NotificationService.getNotifications(): GET $baseUrl/notifications');
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: await _headers(),
    );

    debugPrint('NotificationService.getNotifications(): status=${response.statusCode}');
    debugPrint('NotificationService.getNotifications(): body=${response.body}');
    
    final result = await _parseResponse(response);
    final records = result is List
        ? result
        : result is Map && result['data'] is List
        ? result['data'] as List
        : throw const FormatException(
            'Unexpected notifications response format.',
          );

    debugPrint('NotificationService.getNotifications(): Found ${records.length} notifications');
    return records
        .whereType<Map>()
        .map((notification) => Map<String, dynamic>.from(notification))
        .toList();
  }

  static Future<dynamic> getUnreadCount() async {
    debugPrint('NotificationService.getUnreadCount(): GET $baseUrl/notifications/unread-count');
    final response = await http.get(
      Uri.parse('$baseUrl/notifications/unread-count'),
      headers: await _headers(),
    );

    debugPrint('NotificationService.getUnreadCount(): status=${response.statusCode}');
    debugPrint('NotificationService.getUnreadCount(): body=${response.body}');
    
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
