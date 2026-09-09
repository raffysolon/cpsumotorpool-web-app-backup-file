import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/assignment_service.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

// === Create trip ticket page: multi-step driver request form ===
class CreateTripTicket extends StatefulWidget {
  const CreateTripTicket({super.key});

  @override
  State<CreateTripTicket> createState() => _CreateTripTicketState();
}

class _CreateTripTicketState extends State<CreateTripTicket> {
  // --- Theme constants: colors used by the trip ticket form ---
  static const _green = AppColors.primary;
  static const _greenDark = AppColors.primaryDark;
  static const _greenSoft = AppColors.mint;
  static const _ink = AppColors.navy;
  static const _muted = AppColors.mutedDark;
  static const _line = AppColors.border;
  static const _background = AppColors.background;

  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _purposeController = TextEditingController();

  static const _locations = [
    'CPSU SAN CARLOS',
    'CPSU BACOLOD',
    'CPSU KABANKALAN',
    'CPSU HIMAMAYLAN',
  ];

  int _step = 0;
  bool _isLoadingAssignment = true;
  bool _isSubmitting = false;
  int? _vehicleId;
  String? _vehicleDisplayName;
  DateTime _departureDate = DateTime.now();
  TimeOfDay _departureTime = TimeOfDay.fromDateTime(DateTime.now());
  DateTime? _returnDate;
  TimeOfDay? _returnTime;
  final List<Map<String, String>> _passengers =
      []; // Changed to store name and designation

  @override
  void initState() {
    super.initState();
    _loadAssignment();
  }

  Future<void> _loadAssignment() async {
    try {
      final assignment = await AssignmentService.getMyAssignment();
      if (!mounted) return;
      final vehicle = assignment?['vehicle'];
      final vehicleName = vehicle is Map
          ? vehicle['name']?.toString() ?? ''
          : '';
      final plateNo = vehicle is Map
          ? vehicle['plate_no']?.toString() ?? ''
          : '';
      setState(() {
        _vehicleId = _toInt(
          assignment?['vehicle_id'] ?? (vehicle is Map ? vehicle['id'] : null),
        );
        _vehicleDisplayName = [
          vehicleName,
          plateNo,
        ].where((value) => value.isNotEmpty).join(' — ');
        _isLoadingAssignment = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vehicleId = null;
        _vehicleDisplayName = null;
        _isLoadingAssignment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load vehicle assignment')),
      );
    }
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  @override
  // --- Page layout: step indicator, current form step, and actions ---
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DriverShellAtmosphere(
        child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              narrow ? 18 : 48,
              24,
              narrow ? 18 : 48,
              48,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  children: [
                    _buildHeader(narrow),
                    const SizedBox(height: 28),
                    _buildProgress(narrow),
                    const SizedBox(height: 28),
                    _buildStepContent(narrow),
                  ],
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _buildHeader(bool narrow) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back to dashboard',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
        const SizedBox(width: 6),
        Container(
          width: narrow ? 36 : 42,
          height: narrow ? 36 : 42,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.local_shipping_rounded,
            color: Colors.white,
            size: narrow ? 20 : 23,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Create Trip Ticket',
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (!narrow)
          const Text(
            'Driver Portal',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
      ],
    );
  }

  Widget _buildProgress(bool narrow) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 32, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: narrow
          ? Column(
              children: [
                _buildCompactStep(0, 'Trip Details', Icons.edit_note_rounded),
                _buildCompactStep(
                  1,
                  'Passengers',
                  Icons.people_outline_rounded,
                ),
                _buildCompactStep(2, 'Review', Icons.fact_check_outlined),
              ],
            )
          : Row(
              children: [
                _buildStepIndicator(0, 'Trip Details', Icons.edit_note_rounded),
                _buildProgressLine(0),
                _buildStepIndicator(
                  1,
                  'Passengers',
                  Icons.people_outline_rounded,
                ),
                _buildProgressLine(1),
                _buildStepIndicator(2, 'Review', Icons.fact_check_outlined),
              ],
            ),
    );
  }

  Widget _buildCompactStep(int index, String label, IconData icon) {
    final active = _step == index;
    final complete = _step > index;
    final color = active || complete ? _green : _muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active || complete ? _green : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Icon(
              complete ? Icons.check_rounded : icon,
              color: active || complete ? Colors.white : _muted,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: active || complete
                  ? FontWeight.w800
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int index, String label, IconData icon) {
    final active = _step == index;
    final complete = _step > index;
    final color = active || complete ? _green : _muted;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active || complete ? _green : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Icon(
              complete ? Icons.check_rounded : icon,
              color: active || complete ? Colors.white : _muted,
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: active || complete
                  ? FontWeight.w800
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLine(int index) {
    return Expanded(
      child: Container(
        height: 2,
        color: _step > index ? _green : _line,
        margin: const EdgeInsets.only(bottom: 24),
      ),
    );
  }

  Widget _buildStepContent(bool narrow) {
    switch (_step) {
      case 1:
        return _buildPassengerStep(narrow);
      case 2:
        return _buildReviewStep(narrow);
      default:
        return _buildDetailsStep(narrow);
    }
  }

  Widget _buildDetailsStep(bool narrow) {
    if (_isLoadingAssignment) {
      return _buildPanel(
        title: 'Trip Details',
        subtitle: 'Loading your vehicle assignment.',
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_vehicleId == null || (_vehicleDisplayName ?? '').isEmpty) {
      return _buildPanel(
        title: 'Trip Details',
        subtitle: 'Vehicle assignment required.',
        child: const Text(
          'No vehicle assigned yet. Contact your Motorpool Administrator.',
          style: TextStyle(color: _muted, fontSize: 14),
        ),
      );
    }

    return _buildPanel(
      title: 'Trip Details',
      subtitle: 'Enter the information for this trip request.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildAssignedVehicleField(),
            _buildResponsiveFields(
              narrow,
              _buildField(
                label: 'Origin',
                controller: _originController,
                icon: Icons.trip_origin,
                validator: _required,
              ),
              _buildField(
                label: 'Destination',
                controller: _destinationController,
                icon: Icons.location_on_outlined,
                validator: _required,
              ),
            ),
            _buildField(
              label: 'Purpose of Trip',
              controller: _purposeController,
              icon: Icons.description_outlined,
              validator: _required,
            ),
            _buildDateField(
              label: 'Scheduled Departure',
              date: _departureDate,
              time: _departureTime,
              onDateChanged: (value) => setState(() => _departureDate = value),
              onTimeChanged: (value) => setState(() => _departureTime = value),
            ),
            _buildOptionalReturnField(),
            const SizedBox(height: 14),
            _buildPrimaryButton('Continue to Passengers', _nextStep),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerStep(bool narrow) {
    return _buildPanel(
      title: 'Passengers',
      subtitle: 'Add everyone who will travel on this trip.',
      child: Column(
        children: [
          if (_passengers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 34),
              decoration: BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _line),
              ),
              child: const Column(
                children: [
                  Icon(Icons.people_outline, color: _muted, size: 34),
                  SizedBox(height: 10),
                  Text(
                    'No passengers added yet.',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ..._passengers.asMap().entries.map(
              (entry) => _buildPassengerTile(entry.key, entry.value),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _showAddPassengerDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('ADD PASSENGER'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _green),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildSecondaryButton(
                  'Back',
                  () => setState(() => _step = 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildPrimaryButton('Review Ticket', _nextStep)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerTile(int index, Map<String, String> passenger) {
    final name = passenger['name'] ?? '';
    final designation = passenger['designation'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: _greenSoft,
            child: Icon(Icons.person, color: _green, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (designation.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      designation,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove passenger',
            onPressed: () => setState(() => _passengers.removeAt(index)),
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(bool narrow) {
    return _buildPanel(
      title: 'Review Trip Ticket',
      subtitle: 'Please confirm that the information below is correct.',
      child: Column(
        children: [
          _buildReviewSection('Trip Information', [
            _reviewRow('Vehicle', _vehicleDisplayName ?? ''),
            _reviewRow(
              'Route',
              '${_originController.text} to ${_destinationController.text}',
            ),
            _reviewRow('Purpose', _purposeController.text),
            _reviewRow(
              'Departure',
              '${_formatDate(_departureDate)} at ${_formatTime(_departureTime)}',
            ),
            _reviewRow(
              'Return',
              _returnDate == null || _returnTime == null
                  ? 'To be confirmed'
                  : '${_formatDate(_returnDate!)} at ${_formatTime(_returnTime!)}',
            ),
          ]),
          const SizedBox(height: 16),
          _buildReviewSection(
            'Passengers (${_passengers.length})',
            _passengers.isEmpty
                ? [
                    const Text(
                      'No passengers added.',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                  ]
                : _passengers.map((passenger) {
                    final name = passenger['name'] ?? '';
                    final designation = passenger['designation'] ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.person_outline,
                            color: _green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (designation.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      designation,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _buildSecondaryButton(
                  'Back',
                  () => setState(() => _step = 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPrimaryButton(
                  _isSubmitting ? 'Submitting...' : 'Submit Trip Ticket',
                  _isSubmitting ? null : _submitTicket,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D19332A),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 26),
          child,
        ],
      ),
    );
  }

  Widget _buildResponsiveFields(bool narrow, Widget first, Widget second) {
    if (narrow) {
      return Column(children: [first, second]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 16),
        Expanded(child: second),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _green, size: 19),
          filled: true,
          fillColor: _background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildAssignedVehicleField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Vehicle',
          prefixIcon: const Icon(
            Icons.directions_car_outlined,
            color: _muted,
            size: 19,
          ),
          filled: true,
          fillColor: const Color(0xFFEFF2F0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _line),
          ),
        ),
        child: Text(
          _vehicleDisplayName!,
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: options
            .map(
              (option) =>
                  DropdownMenuItem<String>(value: option, child: Text(option)),
            )
            .toList(),
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _green, size: 19),
          filled: true,
          fillColor: _background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required ValueChanged<DateTime> onDateChanged,
    required ValueChanged<TimeOfDay> onTimeChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: InkWell(
        onTap: () => _pickDateAndTime(date, time, onDateChanged, onTimeChanged),
        borderRadius: BorderRadius.circular(9),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(
              Icons.calendar_month_outlined,
              color: _green,
              size: 19,
            ),
            suffixIcon: const Icon(
              Icons.access_time_rounded,
              color: _green,
              size: 19,
            ),
            filled: true,
            fillColor: _background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _line),
            ),
          ),
          child: Text(
            '${_formatDate(date)}   ${_formatTime(time)}',
            style: const TextStyle(color: _ink, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionalReturnField() {
    final hasReturn = _returnDate != null && _returnTime != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: InkWell(
        onTap: _pickReturnDateAndTime,
        borderRadius: BorderRadius.circular(9),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Return Departure (Optional)',
            prefixIcon: const Icon(
              Icons.keyboard_return_rounded,
              color: _green,
              size: 19,
            ),
            suffixIcon: hasReturn
                ? IconButton(
                    tooltip: 'Clear return schedule',
                    icon: const Icon(Icons.clear, color: _green, size: 19),
                    onPressed: () => setState(() {
                      _returnDate = null;
                      _returnTime = null;
                    }),
                  )
                : const Icon(Icons.add_circle_outline, color: _green, size: 19),
            filled: true,
            fillColor: _background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _line),
            ),
          ),
          child: Text(
            hasReturn
                ? '${_formatDate(_returnDate!)}   ${_formatTime(_returnTime!)}'
                : 'To be confirmed',
            style: const TextStyle(color: _ink, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildSecondaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _greenDark,
          side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildReviewSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _greenDark,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          ...children,
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateAndTime(
    DateTime date,
    TimeOfDay time,
    ValueChanged<DateTime> onDateChanged,
    ValueChanged<TimeOfDay> onTimeChanged,
  ) async {
    final now = DateTime.now();
    final initialDate = date.isBefore(DateTime(now.year, now.month, now.day))
        ? now
        : date;
    final initialTime = time;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _green)),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;
    onDateChanged(pickedDate);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime != null && mounted) onTimeChanged(pickedTime);
  }

  Future<void> _pickReturnDateAndTime() async {
    final now = DateTime.now();
    final initialDate = _returnDate ?? _departureDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(DateTime(now.year, now.month, now.day))
          ? now
          : initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _green)),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _returnTime ?? _departureTime,
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _returnDate = pickedDate;
      _returnTime = pickedTime;
    });
  }

  Future<void> _showAddPassengerDialog() async {
    final nameController = TextEditingController();
    final designationController = TextEditingController();
    final passenger = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Passenger'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Passenger name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: designationController,
              decoration: const InputDecoration(
                labelText: 'Designation / Position',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              textCapitalization: TextCapitalization.words,
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
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, {
                  'name': nameController.text.trim(),
                  'designation': designationController.text.trim(),
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameController.dispose();
    designationController.dispose();
    if (passenger != null && mounted)
      setState(() => _passengers.add(passenger));
  }

  void _nextStep() {
    if (_vehicleId == null) return;
    if (_step == 0 && !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _step = (_step + 1).clamp(0, 2));
  }

  Future<void> _submitTicket() async {
    if (_vehicleId == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    final scheduledDeparture = DateTime(
      _departureDate.year,
      _departureDate.month,
      _departureDate.day,
      _departureTime.hour,
      _departureTime.minute,
    ).toIso8601String();
    final returnScheduledDeparture = _returnDate == null || _returnTime == null
        ? null
        : DateTime(
            _returnDate!.year,
            _returnDate!.month,
            _returnDate!.day,
            _returnTime!.hour,
            _returnTime!.minute,
          ).toIso8601String();

    try {
      await TripService.createTrip(
        origin: _originController.text.trim(),
        destination: _destinationController.text.trim(),
        purpose: _purposeController.text.trim(),
        scheduledDeparture: scheduledDeparture,
        returnScheduledDeparture: returnScheduledDeparture,
        passengers: List<Map<String, String>>.from(_passengers),
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Trip Ticket Submitted'),
          content: const Text('Your trip ticket has been sent for review.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to submit trip ticket: $error')),
      );
    }
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
  }
}
