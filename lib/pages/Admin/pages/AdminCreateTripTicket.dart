import 'package:flutter/material.dart';
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

class _TripRecord {
  final String origin;
  final String destination;
  final String assignedDriver;
  final String assignedVehicle;
  final String status;

  const _TripRecord({
    required this.origin,
    required this.destination,
    required this.assignedDriver,
    required this.assignedVehicle,
    required this.status,
  });
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

final List<_TripRecord> _createdTrips = [
  const _TripRecord(
    destination: 'Bacolod City Hall',
    origin: 'CPSU San Carlos',
    assignedDriver: 'Ramon Dela Cruz',
    assignedVehicle: 'Toyota Innova - SJA 4421',
    status: 'Approved',
  ),
  const _TripRecord(
    destination: 'Provincial Capitol',
    origin: 'CPSU San Carlos',
    assignedDriver: 'Jose Reyes',
    assignedVehicle: 'Mitsubishi L300 - SJB 8832',
    status: 'Approved',
  ),
];

class _AdminCreateTripTicketContent extends StatefulWidget {
  const _AdminCreateTripTicketContent();

  @override
  State<_AdminCreateTripTicketContent> createState() =>
      _AdminCreateTripTicketContentState();
}

class _AdminCreateTripTicketContentState
    extends State<_AdminCreateTripTicketContent> {
  late List<_TripRecord> _trips;

  @override
  void initState() {
    super.initState();
    _trips = List.from(_createdTrips);
  }

  void _createTripTicket(Map<String, dynamic> data) {
    // TODO: Replace this placeholder with the API call that creates an approved Trip record.
    setState(() {
      _trips.add(
        _TripRecord(
          origin: data['origin'] as String,
          destination: data['destination'] as String,
          assignedDriver: data['assignedDriver'] as String,
          assignedVehicle: data['assignedVehicle'] as String,
          status: 'Approved',
        ),
      );
    });
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Trip Ticket', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.navy,
              )),
              SizedBox(height: 2),
              Text('Create approved trip tickets for your fleet',
                  style: TextStyle(fontSize: 13, color: AppColors.mutedDark)),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded,
                size: 24, color: AppColors.navy),
            onPressed: () {},
          ),
          const SizedBox(width: 6),
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
        Text('Created Trips (${_trips.length})', style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.navy,
        )),
        ElevatedButton.icon(
          onPressed: () => _showCreateTripDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create Trip Ticket'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 760 ? 760.0 : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  _buildTableHeader(),
                  const Divider(height: 1, color: AppColors.border),
                  ..._trips.asMap().entries.map((entry) => Column(
                        children: [
                          _buildTableRow(entry.value),
                          if (entry.key < _trips.length - 1)
                            const Divider(height: 1, color: AppColors.border),
                        ],
                      )),
                  if (_trips.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Text('No trips created yet',
                          style: TextStyle(color: AppColors.mutedDark)),
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
      fontSize: 11, fontWeight: FontWeight.w600,
      color: AppColors.mutedDark, letterSpacing: 0.8,
    );
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('DESTINATION', style: style)),
          Expanded(flex: 3, child: Text('ASSIGNED DRIVER', style: style)),
          Expanded(flex: 4, child: Text('ASSIGNED VEHICLE', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
        ],
      ),
    );
  }

  Widget _buildTableRow(_TripRecord trip) {
    const textStyle = TextStyle(color: AppColors.navy, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(trip.destination, style: textStyle)),
          Expanded(flex: 3, child: Text(trip.assignedDriver, style: textStyle)),
          Expanded(flex: 4, child: Text(trip.assignedVehicle, style: textStyle)),
          Expanded(flex: 2, child: _StatusBadge(status: trip.status)),
        ],
      ),
    );
  }

  void _showCreateTripDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _CreateTripDialog(
        onSave: (data) {
          _createTripTicket(data);
          Navigator.pop(dialogContext);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Trip ticket created successfully'),
            backgroundColor: Colors.green,
          ));
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A),
      )),
    );
  }
}

class _PassengerDraft {
  const _PassengerDraft({required this.name, required this.designation});

  final String name;
  final String designation;
}

class _CreateTripDialog extends StatefulWidget {
  const _CreateTripDialog({required this.onSave});

  final ValueChanged<Map<String, dynamic>> onSave;

  @override
  State<_CreateTripDialog> createState() => _CreateTripDialogState();
}

class _CreateTripDialogState extends State<_CreateTripDialog> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _purposeController = TextEditingController();
  final _passengers = <_PassengerDraft>[];
  final _drivers = ['John Doe', 'Jane Smith', 'Ramon Dela Cruz', 'Jose Reyes'];
  final _vehicles = [
    'Toyota Innova - SJA 4421',
    'Mitsubishi L300 - SJB 8832',
    'Toyota Hi-Ace - SJC 1194',
  ];
  DateTime _departureDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _departureTime = const TimeOfDay(hour: 8, minute: 0);
  String? _selectedDriver;
  String? _selectedVehicle;

  bool get _canCreate =>
      _originController.text.trim().isNotEmpty &&
      _destinationController.text.trim().isNotEmpty &&
      _purposeController.text.trim().isNotEmpty &&
      _passengers.isNotEmpty &&
      _passengers.every((passenger) => passenger.name.trim().isNotEmpty &&
          passenger.designation.trim().isNotEmpty) &&
      _selectedDriver != null && _selectedVehicle != null;

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
        width: 600,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogTitle(),
              const SizedBox(height: 24),
                _buildTextField('Origin', _originController,
                  'Enter origin', Icons.trip_origin),
              _buildTextField('Destination', _destinationController,
                  'Enter destination', Icons.location_on_outlined),
              _buildTextField('Purpose', _purposeController, 'Enter purpose of trip',
                  Icons.description_outlined, maxLines: 3),
              _buildDepartureField(),
              _buildPassengersSection(),
              _buildDropdown('Assign Driver', Icons.person_outline, _selectedDriver,
                  _drivers, (value) => setState(() => _selectedDriver = value)),
              _buildDropdown('Assign Vehicle', Icons.directions_car_outlined,
                  _selectedVehicle, _vehicles,
                  (value) => setState(() => _selectedVehicle = value)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: _canCreate ? () => widget.onSave({
                      'origin': _originController.text.trim(),
                      'destination': _destinationController.text.trim(),
                      'purpose': _purposeController.text.trim(),
                      'departure': DateTime(
                        _departureDate.year, _departureDate.month, _departureDate.day,
                        _departureTime.hour, _departureTime.minute,
                      ),
                      'passengers': _passengers,
                      'assignedDriver': _selectedDriver!,
                      'assignedVehicle': _selectedVehicle!,
                    }) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                    ),
                    child: const Text('Create Trip Ticket'),
                  )),
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
        const Text('Create Trip Ticket', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy,
        )),
        IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close, color: AppColors.navy),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      String hint, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
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
          decoration: _inputDecoration('Scheduled Departure Time',
              'Select departure time', Icons.calendar_month_outlined).copyWith(
            suffixIcon: const Icon(Icons.access_time_rounded, color: AppColors.primary),
          ),
          child: Text('${_formatDate(_departureDate)} at ${_formatTime(_departureTime)}',
              style: const TextStyle(color: AppColors.navy, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildPassengersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Passengers', style: TextStyle(
          color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 14,
        )),
        const SizedBox(height: 8),
        ..._passengers.asMap().entries.map((entry) => Container(
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
                  Expanded(child: Text('${entry.value.name} - ${entry.value.designation}')),
                  IconButton(
                    tooltip: 'Remove passenger',
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => setState(() => _passengers.removeAt(entry.key)),
                  ),
                ],
              ),
            )),
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

  Widget _buildDropdown(String label, IconData icon, String? value,
      List<String> options, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: options.map((option) => DropdownMenuItem(
          value: option, child: Text(option),
        )).toList(),
        onChanged: onChanged,
        decoration: _inputDecoration(label, 'Select ${label.toLowerCase()}', icon),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 19),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  Future<void> _pickDeparture() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departureDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: _departureTime);
    if (!mounted) return;
    setState(() {
      _departureDate = date;
      if (time != null) {
        _departureTime = time;
      }
    });
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
            TextField(controller: nameController, autofocus: true,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: designationController,
                decoration: const InputDecoration(labelText: 'Designation / Position')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty ||
                  designationController.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(dialogContext, _PassengerDraft(
                name: nameController.text.trim(),
                designation: designationController.text.trim(),
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameController.dispose();
    designationController.dispose();
    if (passenger != null && mounted) setState(() => _passengers.add(passenger));
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    return '$hour:${time.minute.toString().padLeft(2, '0')} '
        '${time.period == DayPeriod.am ? 'AM' : 'PM'}';
  }
}
