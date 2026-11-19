import 'api_reads.dart';
import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'package:cpsumotorpooladmin/services/device_service.dart';

/// Authentication changes must also clear locations already displayed by a map.
class GpsAccessException implements Exception {
  const GpsAccessException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Represents an actual GPS location received from the backend.
class GpsLocation {
  const GpsLocation({
    required this.id,
    required this.vehicleId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.satellites,
    this.tripContextAvailable = false,
    this.trip,
  });

  final int id;
  final int vehicleId;
  final double latitude;
  final double longitude;
  final int? satellites;
  final DateTime recordedAt;
  final bool tripContextAvailable;
  final GpsTrip? trip;

  bool get isUnscheduled => tripContextAvailable && trip == null;

  LatLng get position => LatLng(latitude, longitude);

  /// Allow four 15-second upload intervals for LTE/polling delays.
  /// A small future tolerance accommodates clock skew without hiding bad dates.
  bool get isRecent => isRecentAt(DateTime.now());

  bool isRecentAt(DateTime now) {
    final age = now.toUtc().difference(recordedAt.toUtc());
    return age >= const Duration(seconds: -5) &&
        age <= const Duration(seconds: 60);
  }

  static DateTime _parseRecordedAt(String value) {
    final timestamp = value.trim();
    // Laravel/database timestamps without an offset follow the backend's UTC
    // convention. DateTime.parse otherwise interprets them in the viewer's zone.
    final hasOffset = RegExp(
      r'[Tt ].*(?:[zZ]|[+-]\d{2}(?::?\d{2})?)$',
    ).hasMatch(timestamp);
    return DateTime.parse(hasOffset ? timestamp : '${timestamp}Z').toUtc();
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
      recordedAt: _parseRecordedAt(json['recorded_at'].toString()),
      tripContextAvailable: json.containsKey('trip'),
      trip: json['trip'] is Map<String, dynamic>
          ? GpsTrip.fromJson(json['trip'] as Map<String, dynamic>)
          : null,
    );
  }
}

class GpsTrip {
  const GpsTrip({
    required this.id,
    required this.status,
    required this.scheduledDeparture,
    this.actualDeparture,
    this.lateMinutes,
    this.departureOverdue = false,
  });

  final int id;
  final String status;
  final DateTime scheduledDeparture;
  final DateTime? actualDeparture;
  final int? lateMinutes;
  final bool departureOverdue;

  factory GpsTrip.fromJson(Map<String, dynamic> json) => GpsTrip(
    id: (json['id'] as num).toInt(),
    status: json['status'].toString(),
    scheduledDeparture: DateTime.parse(json['scheduled_departure'].toString()),
    actualDeparture: json['actual_departure_at'] == null
        ? null
        : DateTime.parse(json['actual_departure_at'].toString()),
    lateMinutes: (json['late_minutes'] as num?)?.toInt(),
    departureOverdue: json['departure_overdue'] == true,
  );
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

  // Track the current authenticated session.
  static String? _sessionToken;
  static int _sessionGeneration = 0;

  static Future<void> _checkSession(int generation) async {
    final token = await AuthService.getToken();
    if (generation != _sessionGeneration) {
      throw const GpsAccessException('Session changed. Refresh GPS again.');
    }
    if (token == null || token.isEmpty || token != _sessionToken) {
      clearCache();
      throw const GpsAccessException('Session changed. Please log in again.');
    }
  }

  // === Authentication ===

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      clearCache();

      throw const GpsAccessException(
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

  // === Retrieve registered vehicles ===

  static Future<List<TrackedVehicle>> getTrackedVehicles() async {
    await _headers();

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

    final request = _fetchTrackedVehicles(_sessionGeneration);

    _registryRequest = request;

    try {
      return await request;
    } finally {
      if (identical(_registryRequest, request)) {
        _registryRequest = null;
      }
    }
  }

  static Future<List<TrackedVehicle>> _fetchTrackedVehicles(
    int generation,
  ) async {
    final vehicles = <int, TrackedVehicle>{};

    int page = 1;
    int lastPage = 1;

    try {
      do {
        final response = await DeviceService.getDevices(
          page: page,
        ).timeout(const Duration(seconds: 30));

        await _checkSession(generation);

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
      await _checkSession(generation);
      if (error.toString().contains('session has expired') ||
          error.toString().contains('permission')) {
        clearCache();
        throw const GpsAccessException(
          'GPS access denied. Please log in again.',
        );
      }
      rethrow;
    }
  }

  // === Retrieve latest GPS location ===

  static Future<GpsLocation?> getLatestLocation(int vehicleId) async {
    final headers = await _headers();

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

    final request = _fetchLatestLocation(
      vehicleId,
      headers,
      _sessionGeneration,
    );

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
    int generation,
  ) async {
    final uri = Uri.parse('$baseUrl/gps/vehicles/$vehicleId/latest');

    final response = await ApiReads.get(
      uri,
      headers: headers,
    ).timeout(const Duration(seconds: 30));

    await _checkSession(generation);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid GPS location response.');
      }

      final location = GpsLocation.fromJson(data);
      if (location.vehicleId != vehicleId) {
        throw const FormatException('GPS response belongs to another vehicle.');
      }

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

      throw const GpsAccessException(
        'Your session has expired. '
        'Please log in again.',
      );
    }

    if (response.statusCode == 403) {
      clearCache();
      throw const GpsAccessException(
        'You do not have permission to view GPS locations.',
      );
    }

    throw Exception(
      'Unable to retrieve GPS location '
      '(${response.statusCode}).',
    );
  }

  // === Clear cached data ===

  static void clearCache() {
    _sessionGeneration++;
    _cachedVehicles = null;

    _lastRegistryRefresh = null;

    _registryRequest = null;

    _cachedLocations.clear();

    _lastLocationRefresh.clear();

    _locationRequests.clear();

    _sessionToken = null;
  }
}
