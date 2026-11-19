import 'dart:convert';
import '../pages/services/auth_service.dart';
import 'api_reads.dart';
import 'gps_service.dart';

class GpsSyncService {
  static Future<Map<String, dynamic>> getLogs(int page) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw const GpsAccessException('Please log in again.');
    }
    final response = await ApiReads.get(
      Uri.parse('${AuthService.baseUrl}/gps/sync-logs?page=$page'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (await AuthService.getToken() != token ||
        response.statusCode == 401 ||
        response.statusCode == 403) {
      throw const GpsAccessException('GPS access denied. Please log in again.');
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load GPS sync records (${response.statusCode}).',
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['data'] is! List) {
      throw const FormatException('Invalid GPS sync response.');
    }
    return body;
  }
}
