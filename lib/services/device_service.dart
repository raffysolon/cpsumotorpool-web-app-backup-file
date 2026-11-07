import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';

class DeviceService {
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

  /// Get all registered devices with pagination
  static Future<dynamic> getDevices({
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

    final uri = Uri.parse('$baseUrl/devices').replace(queryParameters: queryParams);
    
    final response = await http.get(uri, headers: await _headers());

    return _parseResponse(response);
  }

  /// Register a new device to a vehicle
  static Future<dynamic> registerDevice({
    required String deviceId,
    required int vehicleId,
    String? vehiclePlate,
  }) async {
    final payload = {
      'device_id': deviceId,
      'vehicle_id': vehicleId,
      if (vehiclePlate != null) 'vehicle_plate': vehiclePlate,
    };

    debugPrint('DeviceService.registerDevice(): POST $baseUrl/devices/register');
    debugPrint('DeviceService.registerDevice(): payload=$payload');

    final response = await http.post(
      Uri.parse('$baseUrl/devices/register'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );

    debugPrint('DeviceService.registerDevice(): status=${response.statusCode} body=${response.body}');
    return _parseResponse(response);
  }

  /// Update device assignment to a different vehicle
  static Future<dynamic> updateDevice(
    String deviceId, {
    required int vehicleId,
    String? vehiclePlate,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/devices/$deviceId'),
      headers: await _headers(),
      body: jsonEncode({
        'vehicle_id': vehicleId,
        if (vehiclePlate != null) 'vehicle_plate': vehiclePlate,
      }),
    );

    return _parseResponse(response);
  }

  /// Delete/unregister a device
  static Future<dynamic> deleteDevice(String deviceId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/devices/$deviceId'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  /// Get devices by vehicle ID
  static Future<dynamic> getDevicesByVehicle(int vehicleId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/devices/vehicle/$vehicleId'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  /// Get device details including last location
  static Future<dynamic> getDeviceDetails(String deviceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/devices/$deviceId'),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }
}
