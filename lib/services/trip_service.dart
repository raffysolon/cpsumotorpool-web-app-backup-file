import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';

class TripService {
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

  static Future<dynamic> getMyTrips() async {
    final response = await http.get(
      Uri.parse('$baseUrl/my-trips'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> getAllTrips() async {
    final response = await http.get(
      Uri.parse('$baseUrl/trips'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> approveTrip(int id) async {
    final response = await http.put(
      Uri.parse('$baseUrl/trips/$id/approve'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> denyTrip(int id) async {
    final response = await http.put(
      Uri.parse('$baseUrl/trips/$id/deny'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<http.Response> getTripTicket(int id) async {
    // TODO: Add a matching Laravel PDF route for this endpoint.
    final response = await http.get(
      Uri.parse('$baseUrl/trips/$id/print'),
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Request failed (${response.statusCode}): ${response.body}',
      );
    }

    return response;
  }

  static Future<dynamic> createTrip(
    String origin,
    String destination,
    String purpose,
    String scheduledDeparture,
    List<Map<String, String>> passengers,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trips'),
      headers: await _headers(),
      body: jsonEncode({
        'origin': origin,
        'destination': destination,
        'purpose': purpose,
        'scheduled_departure': scheduledDeparture,
        'passengers': passengers,
      }),
    );

    return _parseResponse(response);
  }
}