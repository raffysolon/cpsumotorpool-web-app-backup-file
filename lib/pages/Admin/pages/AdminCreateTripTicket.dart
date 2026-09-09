import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/pdf_opener.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

class AdminCreateTripTicketPage extends StatelessWidget {
  const AdminCreateTripTicketPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/approval-letter',
      child: const _AdminCreateTripTicketContent(),
    );
  }
}

abstract class AppColors {
  static const Color navy = Color(0xFF19332A);
  static const Color primary = Color(0xFF0B8F5A);
  static const Color primaryDark = Color(0xFF087448);
  static const Color mutedDark = Color(0xFF71827B);
  static const Color border = Color(0xFFDCE9E2);
  static const Color background = Color(0xFFF7FAF8);
  static const Color softGreen = Color(0xFFE8F7F0);
}

class _CreatedTripRecord {
  final int id;
  final String origin;
  final String destination;
  final String assignedDriver;
  final String assignedVehicle;
  final String status;

  const _CreatedTripRecord({
    required this.id,
    required this.origin,
    required this.destination,
    required this.assignedDriver,
    required this.assignedVehicle,
    required this.status,
  });

}

class _DriverOption {
  final int id;
  final String name;

  const _DriverOption({required this.id, required this.name});

  factory _DriverOption.fromJson(Map<String, dynamic> json) {
    return _DriverOption(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: (json['name'] ?? 'Unknown Driver').toString(),
    );
  }
}

class _VehicleOption {
  final int id;
  final String label;

  const _VehicleOption({required this.id, required this.label});

  factory _VehicleOption.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString();
    final plate = (json['plate_no'] ?? '').toString();
    final label = [name, plate].where((value) => value.isNotEmpty).join(' — ');

    return _VehicleOption(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      label: label.isNotEmpty ? label : 'N/A',
    );
  }
}

class _AdminCreateTripTicketContent extends StatefulWidget {
  const _AdminCreateTripTicketContent();

  @override
  State<_AdminCreateTripTicketContent> createState() =>
      _AdminCreateTripTicketContentState();
}

class _AdminCreateTripTicketContentState
    extends State<_AdminCreateTripTicketContent> {
  List<_CreatedTripRecord> _trips = [];
  List<_DriverOption> _drivers = [];
  List<_VehicleOption> _vehicles = [];
  bool _isLoading = true;
  bool _isOpeningTicket = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        TripService.getAvailableDrivers(),
        TripService.getAvailableVehicles(),
      ]);

      final driversResult = results[0];
      final vehiclesResult = results[1];

      final rawDrivers = driversResult is List ? driversResult : const [];

      final rawVehicles = vehiclesResult is List ? vehiclesResult : const [];

      if (!mounted) return;
      setState(() {
        _trips = [];

        _drivers = rawDrivers.whereType<Map>().map((driver) {
          return _DriverOption.fromJson(Map<String, dynamic>.from(driver));
        }).toList();

        _vehicles = rawVehicles.whereType<Map>().map((vehicle) {
          return _VehicleOption.fromJson(Map<String, dynamic>.from(vehicle));
        }).toList();

        _isLoading = false;
      });

      adminTripTicketCountNotifier.value = 0;
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load trip data: $error')),
      );
    }
  }

  void _showCreateTripDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _CreateTripDialog(
        drivers: _drivers,
        vehicles: _vehicles,
        onSubmit: (data) async {
          final currentContext = context;
          final currentDialogContext = dialogContext;

          try {
            final payload = {
              'origin': data['origin'],
              'destination': data['destination'],
              'purpose': data['purpose'],
              'scheduled_departure': data['scheduled_departure'],
              'return_scheduled_departure': data['return_scheduled_departure'],
              'driver_id': data['driver_id'],
              'vehicle_id': data['vehicle_id'],
              'passengers': data['passengers'],
            };

            await TripService.createAdminTrip(
              origin: payload['origin'] as String,
              destination: payload['destination'] as String,
              purpose: payload['purpose'] as String,
              scheduledDeparture: payload['scheduled_departure'] as String,
              returnScheduledDeparture:
                  payload['return_scheduled_departure'] as String?,
              driverId: int.parse(payload['driver_id'].toString()),
              vehicleId: int.parse(payload['vehicle_id'].toString()),
              passengers: (payload['passengers'] as List)
                  .map((item) => Map<String, String>.from(item as Map))
                  .toList(),
            );

            if (!mounted ||
                !currentContext.mounted ||
                !Navigator.of(currentDialogContext).mounted)
              return;
            Navigator.pop(currentDialogContext);
            adminTripTicketCountNotifier.value = 0;
            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(
                content: Text('Trip ticket created successfully'),
                backgroundColor: Colors.green,
              ),
            );
            await _loadData();
          } catch (error) {
            if (!mounted || !currentContext.mounted) return;
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(
                content: Text('Unable to create trip: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _openTripTicket(_CreatedTripRecord trip) async {
    if (_isOpeningTicket) return;

    setState(() => _isOpeningTicket = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TripTicketLoadingDialog(),
    );

    try {
      final response = await TripService.getTripTicket(trip.id);
      if (response.bodyBytes.isEmpty) {
        throw Exception('Received empty PDF response.');
      }
      await openPdf(response.bodyBytes, trip.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open trip ticket: $error')),
      );
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isOpeningTicket = false);
      }
    }
  }

  void _goToMap() {
    Navigator.pushNamed(context, '/map');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildTable(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      borderRadius: 0,
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Trip Ticket',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Create approved trip tickets for your fleet',
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
                onTap: () => AdminNotificationsController.instance
                    .showNotificationsDialog(context),
              );
            },
          ),
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Created Trips (${_trips.length})',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showCreateTripDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create Trip Ticket'),
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

  Widget _buildTable() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 860
              ? 860.0
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  _buildTableHeader(),
                  const Divider(height: 1, color: AppColors.border),
                  if (_trips.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Text(
                        'No trips created yet',
                        style: TextStyle(color: AppColors.mutedDark),
                      ),
                    )
                  else
                    ..._trips.asMap().entries.map(
                      (entry) => Column(
                        children: [
                          _buildTableRow(entry.value),
                          if (entry.key < _trips.length - 1)
                            const Divider(height: 1, color: AppColors.border),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableHeader() {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.mutedDark,
      letterSpacing: 0.8,
    );
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('ORIGIN', style: style)),
          Expanded(flex: 3, child: Text('DESTINATION', style: style)),
          Expanded(flex: 3, child: Text('ASSIGNED DRIVER', style: style)),
          Expanded(flex: 3, child: Text('ASSIGNED VEHICLE', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          SizedBox(width: 260),
        ],
      ),
    );
  }

  Widget _buildTableRow(_CreatedTripRecord trip) {
    const textStyle = TextStyle(color: AppColors.navy, fontSize: 13);
    final status = trip.status.toLowerCase() == 'approved'
        ? 'Approved'
        : trip.status;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              trip.origin.isNotEmpty ? trip.origin : 'N/A',
              style: textStyle,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              trip.destination.isNotEmpty ? trip.destination : 'N/A',
              style: textStyle,
            ),
          ),
          Expanded(flex: 3, child: Text(trip.assignedDriver, style: textStyle)),
          Expanded(
            flex: 3,
            child: Text(trip.assignedVehicle, style: textStyle),
          ),
          Expanded(flex: 2, child: _StatusBadge(status: status)),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF334155)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextButton.icon(
                onPressed: _isOpeningTicket
                    ? null
                    : () => _openTripTicket(trip),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(0, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text(
                  'View Ticket',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF334155)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextButton.icon(
                onPressed: () => _goToMap(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(0, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.location_on_outlined, size: 16),
                label: const Text(
                  'View on Map',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final approved = status.toLowerCase() == 'approved';
    final textColor = approved
        ? const Color(0xFF166534)
        : const Color(0xFF92400E);
    final bgColor = approved
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEF3C7);
    final borderColor = approved
        ? const Color(0xFF86EFAC)
        : const Color(0xFFFCD34D);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            approved ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 12,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripTicketLoadingDialog extends StatelessWidget {
  const _TripTicketLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        borderRadius: 16,
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(strokeWidth: 4),
              ),
              SizedBox(height: 18),
              Text(
                'Generating trip ticket...',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text('Please wait', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassengerDraft {
  const _PassengerDraft({required this.name, this.designation = ''});

  final String name;
  final String designation;
}

class _CreateTripDialog extends StatefulWidget {
  const _CreateTripDialog({
    required this.drivers,
    required this.vehicles,
    required this.onSubmit,
  });

  final List<_DriverOption> drivers;
  final List<_VehicleOption> vehicles;
  final Future<void> Function(Map<String, dynamic> data) onSubmit;

  @override
  State<_CreateTripDialog> createState() => _CreateTripDialogState();
}

class _CreateTripDialogState extends State<_CreateTripDialog> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _purposeController = TextEditingController();
  final List<_PassengerDraft> _passengers = [];
  DateTime _departureDate = DateTime.now();
  TimeOfDay _departureTime = TimeOfDay.fromDateTime(DateTime.now());
  DateTime? _returnDate;
  TimeOfDay? _returnTime;
  List<_DriverOption> _availableDrivers = [];
  List<_VehicleOption> _availableVehicles = [];
  int? _selectedDriverId;
  int? _selectedVehicleId;
  bool _isSubmitting = false;
  bool _isRefreshingAvailability = false;

  bool get _canSubmit =>
      _selectedDriverId != null && _selectedVehicleId != null;

  @override
  void initState() {
    super.initState();
    _availableDrivers = List<_DriverOption>.from(widget.drivers);
    _availableVehicles = List<_VehicleOption>.from(widget.vehicles);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAvailability();
    });
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
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
              _buildDialogTitle(),
              const SizedBox(height: 24),
              _buildTextField(
                'Origin',
                _originController,
                'Enter origin',
                Icons.trip_origin,
              ),
              _buildTextField(
                'Destination',
                _destinationController,
                'Enter destination',
                Icons.location_on_outlined,
              ),
              _buildTextField(
                'Purpose',
                _purposeController,
                'Enter trip purpose',
                Icons.description_outlined,
                maxLines: 3,
              ),
              _buildDepartureField(),
              _buildReturnField(),
              _buildPassengersSection(),
              const Text(
                'Assign Driver',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedDriverId,
                isExpanded: true,
                hint: _availableDrivers.isEmpty
                    ? const Text('No available drivers')
                    : const Text('Select available driver'),
                decoration: _inputDecoration(
                  'Driver',
                  _isRefreshingAvailability
                      ? 'Checking available drivers...'
                      : 'Select available driver',
                  Icons.person_outline,
                ),
                items: _availableDrivers.map((driver) {
                  return DropdownMenuItem<int>(
                    value: driver.id,
                    child: Text(driver.name),
                  );
                }).toList(),
                onChanged: _availableDrivers.isEmpty
                    ? null
                    : (value) => setState(() => _selectedDriverId = value),
              ),
              const SizedBox(height: 16),
              const Text(
                'Assign Vehicle',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedVehicleId,
                isExpanded: true,
                hint: _availableVehicles.isEmpty
                    ? const Text('No available vehicles')
                    : const Text('Select available vehicle'),
                decoration: _inputDecoration(
                  'Vehicle',
                  _isRefreshingAvailability
                      ? 'Checking available vehicles...'
                      : 'Select available vehicle',
                  Icons.directions_car_outlined,
                ),
                items: _availableVehicles.map((vehicle) {
                  return DropdownMenuItem<int>(
                    value: vehicle.id,
                    child: Text(vehicle.label),
                  );
                }).toList(),
                onChanged: _availableVehicles.isEmpty
                    ? null
                    : (value) => setState(() => _selectedVehicleId = value),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canSubmit && !_isSubmitting ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Trip Ticket'),
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

  Widget _buildDialogTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Create Trip Ticket',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close, color: AppColors.navy),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: _inputDecoration(label, hint, icon),
      ),
    );
  }

  Widget _buildDepartureField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _pickDeparture,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration:
              _inputDecoration(
                'Scheduled Departure',
                'Select departure time',
                Icons.calendar_month_outlined,
              ).copyWith(
                suffixIcon: const Icon(
                  Icons.access_time_rounded,
                  color: AppColors.primary,
                ),
              ),
          child: Text(
            '${_formatDate(_departureDate)} at ${_formatTime(_departureTime)}',
            style: const TextStyle(color: AppColors.navy, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildReturnField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _pickReturn,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration:
              _inputDecoration(
                'Return Departure (Optional)',
                'Select return date and time if known',
                Icons.keyboard_return_rounded,
              ).copyWith(
                suffixIcon: _returnDate == null
                    ? const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.primary,
                      )
                    : IconButton(
                        tooltip: 'Clear return schedule',
                        icon: const Icon(Icons.clear, color: AppColors.primary),
                        onPressed: () => setState(() {
                          _returnDate = null;
                          _returnTime = null;
                        }),
                      ),
              ),
          child: Text(
            _returnDate == null || _returnTime == null
                ? 'To be confirmed'
                : '${_formatDate(_returnDate!)} at ${_formatTime(_returnTime!)}',
            style: const TextStyle(color: AppColors.navy, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildPassengersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passengers',
          style: TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ..._passengers.asMap().entries.map(
          (entry) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${entry.value.name}${entry.value.designation.isNotEmpty ? ' — ${entry.value.designation}' : ''}',
                  ),
                ),
                IconButton(
                  tooltip: 'Remove passenger',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () =>
                      setState(() => _passengers.removeAt(entry.key)),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showAddPassengerDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Passenger'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 19),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Future<void> _pickDeparture() async {
    final now = DateTime.now();
    final initialDate =
        _departureDate.isBefore(DateTime(now.year, now.month, now.day))
        ? now
        : _departureDate;
    final currentContext = context;

    final date = await showDatePicker(
      context: currentContext,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted || !currentContext.mounted) return;

    final time = await showTimePicker(
      context: currentContext,
      initialTime: _departureTime,
    );
    if (!mounted || !currentContext.mounted) return;

    setState(() {
      _departureDate = date;
      if (time != null) {
        _departureTime = time;
      }
    });

    await _refreshAvailability();
  }

  Future<void> _pickReturn() async {
    final now = DateTime.now();
    final initialDate = _returnDate ?? _departureDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(DateTime(now.year, now.month, now.day))
          ? now
          : initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _returnTime ?? _departureTime,
    );
    if (!mounted || time == null) return;

    setState(() {
      _returnDate = date;
      _returnTime = time;
    });
  }

  Future<void> _refreshAvailability() async {
    final scheduledDeparture = _buildScheduledDeparture();

    setState(() => _isRefreshingAvailability = true);

    try {
      final driversResponse = await TripService.getAvailableDrivers(
        scheduledDeparture: scheduledDeparture,
      );
      final vehiclesResponse = await TripService.getAvailableVehicles(
        scheduledDeparture: scheduledDeparture,
      );

      final refreshedDrivers =
          (driversResponse is List ? driversResponse : const [])
              .whereType<Map>()
              .map(
                (driver) =>
                    _DriverOption.fromJson(Map<String, dynamic>.from(driver)),
              )
              .toList();

      final refreshedVehicles =
          (vehiclesResponse is List ? vehiclesResponse : const [])
              .whereType<Map>()
              .map(
                (vehicle) =>
                    _VehicleOption.fromJson(Map<String, dynamic>.from(vehicle)),
              )
              .toList();

      if (!mounted) return;

      setState(() {
        _availableDrivers = refreshedDrivers;
        _availableVehicles = refreshedVehicles;

        if (_selectedDriverId != null &&
            !_availableDrivers.any(
              (driver) => driver.id == _selectedDriverId,
            )) {
          _selectedDriverId = null;
        }

        if (_selectedVehicleId != null &&
            !_availableVehicles.any(
              (vehicle) => vehicle.id == _selectedVehicleId,
            )) {
          _selectedVehicleId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availableDrivers = List<_DriverOption>.from(widget.drivers);
        _availableVehicles = List<_VehicleOption>.from(widget.vehicles);
      });
    } finally {
      if (mounted) {
        setState(() => _isRefreshingAvailability = false);
      }
    }
  }

  Future<void> _showAddPassengerDialog() async {
    final nameController = TextEditingController();
    final designationController = TextEditingController();

    final passenger = await showDialog<_PassengerDraft>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Passenger'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: designationController,
              decoration: const InputDecoration(
                labelText: 'Designation / Position',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(
                dialogContext,
                _PassengerDraft(
                  name: name,
                  designation: designationController.text.trim(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (passenger != null && mounted) {
      setState(() => _passengers.add(passenger));
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    final scheduledDeparture = _buildScheduledDeparture();

    setState(() => _isSubmitting = true);

    final passengers = _passengers
        .map(
          (passenger) => {
            'name': passenger.name,
            'designation': passenger.designation,
          },
        )
        .toList();

    await widget.onSubmit({
      'origin': _originController.text.trim(),
      'destination': _destinationController.text.trim(),
      'purpose': _purposeController.text.trim(),
      'scheduled_departure': scheduledDeparture,
      'return_scheduled_departure': _buildReturnScheduledDeparture(),
      'driver_id': _selectedDriverId,
      'vehicle_id': _selectedVehicleId,
      'passengers': passengers,
    });

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  String? _buildReturnScheduledDeparture() {
    if (_returnDate == null || _returnTime == null) return null;

    final scheduledDate = DateTime(
      _returnDate!.year,
      _returnDate!.month,
      _returnDate!.day,
      _returnTime!.hour,
      _returnTime!.minute,
    );

    return '${scheduledDate.year}-'
        '${scheduledDate.month.toString().padLeft(2, '0')}-'
        '${scheduledDate.day.toString().padLeft(2, '0')} '
        '${scheduledDate.hour.toString().padLeft(2, '0')}:${scheduledDate.minute.toString().padLeft(2, '0')}:00';
  }

  String _buildScheduledDeparture() {
    final scheduledDate = DateTime(
      _departureDate.year,
      _departureDate.month,
      _departureDate.day,
      _departureTime.hour,
      _departureTime.minute,
    );

    return '${scheduledDate.year}-'
        '${scheduledDate.month.toString().padLeft(2, '0')}-'
        '${scheduledDate.day.toString().padLeft(2, '0')} '
        '${scheduledDate.hour.toString().padLeft(2, '0')}:${scheduledDate.minute.toString().padLeft(2, '0')}:00';
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    return '$hour:${time.minute.toString().padLeft(2, '0')} '
        '${time.period == DayPeriod.am ? 'AM' : 'PM'}';
  }
}
