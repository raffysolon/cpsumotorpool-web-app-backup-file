import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'package:cpsumotorpooladmin/services/coordinator_assignment_service.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

// ═══════════════════════════════════════════════════════════════
// COORDINATOR ASSIGNMENTS PAGE
// Manage Driver and Vehicle assignments to Campus Coordinators
// Route: /coordinator-assignments
// ═══════════════════════════════════════════════════════════════

// ─── Page Wrapper ───
class CoordinatorAssignments extends StatelessWidget {
  const CoordinatorAssignments({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/coordinator-assignments',
      child: const _CoordinatorAssignmentsContent(),
    );
  }
}

// ─── Data Model ───
class _CoordinatorAssignment {
  final int id;
  final String campus;
  final String coordinatorName;
  final int driverId;
  final String driverName;
  final int vehicleId;
  final String vehicleName;

  const _CoordinatorAssignment({
    required this.id,
    required this.campus,
    required this.coordinatorName,
    required this.driverId,
    required this.driverName,
    required this.vehicleId,
    required this.vehicleName,
  });
}

class _AssignmentOption {
  final int id;
  final String name;

  const _AssignmentOption({required this.id, required this.name});
}

// ─── Color Scheme ───
abstract class AppColors {
  static const Color navy = Color(0xFF19332A);
  static const Color primary = Color(0xFF0B8F5A);
  static const Color mutedDark = Color(0xFF71827B);
  static const Color border = Color(0xFFDCE9E2);
  static const Color background = Color(0xFFF7FAF8);
}

// ─── Main Content Layout ───
class _CoordinatorAssignmentsContent extends StatefulWidget {
  const _CoordinatorAssignmentsContent();

  @override
  State<_CoordinatorAssignmentsContent> createState() =>
      _CoordinatorAssignmentsContentState();
}

class _CoordinatorAssignmentsContentState
    extends State<_CoordinatorAssignmentsContent> {
  late List<_CoordinatorAssignment> _displayedAssignments;
  List<_AssignmentOption> _drivers = const [];
  List<_AssignmentOption> _vehicles = const [];
  bool _isLoading = true;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _displayedAssignments = [];
    AdminNotificationsController.instance.refresh();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        CoordinatorAssignmentService.getAssignments(),
        _fetchOptions('drivers'),
        _fetchOptions('vehicles'),
      ]);

      if (!mounted) return;
      setState(() {
        _displayedAssignments = _parseAssignments(results[0]);
        _drivers = results[1] as List<_AssignmentOption>;
        _vehicles = results[2] as List<_AssignmentOption>;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showNotification('Unable to load assignments: $error', isError: true);
    }
  }

  Future<List<_AssignmentOption>> _fetchOptions(String resource) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found');
    }

    final availableResource = resource == 'drivers'
        ? 'available-drivers'
        : 'available-vehicles';
    final response = await http.get(
      Uri.parse('http://127.0.0.1:8000/api/$availableResource'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$resource request failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final records = decoded is List
        ? decoded
        : decoded is Map<String, dynamic> && decoded['data'] is List
            ? decoded['data'] as List
            : const [];

    return records
        .whereType<Map<String, dynamic>>()
        .map((record) => _AssignmentOption(
              id: _toInt(record['id']),
              name: _displayName(record),
            ))
        .where((option) => option.id > 0 && option.name.isNotEmpty)
        .toList();
  }

  List<_CoordinatorAssignment> _parseAssignments(dynamic response) {
    final records = response is List
        ? response
        : response is Map<String, dynamic> && response['data'] is List
            ? response['data'] as List
            : const [];

    return records.whereType<Map<String, dynamic>>().map((record) {
      final driver = record['driver'] is Map<String, dynamic>
          ? record['driver'] as Map<String, dynamic>
          : null;
      final vehicle = record['vehicle'] is Map<String, dynamic>
          ? record['vehicle'] as Map<String, dynamic>
          : null;
      return _CoordinatorAssignment(
        id: _toInt(record['id']),
        campus: _toString(record['campus_name'] ?? record['campus']),
        coordinatorName: _toString(record['coordinator_name']),
        driverId: _toInt(record['driver_id'] ?? driver?['id']),
        driverName: _displayName(driver ?? record, fallback: 'Unassigned'),
        vehicleId: _toInt(record['vehicle_id'] ?? vehicle?['id']),
        vehicleName: _displayName(vehicle ?? record, fallback: 'Unassigned'),
      );
    }).toList();
  }

  static int _toInt(dynamic value) => int.tryParse('$value') ?? 0;

  static String _toString(dynamic value) => value?.toString() ?? '';

  static String _displayName(
    Map<String, dynamic> record, {
    String fallback = '',
  }) {
    final directName = record['name'] ?? record['full_name'] ?? record['title'];
    if (directName != null && directName.toString().trim().isNotEmpty) {
      return directName.toString();
    }

    final firstName = record['first_name']?.toString() ?? '';
    final lastName = record['last_name']?.toString() ?? '';
    final combined = '$firstName $lastName'.trim();
    return combined.isEmpty ? fallback : combined;
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopBar(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildTable(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Top Bar ───
  Widget _buildTopBar(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      borderRadius: 0,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Campus Administrator Assignments',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Province of Negros Occidental — Motorpool Division',
                style: TextStyle(fontSize: 13, color: AppColors.mutedDark),
              ),
            ],
          ),
          const Spacer(),
          ValueListenableBuilder<int>(
            valueListenable: AdminNotificationsController.instance.unreadCount,
            builder: (context, count, _) {
              return AdminNotificationBell(
                count: count,
                onTap: () => AdminNotificationsController.instance.showNotificationsDialog(context),
              );
            },
          ),
          const SizedBox(width: 10),
          // Profile avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  // ─── Header with Add Button ───
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Active Assignments (${_displayedAssignments.length})',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showAssignmentDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Assignment'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Table Container ───
  Widget _buildTable(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: 180,
        child: GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 18,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 960 ? 960.0 : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  _buildTableHeader(),
                  const Divider(height: 1, color: AppColors.border),
                  ..._displayedAssignments.asMap().entries.map((entry) {
                    final i = entry.key;
                    final assignment = entry.value;
                    return Column(
                      children: [
                        _buildTableRow(context, assignment),
                        if (i < _displayedAssignments.length - 1)
                          const Divider(height: 1, color: AppColors.border),
                      ],
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Table Header ───
  Widget _buildTableHeader() {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.mutedDark,
      letterSpacing: 0.8,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: const [
          Expanded(flex: 4, child: Text('CAMPUS / ADMINISTRATOR', style: style)),
          Expanded(flex: 3, child: Text('ASSIGNED DRIVER', style: style)),
          Expanded(flex: 4, child: Text('ASSIGNED VEHICLE', style: style)),
          SizedBox(width: 120),
        ],
      ),
    );
  }

  // ─── Table Row ───
  Widget _buildTableRow(BuildContext context, _CoordinatorAssignment assignment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Campus / Coordinator
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.campus,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  assignment.coordinatorName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedDark,
                  ),
                ),
              ],
            ),
          ),
          // Driver
          Expanded(
            flex: 3,
            child: Text(
              assignment.driverName,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.navy,
              ),
            ),
          ),
          // Vehicle
          Expanded(
            flex: 4,
            child: Text(
              assignment.vehicleName,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.navy,
              ),
            ),
          ),
          // Actions
          SizedBox(
            width: 120,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Edit assignment',
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                  onPressed: () => _showAssignmentDialog(context, assignment),
                ),
                IconButton(
                  tooltip: 'Delete assignment',
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _confirmDelete(assignment),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Show Assignment Dialog (Add/Edit) ───
  void _showAssignmentDialog(
    BuildContext context, [
    _CoordinatorAssignment? assignment,
  ]) {
    showDialog(
      context: context,
      builder: (dialogContext) => _AssignmentDialog(
        assignment: assignment,
        drivers: [
          ..._drivers,
          if (assignment != null &&
              !_drivers.any((driver) => driver.id == assignment.driverId))
            _AssignmentOption(
              id: assignment.driverId,
              name: assignment.driverName,
            ),
        ],
        vehicles: [
          ..._vehicles,
          if (assignment != null &&
              !_vehicles.any((vehicle) => vehicle.id == assignment.vehicleId))
            _AssignmentOption(
              id: assignment.vehicleId,
              name: assignment.vehicleName,
            ),
        ],
        onSave: (campus, coordinatorName, driverId, vehicleId) async {
          try {
            if (assignment != null) {
              await CoordinatorAssignmentService.updateAssignment(
                assignment.id,
                campusName: campus,
                coordinatorName: coordinatorName,
                driverId: driverId,
                vehicleId: vehicleId,
              );
            } else {
              await CoordinatorAssignmentService.createAssignment(
                campusName: campus,
                coordinatorName: coordinatorName,
                driverId: driverId,
                vehicleId: vehicleId,
              );
            }

            if (!mounted || !dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            await _loadData();
            _showNotification(
              assignment != null
                  ? 'Assignment updated successfully'
                  : 'Assignment added successfully',
            );
          } catch (error) {
            if (mounted) {
              _showNotification('Unable to save assignment: $error', isError: true);
            }
          }
        },
      ),
    );
  }

  // ─── Confirm Delete ───
  void _confirmDelete(_CoordinatorAssignment assignment) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: Text(
          'Are you sure you want to remove ${assignment.campus}\'s assignment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await CoordinatorAssignmentService.deleteAssignment(assignment.id);
                if (!mounted || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                await _loadData();
                _showNotification('Assignment deleted');
              } catch (error) {
                if (mounted) {
                  _showNotification(
                    'Unable to delete assignment: $error',
                    isError: true,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showNotification(String message, {bool isError = false}) {
    _notificationTimer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}

// ─── Assignment Dialog (Add/Edit Form) ───
class _AssignmentDialog extends StatefulWidget {
  final _CoordinatorAssignment? assignment;
  final List<_AssignmentOption> drivers;
  final List<_AssignmentOption> vehicles;
  final Future<void> Function(
    String campus,
    String coordinatorName,
    int driverId,
    int vehicleId,
  ) onSave;

  const _AssignmentDialog({
    required this.assignment,
    required this.drivers,
    required this.vehicles,
    required this.onSave,
  });

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  late TextEditingController _campusController;
  late TextEditingController _coordinatorController;
  int? _selectedDriverId;
  int? _selectedVehicleId;

  bool get _canSave =>
      _campusController.text.trim().isNotEmpty &&
      _coordinatorController.text.trim().isNotEmpty &&
      _selectedDriverId != null &&
      _selectedVehicleId != null;

  @override
  void initState() {
    super.initState();
    _campusController = TextEditingController(
      text: widget.assignment?.campus ?? '',
    );
    _coordinatorController = TextEditingController(
      text: widget.assignment?.coordinatorName ?? '',
    );
    _selectedDriverId = widget.assignment?.driverId;
    _selectedVehicleId = widget.assignment?.vehicleId;
  }

  @override
  void dispose() {
    _campusController.dispose();
    _coordinatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.assignment != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Assignment' : 'Add Assignment',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.navy),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Campus Name
              const Text(
                'Campus Name',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _campusController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),

              // Coordinator Name
              const Text(
                'Administrator Name',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _coordinatorController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),

              // Driver
              const Text(
                'Assign Driver',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: widget.drivers.any(
                  (driver) => driver.id == _selectedDriverId,
                )
                    ? _selectedDriverId
                    : null,
                items: widget.drivers
                    .map((driver) => DropdownMenuItem<int>(
                          value: driver.id,
                          child: Text(driver.name),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedDriverId = value),
                decoration: InputDecoration(
                  hintText: 'Select driver',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),

              // Vehicle
              const Text(
                'Assign Vehicle',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: widget.vehicles.any(
                  (vehicle) => vehicle.id == _selectedVehicleId,
                )
                    ? _selectedVehicleId
                    : null,
                items: widget.vehicles
                    .map((vehicle) => DropdownMenuItem<int>(
                          value: vehicle.id,
                          child: Text(vehicle.name),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedVehicleId = value),
                decoration: InputDecoration(
                  hintText: 'Select vehicle',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 28),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.navy,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canSave
                          ? () => widget.onSave(
                                _campusController.text.trim(),
                                _coordinatorController.text.trim(),
                              _selectedDriverId!,
                              _selectedVehicleId!,
                              )
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        isEdit ? 'Update' : 'Save',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
