// ignore_for_file: file_names

import 'package:cpsumotorpooladmin/widgets/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/device_service.dart';
import 'package:cpsumotorpooladmin/services/vehicle_service.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';
import 'package:cpsumotorpooladmin/widgets/skeleton_widgets_web.dart' as skeleton;

// === Device Registry Page - Manage GPS Tracker Devices ===
// Route: /devices
class DeviceRegistryPage extends StatefulWidget {
  const DeviceRegistryPage({super.key});

  @override
  State<DeviceRegistryPage> createState() => _DeviceRegistryPageState();
}

class _DeviceRegistryPageState extends State<DeviceRegistryPage> {
  final _devices = <_DeviceData>[];
  final _vehicles = <_VehicleData>[];
  bool _isLoading = true;

  // Pagination state
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalRecords = 0;
  final int _perPage = 20;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        DeviceService.getDevices(
          page: _currentPage,
          perPage: _perPage,
        ),
        VehicleService.getVehicles(perPage: 1000), // Get all vehicles for dropdown
      ]);

      if (!mounted) return;
      setState(() {
        _devices
          ..clear()
          ..addAll(_parseDevices(results[0]));
        _vehicles
          ..clear()
          ..addAll(_parseVehicles(results[1]));

        // Extract pagination metadata
        if (results[0] is Map) {
          final deviceData = results[0] as Map<String, dynamic>;
          _currentPage = deviceData['current_page'] ?? _currentPage;
          _lastPage = deviceData['last_page'] ?? 1;
          _totalRecords = deviceData['total'] ?? _devices.length;
        } else {
          _totalRecords = _devices.length;
          _lastPage = 1;
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        AppNotification.showMessage(
          'Failed to load devices: $e',
          isError: true,
        );
      }
    }
  }

  List<_DeviceData> _parseDevices(dynamic json) {
    if (json == null) return [];
    if (json is Map && json.containsKey('data')) {
      final data = json['data'];
      if (data is List) {
        return data.map((item) => _DeviceData.fromJson(item)).toList();
      }
    }
    if (json is List) {
      return json.map((item) => _DeviceData.fromJson(item)).toList();
    }
    return [];
  }

  List<_VehicleData> _parseVehicles(dynamic json) {
    if (json == null) return [];
    if (json is Map && json.containsKey('data')) {
      final data = json['data'];
      if (data is List) {
        return data.map((item) => _VehicleData.fromJson(item)).toList();
      }
    }
    if (json is List) {
      return json.map((item) => _VehicleData.fromJson(item)).toList();
    }
    return [];
  }

  Future<void> _showRegisterDialog() async {
    final deviceIdController = TextEditingController();
    int? selectedVehicleId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Register Device'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Device ID',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: deviceIdController,
                  decoration: const InputDecoration(
                    hintText: 'e.g., LORA32_ABC1234',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Assign to Vehicle',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedVehicleId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select vehicle',
                  ),
                  items: _vehicles.map((vehicle) {
                    return DropdownMenuItem<int>(
                      value: vehicle.id,
                      child: Text('${vehicle.plateNo} - ${vehicle.name}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedVehicleId = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final deviceId = deviceIdController.text.trim();
                if (deviceId.isEmpty) {
                  AppNotification.showMessage(
                    'Device ID is required',
                    isError: true,
                  );
                  return;
                }
                if (selectedVehicleId == null) {
                  AppNotification.showMessage(
                    'Please select a vehicle',
                    isError: true,
                  );
                  return;
                }

                try {
                  final vehicle = _vehicles.firstWhere(
                    (v) => v.id == selectedVehicleId,
                  );
                  await DeviceService.registerDevice(
                    deviceId: deviceId,
                    vehicleId: selectedVehicleId!,
                    vehiclePlate: vehicle.plateNo,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    AppNotification.showMessage(
                      'Device registered successfully',
                      isSuccess: true,
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppNotification.showMessage(
                      'Failed to register: $e',
                      isError: true,
                    );
                  }
                }
              },
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(_DeviceData device) async {
    int? selectedVehicleId = device.vehicleId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Device: ${device.deviceId}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reassign to Vehicle',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedVehicleId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select vehicle',
                  ),
                  items: _vehicles.map((vehicle) {
                    return DropdownMenuItem<int>(
                      value: vehicle.id,
                      child: Text('${vehicle.plateNo} - ${vehicle.name}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedVehicleId = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedVehicleId == null) {
                  AppNotification.showMessage(
                    'Please select a vehicle',
                    isError: true,
                  );
                  return;
                }

                try {
                  final vehicle = _vehicles.firstWhere(
                    (v) => v.id == selectedVehicleId,
                  );
                  await DeviceService.updateDevice(
                    device.deviceId,
                    vehicleId: selectedVehicleId!,
                    vehiclePlate: vehicle.plateNo,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    AppNotification.showMessage(
                      'Device updated successfully',
                      isSuccess: true,
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppNotification.showMessage(
                      'Failed to update: $e',
                      isError: true,
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDevice(_DeviceData device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to unregister device "${device.deviceId}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DeviceService.deleteDevice(device.deviceId);
        if (mounted) {
          AppNotification.showMessage(
            'Device unregistered',
            isSuccess: true,
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          AppNotification.showMessage(
            'Failed to delete: $e',
            isError: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/devices',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Registry',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage GPS Tracker Devices',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showRegisterDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Register Device'),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? _buildSkeletonLoader()
                : _devices.isEmpty
                    ? _buildEmptyState()
                    : _buildDeviceTable(),
          ),

          // Pagination
          if (!_isLoading && _devices.isNotEmpty) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          10,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: skeleton.SkeletonWidgetsWeb.box(
              width: double.infinity,
              height: 60,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices_other, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No devices registered yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Click "Register Device" to add your first GPS tracker',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Device ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Vehicle', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Plate Number', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Registered At', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Last Seen', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 100, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  // Table Rows
                  ..._devices.map((device) => _buildDeviceRow(device)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceRow(_DeviceData device) {
    final statusColor = device.isOnline ? Colors.green : Colors.grey;
    final statusText = device.isOnline ? 'Online' : 'Offline';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              device.deviceId,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              device.vehicleName ?? '-',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              device.vehiclePlate ?? '-',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              device.registeredAt ?? '-',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              device.lastSeen ?? 'Never',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditDialog(device),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => _deleteDevice(device),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${((_currentPage - 1) * _perPage) + 1} to '
            '${(_currentPage * _perPage) > _totalRecords ? _totalRecords : (_currentPage * _perPage)} '
            'of $_totalRecords devices',
            style: const TextStyle(fontSize: 14),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _loadData();
                      }
                    : null,
              ),
              Text('Page $_currentPage of $_lastPage'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _lastPage
                    ? () {
                        setState(() => _currentPage++);
                        _loadData();
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// === Data Models ===
class _DeviceData {
  final String deviceId;
  final int vehicleId;
  final String? vehicleName;
  final String? vehiclePlate;
  final String? registeredAt;
  final String? lastSeen;
  final bool isOnline;

  _DeviceData({
    required this.deviceId,
    required this.vehicleId,
    this.vehicleName,
    this.vehiclePlate,
    this.registeredAt,
    this.lastSeen,
    this.isOnline = false,
  });

  factory _DeviceData.fromJson(Map<String, dynamic> json) {
    return _DeviceData(
      deviceId: json['device_id']?.toString() ?? '',
      vehicleId: json['vehicle_id'] ?? 0,
      vehicleName: json['vehicle_name']?.toString(),
      vehiclePlate: json['vehicle_plate']?.toString(),
      registeredAt: json['registered_at']?.toString(),
      lastSeen: json['last_seen']?.toString(),
      isOnline: json['is_online'] == true || json['is_online'] == 1,
    );
  }
}

class _VehicleData {
  final int id;
  final String name;
  final String plateNo;

  _VehicleData({
    required this.id,
    required this.name,
    required this.plateNo,
  });

  factory _VehicleData.fromJson(Map<String, dynamic> json) {
    return _VehicleData(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      plateNo: json['plate_no']?.toString() ?? '',
    );
  }
}
