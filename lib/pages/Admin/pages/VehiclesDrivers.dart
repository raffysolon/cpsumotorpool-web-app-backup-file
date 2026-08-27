import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/driver_service.dart';
import 'package:cpsumotorpooladmin/services/vehicle_service.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

// === Combined vehicle and driver management page ===
// Route: /vehicles
class VehiclesDriversPage extends StatefulWidget {
  const VehiclesDriversPage({super.key});

  @override
  State<VehiclesDriversPage> createState() => _VehiclesDriversState();
}

class _VehiclesDriversState extends State<VehiclesDriversPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _vehicles = <_VehicleData>[];
  final _drivers = <_DriverData>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        DriverService.getDrivers(),
        VehicleService.getVehicles(),
      ]);
      if (!mounted) return;
      setState(() {
        _drivers
          ..clear()
          ..addAll(_parseDrivers(results[0]));
        _vehicles
          ..clear()
          ..addAll(_parseVehicles(results[1]));
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load drivers and vehicles: $error')),
      );
    }
  }

  List<_DriverData> _parseDrivers(dynamic response) {
    final records = _records(response);
    return records.map((record) {
      return _DriverData(
        _toInt(record['id']),
        _stringValue(record['name']),
        _stringValue(record['email']),
        _stringValue(record['contact_number'] ?? record['contactNumber']),
        _stringValue(record['status'], fallback: 'Active'),
        _stringValue(record['license_number'] ?? record['licenseNumber']),
      );
    }).where((driver) => driver.id > 0).toList();
  }

  List<_VehicleData> _parseVehicles(dynamic response) {
    final records = _records(response);
    return records.map((record) {
      return _VehicleData(
        _toInt(record['id']),
        _stringValue(record['name']),
        _stringValue(record['plate_no'] ?? record['plate'] ?? record['plateNo']),
        _stringValue(record['status'], fallback: 'Available'),
      );
    }).where((vehicle) => vehicle.id > 0).toList();
  }

  List<Map<String, dynamic>> _records(dynamic response) {
    final records = response is List
        ? response
        : response is Map<String, dynamic> && response['data'] is List
            ? response['data'] as List
            : const [];
    return records.whereType<Map<String, dynamic>>().toList();
  }

  static int _toInt(dynamic value) => int.tryParse('$value') ?? 0;

  static String _stringValue(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/vehicles',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildVehiclesTab(), _buildDriversTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      child: const Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vehicles & Drivers',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Province of Negros Occidental - Motorpool Division',
                style: TextStyle(fontSize: 13, color: AppColors.mutedDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final isDriversTab = _tabController.index == 1;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primaryDark,
              unselectedLabelColor: AppColors.mutedDark,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Vehicles'),
                Tab(text: 'Drivers'),
              ],
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton.icon(
            onPressed: isDriversTab
                ? _showAddDriverDialog
                : _showAddVehicleDialog,
            icon: const Icon(Icons.add, size: 18),
            label: Text(isDriversTab ? 'Add Driver' : 'Add Vehicle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesTab() {
    return _buildTabContent(
      title: 'Fleet vehicles',
      subtitle: 'Manage the vehicles available to the motorpool.',
      child: _isLoading ? _loadingIndicator() : _buildVehicleTable(),
    );
  }

  Widget _buildDriversTab() {
    return _buildTabContent(
      title: 'Registered drivers',
      subtitle: 'Manage driver accounts and licensing information.',
      child: _isLoading ? _loadingIndicator() : _buildDriverTable(),
    );
  }

  Widget _loadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildTabContent({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: AppColors.mutedDark),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleTable() {
    return _buildTable(
      minWidth: 700,
      headers: const ['VEHICLE NAME / MODEL', 'PLATE NUMBER', 'STATUS', 'ACTIONS'],
      rows: [
        for (var i = 0; i < _vehicles.length; i++) _buildVehicleRow(i, _vehicles[i]),
      ],
      flexes: const [6, 4, 3, 2],
    );
  }

  Widget _buildDriverTable() {
    return _buildTable(
      minWidth: 900,
      headers: const ['NAME', 'EMAIL', 'CONTACT NUMBER', 'STATUS', 'ACTIONS'],
      rows: [
        for (var i = 0; i < _drivers.length; i++) _buildDriverRow(i, _drivers[i]),
      ],
      flexes: const [4, 6, 4, 3, 2],
    );
  }

  Widget _buildTable({
    required double minWidth,
    required List<String> headers,
    required List<Widget> rows,
    required List<int> flexes,
  }) {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.mutedDark,
      letterSpacing: .8,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        for (var i = 0; i < headers.length; i++)
                          Expanded(flex: flexes[i], child: Text(headers[i], style: headerStyle)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  ...rows,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVehicleRow(int index, _VehicleData vehicle) {
    return _dataRow(
      children: [
        Expanded(flex: 6, child: _primaryText(vehicle.name)),
        Expanded(flex: 4, child: _bodyText(vehicle.plate)),
        Expanded(flex: 3, child: _statusBadge(vehicle.status)),
        Expanded(flex: 2, child: _actions(
          onEdit: () => _showEditVehicleDialog(vehicle),
          onDelete: () => _confirmDeleteVehicle(vehicle),
        )),
      ],
    );
  }

  Widget _buildDriverRow(int index, _DriverData driver) {
    return _dataRow(
      children: [
        Expanded(flex: 4, child: _primaryText(driver.name)),
        Expanded(flex: 6, child: _bodyText(driver.email)),
        Expanded(flex: 4, child: _bodyText(driver.contactNumber)),
        Expanded(flex: 3, child: _statusBadge(driver.status)),
        Expanded(flex: 2, child: _actions(
          onEdit: () => _showDriverDetails(driver),
          onDelete: () => _confirmDeleteDriver(driver),
          isDetails: true,
        )),
      ],
    );
  }

  Widget _dataRow({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: children),
    );
  }

  Widget _primaryText(String value) => Text(
        value,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy),
      );

  Widget _bodyText(String value) => Text(
        value,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: AppColors.navy),
      );

  Widget _statusBadge(String status) {
    final active = status == 'Active' || status == 'Available';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _actions({
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    VoidCallback? onReset,
    bool isDetails = false,
  }) {
    return Row(
      children: [
        IconButton(
          tooltip: isDetails ? 'Details' : 'Edit',
          onPressed: onEdit,
          icon: Icon(
            isDetails ? Icons.info_outline : Icons.edit_outlined,
            size: 18,
            color: AppColors.mutedDark,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        if (onReset != null)
          IconButton(
            tooltip: 'Reset Password',
            onPressed: onReset,
            icon: const Icon(Icons.lock_reset_outlined, size: 18, color: AppColors.mutedDark),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        IconButton(
          tooltip: 'Delete',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.mutedDark),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Future<void> _showAddVehicleDialog() async {
    await _showVehicleDialog();
  }

  Future<void> _showEditVehicleDialog(_VehicleData vehicle) async {
    await _showVehicleDialog(vehicle: vehicle);
  }

  Future<void> _showVehicleDialog({_VehicleData? vehicle}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _VehicleDialog(
        vehicle: vehicle,
        onSave: (name, plate) async {
          if (vehicle == null) {
            await VehicleService.createVehicle(name: name, plateNo: plate);
          } else {
            await VehicleService.updateVehicle(
              vehicle.id,
              name: name,
              plateNo: plate,
            );
          }
          if (!mounted) return;
          await _loadData();
        },
      ),
    );
  }

  Future<void> _showAddDriverDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final contactController = TextEditingController();
    final licenseController = TextEditingController();
    final passwordController = TextEditingController();
    await _showDriverDialog(
      nameController: nameController,
      emailController: emailController,
      contactController: contactController,
      licenseController: licenseController,
      passwordController: passwordController,
    );
  }

  Future<void> _showEditDriverDialog(int index) async {
    final driver = _drivers[index];
    await _showDriverDialog(
      index: index,
      nameController: TextEditingController(text: driver.name),
      emailController: TextEditingController(text: driver.email),
      contactController: TextEditingController(text: driver.contactNumber),
      licenseController: TextEditingController(text: driver.licenseNumber),
      passwordController: TextEditingController(),
    );
  }

  Future<void> _showDriverDetails(_DriverData driver) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Driver Details',
          style: TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Name', driver.name),
              _detailRow('Email', driver.email),
              _detailRow('Contact Number', driver.contactNumber),
              _detailRow('License Number', driver.licenseNumber),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Status',
                      style: TextStyle(color: AppColors.mutedDark, fontSize: 13),
                    ),
                  ),
                  _statusBadge(driver.status),
                ],
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, 'edit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Edit Details'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, 'reset'),
            style: _buttonStyle(),
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == 'edit') {
      final index = _drivers.indexWhere((item) => item.id == driver.id);
      if (index >= 0) await _showEditDriverDialog(index);
    } else if (action == 'reset') {
      await _confirmResetDriverPassword(driver);
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.mutedDark, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDriverDialog({
    required TextEditingController nameController,
    required TextEditingController emailController,
    required TextEditingController contactController,
    required TextEditingController licenseController,
    required TextEditingController passwordController,
    int? index,
  }) async {
    final formKey = GlobalKey<FormState>();
    var submitting = false;
    var obscurePassword = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            index == null ? 'Add Driver' : 'Edit Driver',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _formField(nameController, 'Name'),
                    const SizedBox(height: 12),
                    _formField(emailController, 'Email', keyboardType: TextInputType.emailAddress, validator: _emailValidator),
                    const SizedBox(height: 12),
                    _formField(contactController, 'Contact Number', keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    _formField(licenseController, 'License Number'),
                    const SizedBox(height: 12),
                    _formField(
                      passwordController,
                      index == null
                          ? 'Password'
                          : 'New Password (leave blank to keep current)',
                      obscureText: obscurePassword,
                      validator: (value) {
                        final password = value?.trim() ?? '';
                        if (index == null && password.isEmpty) {
                          return 'Password is required';
                        }
                        if (password.isNotEmpty && password.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                      suffixIcon: IconButton(
                        tooltip: obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () => setDialogState(
                          () => obscurePassword = !obscurePassword,
                        ),
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => submitting = true);
                      final name = nameController.text.trim();
                      final email = emailController.text.trim();
                      final contact = contactController.text.trim();
                      final license = licenseController.text.trim();
                      final password = passwordController.text;

                      try {
                        if (index == null) {
                          await _createDriverAccount(
                            name: name,
                            email: email,
                            contactNumber: contact,
                            licenseNumber: license,
                            password: password,
                          );
                        } else {
                          await _updateDriverAccount(
                            driverId: _drivers[index].id,
                            name: name,
                            email: email,
                            contactNumber: contact,
                            licenseNumber: license,
                            password: password.trim().isEmpty ? null : password,
                          );
                        }
                        await _loadData();
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => submitting = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Unable to save driver: $error')),
                        );
                      }
                    },
              style: _buttonStyle(),
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(index == null ? 'Create Driver' : 'Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    emailController.dispose();
    contactController.dispose();
    licenseController.dispose();
    passwordController.dispose();
  }

  Future<void> _confirmResetDriverPassword(_DriverData driver) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text(
              'Reset driver password?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            content: const Text(
              "Reset this driver's password? A new temporary password will be generated.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: _buttonStyle(),
                child: const Text('Reset Password'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;
    try {
      await _resetDriverPassword(driver.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver password reset successfully')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to reset password: $error')),
        );
      }
    }
  }

  Future<void> _resetDriverPassword(int driverId) async {
    await DriverService.resetPassword(driverId);
  }

  Future<void> _createDriverAccount({
    required String name,
    required String email,
    required String contactNumber,
    required String licenseNumber,
    required String password,
  }) async {
    await DriverService.createDriver(
      name: name,
      email: email,
      contactNumber: contactNumber,
      licenseNumber: licenseNumber,
      password: password,
    );
  }

  Future<void> _updateDriverAccount({
    required int driverId,
    required String name,
    required String email,
    required String contactNumber,
    required String licenseNumber,
    String? password,
  }) async {
    await DriverService.updateDriver(
      driverId,
      name: name,
      email: email,
      contactNumber: contactNumber,
      licenseNumber: licenseNumber,
      password: password,
    );
  }

  Widget _formField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator ?? (value) => value == null || value.trim().isEmpty ? '$label is required' : null,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFFAFCFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim()) ? null : 'Enter a valid email address';
  }

  ButtonStyle _buttonStyle() => ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  Future<void> _confirmDeleteVehicle(_VehicleData vehicle) async {
    final confirmed = await _confirmDelete('Delete Vehicle', 'Delete "${vehicle.name}"?');
    if (!confirmed || !mounted) return;
    try {
      await VehicleService.deleteVehicle(vehicle.id);
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete vehicle: $error')),
        );
      }
    }
  }

  Future<void> _confirmDeleteDriver(_DriverData driver) async {
    final confirmed = await _confirmDelete('Delete Driver', 'Delete "${driver.name}"?');
    if (!confirmed || !mounted) return;
    try {
      await DriverService.deleteDriver(driver.id);
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete driver: $error')),
        );
      }
    }
  }

  Future<bool> _confirmDelete(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), style: _buttonStyle(), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
  }
}

class _VehicleDialog extends StatefulWidget {
  const _VehicleDialog({this.vehicle, required this.onSave});

  final _VehicleData? vehicle;
  final Future<void> Function(String name, String plate) onSave;

  @override
  State<_VehicleDialog> createState() => _VehicleDialogState();
}

class _VehicleDialogState extends State<_VehicleDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _plateController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.vehicle?.name ?? '');
    _plateController = TextEditingController(text: widget.vehicle?.plate ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.vehicle != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        isEdit ? 'Edit Vehicle' : 'Add Vehicle',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _formField(_nameController, 'Name / Model'),
                const SizedBox(height: 12),
                _formField(_plateController, 'Plate Number'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            try {
              await widget.onSave(
                _nameController.text.trim(),
                _plateController.text.trim(),
              );
              if (context.mounted) Navigator.pop(context);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unable to save vehicle: $error')),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0B8F5A),
            foregroundColor: Colors.white,
          ),
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Widget _formField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      validator: (value) => value == null || value.trim().isEmpty
          ? '$label is required'
          : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFFAFCFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _VehicleData {
  _VehicleData(this.id, this.name, this.plate, this.status);
  final int id;
  String name;
  String plate;
  String status;
}

class _DriverData {
  _DriverData(this.id, this.name, this.email, this.contactNumber, this.status, this.licenseNumber);
  final int id;
  String name;
  String email;
  String contactNumber;
  String status;
  String licenseNumber;
}
