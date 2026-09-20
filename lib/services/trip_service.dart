import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';

class TripService {
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

  static Future<dynamic> getMyTrips({String? status}) async {
    final uri = Uri.parse(
      status == null || status.isEmpty
          ? '$baseUrl/my-trips'
          : '$baseUrl/my-trips?status=$status',
    );

    final response = await http.get(uri, headers: await _headers());

    return _parseResponse(response);
  }

  static Future<dynamic> getAllTrips() async {
    debugPrint('TripService.getAllTrips(): GET $baseUrl/trips');
    final response = await http.get(
      Uri.parse('$baseUrl/trips'),
      headers: await _headers(),
    );

    debugPrint(
      'TripService.getAllTrips(): status=${response.statusCode} body=${response.body}',
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

  static Future<dynamic> startTrip(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trips/$id/start'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> endTrip(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trips/$id/end'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> startReturnTrip(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trips/$id/start-return'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> endReturnTrip(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trips/$id/end-return'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<http.Response> getTripTicket(int id) async {
    final headers = await _headers();
    headers['Accept'] = 'application/pdf';
    final response = await http.get(
      Uri.parse('$baseUrl/trips/$id/print'),
      headers: headers,
    ).timeout(const Duration(seconds: 150));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Request failed (${response.statusCode}): ${response.body}',
      );
    }

    final contentType = response.headers['content-type'] ?? '';
    final bufferStart = response.bodyBytes.sublist(
      0,
      math.min(4, response.bodyBytes.length),
    );

    final looksLikePdf =
        contentType.toLowerCase().contains('application/pdf') ||
        bufferStart.any((byte) => byte == 0x25 || byte == 0x50);

    if (response.bodyBytes.isEmpty || !looksLikePdf) {
      final preview = response.body.trim();
      final previewText = preview.isEmpty
          ? 'Empty response body'
          : preview.substring(0, preview.length > 160 ? 160 : preview.length);
      throw Exception(
        'The server did not return a valid PDF file. $previewText',
      );
    }

    return response;
  }

  static Future<dynamic> createTrip({
    required String origin,
    required String destination,
    required String purpose,
    required String scheduledDeparture,
    String? returnScheduledDeparture,
    required List<Map<String, String>> passengers,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trips'),
      headers: await _headers(),
      body: jsonEncode({
        'origin': origin,
        'destination': destination,
        'purpose': purpose,
        'scheduled_departure': scheduledDeparture,
        'return_scheduled_departure': returnScheduledDeparture,
        'passengers': passengers,
      }),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> createAdminTrip({
    required String origin,
    required String destination,
    required String purpose,
    required String scheduledDeparture,
    String? returnScheduledDeparture,
    required int driverId,
    required int vehicleId,
    required List<Map<String, String>> passengers,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trips/admin-create'),
      headers: await _headers(),
      body: jsonEncode({
        'origin': origin,
        'destination': destination,
        'purpose': purpose,
        'scheduled_departure': scheduledDeparture,
        'return_scheduled_departure': returnScheduledDeparture,
        'driver_id': driverId,
        'vehicle_id': vehicleId,
        'passengers': passengers,
      }),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> getAvailableDrivers({
    String? scheduledDeparture,
  }) async {
    final uri = scheduledDeparture == null || scheduledDeparture.isEmpty
        ? Uri.parse('$baseUrl/available-drivers')
        : Uri.parse(
            '$baseUrl/available-drivers?scheduled_departure=${Uri.encodeQueryComponent(scheduledDeparture)}',
          );

    final response = await http.get(uri, headers: await _headers());

    return _parseResponse(response);
  }

  static Future<dynamic> getAvailableVehicles({
    String? scheduledDeparture,
  }) async {
    final uri = scheduledDeparture == null || scheduledDeparture.isEmpty
        ? Uri.parse('$baseUrl/available-vehicles')
        : Uri.parse(
            '$baseUrl/available-vehicles?scheduled_departure=${Uri.encodeQueryComponent(scheduledDeparture)}',
          );

    final response = await http.get(uri, headers: await _headers());

    return _parseResponse(response);
  }
}
