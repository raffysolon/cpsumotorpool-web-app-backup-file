import 'api_reads.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'api_config.dart';

class DestinationPinException implements Exception {
  const DestinationPinException(this.message);
  final String message;
}

class TripRequestException implements Exception {
  const TripRequestException(this.message);
  final String message;
}

class TripService {
  static String get baseUrl => ApiConfig.apiBaseUrl;

  static Future<Map<String, dynamic>> getTripActivity(int tripId) async {
    final response = await ApiReads.get(
      ApiConfig.apiUri('trips/$tripId/activity'),
      headers: await _headers(),
    );
    return await _parseResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getTripEta(int tripId) async {
    final response = await ApiReads.get(
      ApiConfig.apiUri('trips/$tripId/eta'),
      headers: await _headers(),
    );
    return await _parseResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getRecordedRoute(int tripId) async {
    final response = await ApiReads.get(
      ApiConfig.apiUri('trips/$tripId/recorded-route'),
      headers: await _headers(),
    );
    return await _parseResponse(response) as Map<String, dynamic>;
  }

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

  static Future<List<Map<String, dynamic>>> getMyTrips({String? status}) async {
    final uri = ApiConfig.apiUri(
      'my-trips',
      queryParameters: status == null || status.isEmpty
          ? null
          : {'status': status},
    );

    debugPrint('TripService.getMyTrips(): GET $uri');
    final response = await ApiReads.get(uri, headers: await _headers());
    debugPrint('TripService.getMyTrips(): status=${response.statusCode}');
    debugPrint('TripService.getMyTrips(): body=${response.body}');

    final result = await _parseResponse(response);
    final records = result is List
        ? result
        : result is Map && result['data'] is List
        ? result['data'] as List
        : throw const FormatException('Unexpected trips response format.');

    debugPrint('TripService.getMyTrips(): Found ${records.length} trips');
    return records
        .whereType<Map>()
        .map((trip) => Map<String, dynamic>.from(trip))
        .toList();
  }

  static Future<dynamic> getAllTrips({
    String? search,
    String? status,
    String? dateFrom,
    String? dateTo,
    int? driverId,
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
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      queryParams['date_from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      queryParams['date_to'] = dateTo;
    }
    if (driverId != null) {
      queryParams['driver_id'] = driverId.toString();
    }

    final uri = ApiConfig.apiUri('trips', queryParameters: queryParams);
    debugPrint('TripService.getAllTrips(): GET $uri');

    final response = await ApiReads.get(uri, headers: await _headers());

    debugPrint(
      'TripService.getAllTrips(): status=${response.statusCode} body=${response.body}',
    );
    return _parseResponse(response);
  }

  static Future<List<Map<String, dynamic>>> getSavedDestinations() async {
    final response = await http.get(
      ApiConfig.apiUri('saved-destinations'),
      headers: await _headers(),
    );
    final data = await _parseResponse(response);
    return (data as List).cast<Map<String, dynamic>>();
  }

  static Future<void> saveDestination(
    String name,
    double latitude,
    double longitude, {
    int? id,
  }) async {
    final uri = ApiConfig.apiUri(
      id == null ? 'saved-destinations' : 'saved-destinations/$id',
    );
    final headers = await _headers();
    final body = jsonEncode({
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
    });
    final response = id == null
        ? await http.post(uri, headers: headers, body: body)
        : await http.put(uri, headers: headers, body: body);
    _checkPinSave(response);
  }

  static Future<void> setDestinationPin(
    int id,
    double latitude,
    double longitude,
  ) async {
    final response = await http.put(
      ApiConfig.apiUri('trips/$id/destination-pin'),
      headers: await _headers(),
      body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
    );
    _checkPinSave(response);
  }

  static void _checkPinSave(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw DestinationPinException(switch (response.statusCode) {
      401 => 'Your session has expired. Log in again.',
      403 => 'Only admins can save destination pins.',
      404 || 405 =>
        'The pin save endpoint or record was not found. Check that the latest backend is deployed.',
      422 =>
        'Check the coordinates and use a unique name for a saved destination.',
      429 => 'Too many requests. Wait a moment and try again.',
      _ =>
        'Could not save the pin (HTTP ${response.statusCode}). Please try again.',
    });
  }

  static Future<dynamic> approveTrip(int id) async {
    final response = await http.put(
      ApiConfig.apiUri('trips/$id/approve'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> denyTrip(int id) async {
    final response = await http.put(
      ApiConfig.apiUri('trips/$id/deny'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> startTrip(int id) async {
    final response = await http.post(
      ApiConfig.apiUri('trips/$id/start'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> endTrip(int id) async {
    final response = await http.post(
      ApiConfig.apiUri('trips/$id/end'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> startReturnTrip(int id) async {
    final response = await http.post(
      ApiConfig.apiUri('trips/$id/start-return'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> endReturnTrip(int id) async {
    final response = await http.post(
      ApiConfig.apiUri('trips/$id/end-return'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<http.Response> getTripTicket(int id) async {
    final headers = await _headers();
    headers['Accept'] = 'application/pdf';
    final response = await ApiReads.get(
      ApiConfig.apiUri('trips/$id/print'),
      headers: headers,
      timeout: const Duration(seconds: 150),
    );

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
    String? scheduledEndAt,
    required List<Map<String, String>> passengers,
  }) async {
    final response = await http.post(
      ApiConfig.apiUri('trips'),
      headers: await _headers(),
      body: jsonEncode({
        'origin': origin,
        'destination': destination,
        'purpose': purpose,
        'scheduled_departure': scheduledDeparture,
        'return_scheduled_departure': returnScheduledDeparture,
        'scheduled_end_at': scheduledEndAt,
        'passengers': passengers,
      }),
    );

    if (response.statusCode == 422) {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] is String) {
        throw TripRequestException(body['message'] as String);
      }
    }
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
      ApiConfig.apiUri('trips/admin-create'),
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
    final uri = ApiConfig.apiUri(
      'available-drivers',
      queryParameters: scheduledDeparture == null || scheduledDeparture.isEmpty
          ? null
          : {'scheduled_departure': scheduledDeparture},
    );

    final response = await ApiReads.get(uri, headers: await _headers());

    return _parseResponse(response);
  }

  static Future<dynamic> getAvailableVehicles({
    String? scheduledDeparture,
  }) async {
    final uri = ApiConfig.apiUri(
      'available-vehicles',
      queryParameters: scheduledDeparture == null || scheduledDeparture.isEmpty
          ? null
          : {'scheduled_departure': scheduledDeparture},
    );

    final response = await ApiReads.get(uri, headers: await _headers());

    return _parseResponse(response);
  }
}
