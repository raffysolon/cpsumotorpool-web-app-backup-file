import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'package:cpsumotorpooladmin/services/device_service.dart';

/// Represents an actual GPS location received from the backend.
class GpsLocation {
  const GpsLocation({
    required this.id,
    required this.vehicleId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.satellites,
  });

  final int id;
  final int vehicleId;
  final double latitude;
  final double longitude;
  final int? satellites;
  final DateTime recordedAt;

  LatLng get position => LatLng(latitude, longitude);

  /// A location is considered recent if received within 30 seconds.
  bool get isRecent {
    final now = DateTime.now().toUtc();
    final recorded = recordedAt.toUtc();
    final age = now.difference(recorded);

    debugPrint(
      'GPS DEBUG: '
      'Record ID: $id | '
      'Now: $now | '
      'Recorded: $recorded | '
      'Age: ${age.inMilliseconds} ms',
    );

    return !age.isNegative && age <= const Duration(seconds: 30);
  }

  factory GpsLocation.fromJson(Map<String, dynamic> json) {
    final latitude = double.tryParse(json['latitude'].toString());
    final longitude = double.tryParse(json['longitude'].toString());

    if (latitude == null ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude == null ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Invalid GPS coordinates.');
    }

    return GpsLocation(
      id: (json['id'] as num).toInt(),
      vehicleId: (json['vehicle_id'] as num).toInt(),
      latitude: latitude,
      longitude: longitude,
      satellites: (json['satellites'] as num?)?.toInt(),
      recordedAt: DateTime.parse(json['recorded_at'].toString()),
    );
  }
}

/// Represents a vehicle assigned to a registered tracking device.
class TrackedVehicle {
  const TrackedVehicle({
    required this.vehicleId,
    required this.deviceId,
    required this.plate,
    required this.name,
  });

  final int vehicleId;
  final String deviceId;
  final String plate;
  final String name;

  factory TrackedVehicle.fromJson(Map<String, dynamic> json) {
    return TrackedVehicle(
      vehicleId: (json['vehicle_id'] as num).toInt(),
      deviceId: json['device_id'].toString(),
      plate: json['vehicle_plate']?.toString() ?? 'Unknown plate',
      name: json['vehicle_name']?.toString() ?? 'Unknown vehicle',
    );
  }
}

/// Handles GPS retrieval for the admin dashboard.
class GpsService {
  static const String baseUrl = AuthService.baseUrl;

  // === Cache settings ===

  static const Duration _registryCacheDuration = Duration(seconds: 60);

  static const Duration _locationCacheDuration = Duration(seconds: 5);

  // === Registered vehicle cache ===

  static List<TrackedVehicle>? _cachedVehicles;

  static DateTime? _lastRegistryRefresh;

  static Future<List<TrackedVehicle>>? _registryRequest;

  // === GPS location cache ===

  static final Map<int, GpsLocation?> _cachedLocations = {};

  static final Map<int, DateTime> _lastLocationRefresh = {};

  // Prevent duplicate simultaneous requests.
  static final Map<int, Future<GpsLocation?>> _locationRequests = {};

  // === Shared API cooldown ===

  static DateTime? _retryAfter;

  // Track the current authenticated session.
  static String? _sessionToken;

  // === Authentication ===

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      clearCache();

      throw Exception(
        'Authentication token not found. '
        'Please log in again.',
      );
    }

    // Clear cached data when the authenticated session changes.
    if (_sessionToken != token) {
      clearCache();
      _sessionToken = token;
    }

    return {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
  }

  // === Rate limit handling ===

  static bool get _isCoolingDown {
    final retryAfter = _retryAfter;

    return retryAfter != null && DateTime.now().isBefore(retryAfter);
  }

  static void _startCooldown({int seconds = 60}) {
    final nextRetry = DateTime.now().add(Duration(seconds: seconds));

    if (_retryAfter == null || nextRetry.isAfter(_retryAfter!)) {
      _retryAfter = nextRetry;
    }
  }

  static bool _isRateLimitError(Object error) {
    final message = error.toString().toLowerCase();

    return message.contains('too many requests') || message.contains('429');
  }

  static Exception _cooldownException() {
    return Exception(
      'API request limit reached. '
      'GPS tracking will retry automatically.',
    );
  }

  // === Retrieve registered vehicles ===

  static Future<List<TrackedVehicle>> getTrackedVehicles() async {
    await _headers();

    if (_isCoolingDown) {
      throw _cooldownException();
    }

    final now = DateTime.now();

    // Return cached vehicles if the cache is still valid.
    if (_cachedVehicles != null &&
        _lastRegistryRefresh != null &&
        now.difference(_lastRegistryRefresh!) < _registryCacheDuration) {
      return _cachedVehicles!;
    }

    // Reuse an existing request instead of sending another.
    if (_registryRequest != null) {
      return _registryRequest!;
    }

    final request = _fetchTrackedVehicles();

    _registryRequest = request;

    try {
      return await request;
    } finally {
      if (identical(_registryRequest, request)) {
        _registryRequest = null;
      }
    }
  }

  static Future<List<TrackedVehicle>> _fetchTrackedVehicles() async {
    final vehicles = <int, TrackedVehicle>{};

    int page = 1;
    int lastPage = 1;

    try {
      do {
        final response = await DeviceService.getDevices(
          page: page,
        ).timeout(const Duration(seconds: 30));

        if (response is! Map<String, dynamic>) {
          throw Exception('Invalid device registry response.');
        }

        final data = response['data'];

        if (data is! List) {
          throw Exception('Invalid device registry data.');
        }

        for (final item in data) {
          if (item is! Map<String, dynamic>) {
            continue;
          }

          if (item['vehicle_id'] == null) {
            continue;
          }

          final vehicle = TrackedVehicle.fromJson(item);

          // Avoid duplicate vehicle markers.
          vehicles.putIfAbsent(vehicle.vehicleId, () => vehicle);
        }

        lastPage = (response['last_page'] as num?)?.toInt() ?? 1;

        page++;
      } while (page <= lastPage);

      _cachedVehicles = vehicles.values.toList();

      _lastRegistryRefresh = DateTime.now();

      // Remove cached locations for unregistered vehicles.
      _cachedLocations.removeWhere((id, _) => !vehicles.containsKey(id));

      _lastLocationRefresh.removeWhere((id, _) => !vehicles.containsKey(id));

      return _cachedVehicles!;
    } catch (error) {
      if (_isRateLimitError(error)) {
        _startCooldown();

        throw _cooldownException();
      }

      rethrow;
    }
  }

  // === Retrieve latest GPS location ===

  static Future<GpsLocation?> getLatestLocation(int vehicleId) async {
    final headers = await _headers();

    if (_isCoolingDown) {
      throw _cooldownException();
    }

    final now = DateTime.now();

    final lastRefresh = _lastLocationRefresh[vehicleId];

    // Reuse recently retrieved GPS data.
    if (_cachedLocations.containsKey(vehicleId) &&
        lastRefresh != null &&
        now.difference(lastRefresh) < _locationCacheDuration) {
      return _cachedLocations[vehicleId];
    }

    // Reuse an existing request for the same vehicle.
    final existingRequest = _locationRequests[vehicleId];

    if (existingRequest != null) {
      return existingRequest;
    }

    final request = _fetchLatestLocation(vehicleId, headers);

    _locationRequests[vehicleId] = request;

    try {
      return await request;
    } finally {
      if (identical(_locationRequests[vehicleId], request)) {
        _locationRequests.remove(vehicleId);
      }
    }
  }

  static Future<GpsLocation?> _fetchLatestLocation(
    int vehicleId,
    Map<String, String> headers,
  ) async {
    final uri = Uri.parse('$baseUrl/gps/vehicles/$vehicleId/latest');

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid GPS location response.');
      }

      final location = GpsLocation.fromJson(data);

      // Save the latest successful GPS response.
      _cachedLocations[vehicleId] = location;

      _lastLocationRefresh[vehicleId] = DateTime.now();

      return location;
    }

    // Only the controller's explicit no-location response means empty data.
    if (response.statusCode == 404) {
      dynamic data;
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        // A proxy or missing route may return HTML instead of JSON.
      }

      if (data is Map<String, dynamic> &&
          data['message'] == 'No GPS location found.') {
        _cachedLocations[vehicleId] = null;
        _lastLocationRefresh[vehicleId] = DateTime.now();
        return null;
      }

      throw Exception('Unable to retrieve GPS location (404).');
    }

    if (response.statusCode == 401) {
      clearCache();

      throw Exception(
        'Your session has expired. '
        'Please log in again.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception('You do not have permission to view GPS locations.');
    }

    if (response.statusCode == 429) {
      // Respect the backend's Retry-After header.
      final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');

      _startCooldown(
        seconds: retryAfter != null && retryAfter > 60 ? retryAfter : 60,
      );

      throw _cooldownException();
    }

    throw Exception(
      'Unable to retrieve GPS location '
      '(${response.statusCode}).',
    );
  }

  // === Clear cached data ===

  static void clearCache() {
    _cachedVehicles = null;

    _lastRegistryRefresh = null;

    _registryRequest = null;

    _cachedLocations.clear();

    _lastLocationRefresh.clear();

    _locationRequests.clear();

    _retryAfter = null;

    _sessionToken = null;
  }
}
