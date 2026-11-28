import 'dart:convert';
import '../pages/services/auth_service.dart';
import 'api_reads.dart';
import 'gps_service.dart';
import 'api_config.dart';
import 'coordinator_assignment_service.dart';
import 'vehicle_service.dart';
import 'device_service.dart';

class GpsSyncService {
  static String _name(dynamic value) {
    if (value is! Map) return '';
    final direct = value['name'] ?? value['full_name'] ?? value['title'];
    if (direct != null && '$direct'.trim().isNotEmpty) return '$direct'.trim();
    return '${value['first_name'] ?? ''} ${value['last_name'] ?? ''}'.trim();
  }

  static String? _vehicleId(Map value) {
    final nested = value['vehicle'];
    final id = value['vehicle_id'] ?? (nested is Map ? nested['id'] : null);
    return id == null ? null : int.tryParse('$id')?.toString();
  }

  static Future<Map<String, dynamic>> getLogs(
    int page, {
    bool summary = false,
    int? vehicleId,
    int? deviceRegistryId,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw const GpsAccessException('Please log in again.');
    }
    final response = await ApiReads.get(
      ApiConfig.apiUri(
        'gps/sync-logs',
        queryParameters: {
          'page': '$page',
          if (summary) 'summary': '1',
          if (vehicleId != null) 'vehicle_id': '$vehicleId',
          if (deviceRegistryId != null)
            'device_registry_id': '$deviceRegistryId',
        },
      ),
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
    if ((body['data'] as List).isEmpty) return body;
    // Current registry labels are separate from historical GPS capture data.
    final assignmentsResult =
        await CoordinatorAssignmentService.getAssignments();
    final assignmentRows = assignmentsResult is List
        ? assignmentsResult
        : assignmentsResult is Map
        ? assignmentsResult['data']
        : null;
    if (assignmentRows is! List) {
      throw const FormatException(
        'Unable to read vehicle assignments. Please retry.',
      );
    }
    final assignments = assignmentRows.whereType<Map>().toList();
    final vehicles = <String, Map>{};
    var vehiclePage = 1;
    var lastVehiclePage = 1;
    do {
      final result = await VehicleService.getVehicles(
        page: vehiclePage,
        perPage: 100,
      );
      final rows = result is Map ? result['data'] : result;
      if (rows is List) {
        for (final vehicle in rows.whereType<Map>()) {
          vehicles['${vehicle['id']}'] = vehicle;
        }
      }
      lastVehiclePage = result is Map
          ? (result['last_page'] as num?)?.toInt() ?? 1
          : 1;
      vehiclePage++;
    } while (vehiclePage <= lastVehiclePage);
    final devices = <String, Map>{};
    final needsRegistry = (body['data'] as List).whereType<Map>().any(
      (r) => r['device_registry_id'] != null || r['device'] is Map,
    );
    if (needsRegistry) {
      var devicePage = 1;
      var lastDevicePage = 1;
      do {
        final result = await DeviceService.getDevices(page: devicePage);
        final rows = result is Map ? result['data'] : result;
        if (rows is! List) {
          throw const FormatException(
            'Unable to read Device Registry. Please retry.',
          );
        }
        for (final device in rows.whereType<Map>()) {
          if (device['id'] != null) devices['id:${device['id']}'] = device;
          if (device['device_id'] != null)
            devices['name:${device['device_id']}'] = device;
        }
        lastDevicePage = result is Map
            ? (result['last_page'] as num?)?.toInt() ?? 1
            : 1;
        devicePage++;
      } while (devicePage <= lastDevicePage);
    }
    if (await AuthService.getToken() != token) {
      throw const GpsAccessException('Please log in again.');
    }
    body['data'] = (body['data'] as List).whereType<Map>().map((row) {
      final record = Map<String, dynamic>.from(row);
      final linked = row['device'] is Map ? row['device'] as Map : const {};
      final registryId = row['device_registry_id'] ?? linked['id'];
      final hasDevice = registryId != null || linked['device_id'] != null;
      final currentDevice = registryId != null
          ? devices['id:$registryId']
          : devices['name:${linked['device_id']}'];
      final vehicleId = hasDevice
          ? currentDevice == null
                ? null
                : _vehicleId(currentDevice)
          : _vehicleId(row);
      final matching = assignments
          .where((a) => vehicleId != null && _vehicleId(a) == vehicleId)
          .toList();
      final assignedVehicles = matching
          .map((a) => a['vehicle'])
          .whereType<Map>();
      record['vehicle'] = assignedVehicles.isNotEmpty
          ? assignedVehicles.first
          : vehicles[vehicleId] ??
                currentDevice?['vehicle'] ??
                (hasDevice ? null : row['vehicle']);
      // Keep the original vehicle_id for the historical capture; only the
      // overview follows the device's current registry assignment.
      record['overview_vehicle_id'] = vehicleId;
      record['recorded_vehicle'] = vehicles[_vehicleId(row)];
      record['has_assignment'] = matching.isNotEmpty;
      record['campus_name'] = matching
          .map((a) => '${a['campus_name'] ?? a['campus'] ?? ''}'.trim())
          .where((v) => v.isNotEmpty)
          .toSet()
          .join(', ');
      record['driver_name'] = matching
          .map((a) => _name(a['driver']))
          .where((v) => v.isNotEmpty)
          .toSet()
          .join(', ');
      record['coordinator_name'] = matching
          .map((a) => '${a['coordinator_name'] ?? ''}'.trim())
          .where((v) => v.isNotEmpty)
          .toSet()
          .join(', ');
      return record;
    }).toList();
    return body;
  }
}
