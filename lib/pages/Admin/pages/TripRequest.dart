import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';
import 'package:cpsumotorpooladmin/services/pdf_opener.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

class TripRequest extends StatelessWidget {
  const TripRequest({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/trip-request',
      child: const _TripRequestContent(),
    );
  }
}

class _Passenger {
  const _Passenger({required this.name, required this.designation});

  final String name;
  final String designation;
}

class _TripRequestData {
  const _TripRequestData({
    required this.id,
    required this.driverName,
    required this.vehicle,
    required this.origin,
    required this.destination,
    required this.purpose,
    required this.departure,
    required this.status,
    required this.passengers,
  });

  final int id;
  final String driverName;
  final String vehicle;
  final String origin;
  final String destination;
  final String purpose;
  final String departure;
  final String status;
  final List<_Passenger> passengers;

  factory _TripRequestData.fromJson(Map<String, dynamic> json) {
    final driver = _asMap(json['driver']);
    final vehicle = _asMap(json['vehicle']);
    final rawPassengers = json['passengers'] is List
        ? json['passengers'] as List
        : const [];

    return _TripRequestData(
      id: int.tryParse('${json['id'] ?? ''}') ?? 0,
      driverName: _text(driver['name'] ?? json['driver_name']),
      vehicle: _vehicleText(vehicle),
      origin: _text(json['origin']),
      destination: _text(json['destination']),
      purpose: _text(json['purpose']),
      departure: _text(json['scheduled_departure']),
      status: _statusText(json['status']),
      passengers: rawPassengers.whereType<Map>().map((passenger) {
        return _Passenger(
          name: _text(passenger['name']),
          designation: _text(passenger['designation']),
        );
      }).toList(),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : {};
}

String _text(dynamic value) => value?.toString() ?? '';

String _vehicleText(Map<String, dynamic> vehicle) {
  final name = _text(vehicle['name']);
  final plate = _text(vehicle['plate_no']);
  return [name, plate].where((value) => value.isNotEmpty).join(' — ');
}

String _statusText(dynamic value) {
  switch (_text(value).toLowerCase()) {
    case 'approved':
      return 'Approved';
    case 'denied':
    case 'rejected':
      return 'Denied';
    default:
      return 'Pending';
  }
}

class _TripRequestContent extends StatefulWidget {
  const _TripRequestContent();

  @override
  State<_TripRequestContent> createState() => _TripRequestContentState();
}

class _TripRequestContentState extends State<_TripRequestContent> {
  List<_TripRequestData> _trips = [];
  bool _isLoading = true;
  bool _isOpeningTicket = false;

  @override
  void initState() {
    super.initState();
    AdminNotificationsController.instance.refresh();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    debugPrint('TripRequest._loadTrips(): starting fetch');
    setState(() => _isLoading = true);
    try {
      final result = await TripService.getAllTrips();
      debugPrint('TripRequest._loadTrips(): raw result=$result');
      final rawTrips = result is Map && result['data'] is List
          ? result['data'] as List
          : result is List
          ? result
          : const [];

      final filteredTrips = rawTrips.whereType<Map>().where((trip) {
        final status = (trip['status'] ?? '').toString().trim().toLowerCase();
        return status == 'pending';
      }).toList();

      if (!mounted) return;
      setState(() {
        _trips = filteredTrips.map((trip) {
          return _TripRequestData.fromJson(Map<String, dynamic>.from(trip));
        }).toList();
        debugPrint(
          'TripRequest._loadTrips(): parsed trip count=${_trips.length}',
        );
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('TripRequest._loadTrips(): error=$error');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Unable to load trip requests: $error');
    }
  }

  Future<void> _changeStatus(
    BuildContext dialogContext,
    _TripRequestData trip,
    bool approve,
  ) async {
    try {
      if (approve) {
        await TripService.approveTrip(trip.id);
      } else {
        await TripService.denyTrip(trip.id);
      }
      if (!mounted || !dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      _showMessage(approve ? 'Trip approved' : 'Trip denied');
      await _loadTrips();
    } catch (error) {
      if (!mounted) return;
      _showError('Unable to ${approve ? 'approve' : 'deny'} trip: $error');
    }
  }

  void _showDetails(_TripRequestData trip) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _TripDetailDialog(
        trip: trip,
        onApprove: () => _changeStatus(dialogContext, trip, true),
        onDeny: () => _changeStatus(dialogContext, trip, false),
        onViewTicket: () => _openTripTicketPdf(trip),
      ),
    );
  }

  Future<void> _openTripTicketPdf(_TripRequestData trip) async {
    if (_isOpeningTicket) return;
    setState(() => _isOpeningTicket = true);
    showDialog<void>(
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
      debugPrint('TripRequest._openTripTicketPdf(): error=$error');
      _showError('Error: $error');
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isOpeningTicket = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadTrips,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(),
                            const SizedBox(height: 16),
                            _buildTable(),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
        if (_isOpeningTicket)
          Positioned.fill(
            child: ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 42,
                          height: 42,
                          child: CircularProgressIndicator(strokeWidth: 4),
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Generating trip ticket...',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Please wait',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
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
              Text(
                'Trip Requests',
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

  Widget _buildSectionHeader() {
    final pending = _trips.where((trip) => trip.status == 'Pending').length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Trip Requests',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        Text(
          '$pending pending',
          style: const TextStyle(fontSize: 13, color: AppColors.mutedDark),
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
          final width = constraints.maxWidth < 760
              ? 760.0
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _buildTableHeader(),
                  const Divider(height: 1, color: AppColors.border),
                  if (_trips.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Text('No trip requests found.'),
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
          SizedBox(width: 36),
          SizedBox(width: 12),
          Expanded(flex: 5, child: Text('DRIVER NAME', style: style)),
          Expanded(flex: 6, child: Text('VEHICLE', style: style)),
          Expanded(flex: 6, child: Text('DESTINATION', style: style)),
          Expanded(flex: 5, child: Text('DEPARTURE', style: style)),
          Expanded(flex: 4, child: Text('STATUS', style: style)),
          SizedBox(width: 110),
        ],
      ),
    );
  }

  Widget _buildTableRow(_TripRequestData trip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: const Icon(
              Icons.person_outline,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              trip.driverName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              trip.vehicle,
              style: const TextStyle(fontSize: 13, color: AppColors.navy),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              trip.destination,
              style: const TextStyle(fontSize: 13, color: AppColors.navy),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              trip.departure,
              style: const TextStyle(fontSize: 13, color: AppColors.navy),
            ),
          ),
          Expanded(flex: 4, child: _StatusBadge(status: trip.status)),
          const SizedBox(width: 12),
          SizedBox(
            width: 128,
            child: _ViewDetailsButton(onPressed: () => _showDetails(trip)),
          ),
        ],
      ),
    );
  }
}

class _ViewDetailsButton extends StatelessWidget {
  const _ViewDetailsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(0, 38),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.visibility_outlined, size: 16),
        label: const Text(
          'View Details',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final approved = status == 'Approved';
    final denied = status == 'Denied';
    final icon = approved
        ? Icons.check_circle_rounded
        : denied
        ? Icons.cancel_rounded
        : Icons.pending_rounded;
    final textColor = approved
        ? const Color(0xFF166534)
        : denied
        ? const Color(0xFFB91C1C)
        : const Color(0xFF92400E);
    final bgColor = approved
        ? const Color(0xFFDCFCE7)
        : denied
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFFEF3C7);
    final borderColor = approved
        ? const Color(0xFF86EFAC)
        : denied
        ? const Color(0xFFFCA5A5)
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
          Icon(icon, size: 12, color: textColor),
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
      child: Card(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
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

class _TripDetailDialog extends StatelessWidget {
  const _TripDetailDialog({
    required this.trip,
    required this.onApprove,
    required this.onDeny,
    required this.onViewTicket,
  });

  final _TripRequestData trip;
  final VoidCallback onApprove;
  final VoidCallback onDeny;
  final VoidCallback onViewTicket;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trip Request Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _section('Trip Information', [
                _info('Driver Name', trip.driverName),
                _info('Vehicle', trip.vehicle),
                _info('Origin', trip.origin),
                _info('Destination', trip.destination),
                _info('Purpose', trip.purpose),
                _info('Scheduled Departure', trip.departure),
                _info('Status', trip.status),
              ]),
              const SizedBox(height: 18),
              _section(
                'Passengers (${trip.passengers.length})',
                trip.passengers.isEmpty
                    ? [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No passengers added.'),
                        ),
                      ]
                    : trip.passengers
                          .map(
                            (passenger) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      passenger.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      passenger.designation,
                                      style: const TextStyle(
                                        color: AppColors.mutedDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
              ),
              const SizedBox(height: 22),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextButton.icon(
                  onPressed: onViewTicket,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text(
                    'View Trip Ticket',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDeny,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(
                          color: Color(0xFFFCA5A5),
                          width: 1.2,
                        ),
                        backgroundColor: const Color(0xFFFEF2F2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Deny',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shadowColor: AppColors.primary.withValues(alpha: 0.25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Approve',
                        style: TextStyle(fontWeight: FontWeight.w700),
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

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
