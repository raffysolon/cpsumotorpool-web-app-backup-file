import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    try {
      final result = await TripService.getAllTrips();
      final rawTrips = result is Map && result['data'] is List
          ? result['data'] as List
          : result is List
              ? result
              : const [];
      if (!mounted) return;
      setState(() {
        _trips = rawTrips.whereType<Map>().map((trip) {
          return _TripRequestData.fromJson(Map<String, dynamic>.from(trip));
        }).toList();
        _isLoading = false;
      });
    } catch (error) {
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
        onViewTicket: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _TripTicketPreviewPage(trip: trip)),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
              Text('Trip Requests', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.navy)),
              SizedBox(height: 2),
              Text('Province of Negros Occidental — Motorpool Division', style: TextStyle(fontSize: 13, color: AppColors.mutedDark)),
            ],
          ),
          Spacer(),
          Icon(Icons.notifications_none_rounded, size: 24, color: AppColors.navy),
          SizedBox(width: 18),
          CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white, size: 20)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    final pending = _trips.where((trip) => trip.status == 'Pending').length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Trip Requests', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.navy)),
        Text('$pending pending', style: const TextStyle(fontSize: 13, color: AppColors.mutedDark)),
      ],
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 760 ? 760.0 : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _buildTableHeader(),
                  const Divider(height: 1, color: AppColors.border),
                  if (_trips.isEmpty)
                    const Padding(padding: EdgeInsets.all(28), child: Text('No trip requests found.'))
                  else
                    ..._trips.asMap().entries.map((entry) => Column(
                          children: [
                            _buildTableRow(entry.value),
                            if (entry.key < _trips.length - 1) const Divider(height: 1, color: AppColors.border),
                          ],
                        )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableHeader() {
    const style = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mutedDark, letterSpacing: 0.8);
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        SizedBox(width: 36),
        SizedBox(width: 12),
        Expanded(flex: 5, child: Text('DRIVER NAME', style: style)),
        Expanded(flex: 6, child: Text('VEHICLE', style: style)),
        Expanded(flex: 6, child: Text('DESTINATION', style: style)),
        Expanded(flex: 5, child: Text('DEPARTURE', style: style)),
        Expanded(flex: 4, child: Text('STATUS', style: style)),
        SizedBox(width: 110),
      ]),
    );
  }

  Widget _buildTableRow(_TripRequestData trip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: const Icon(Icons.person_outline, size: 20, color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(flex: 5, child: Text(trip.driverName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy))),
        Expanded(flex: 6, child: Text(trip.vehicle, style: const TextStyle(fontSize: 13, color: AppColors.navy))),
        Expanded(flex: 6, child: Text(trip.destination, style: const TextStyle(fontSize: 13, color: AppColors.navy))),
        Expanded(flex: 5, child: Text(trip.departure, style: const TextStyle(fontSize: 13, color: AppColors.navy))),
        Expanded(flex: 4, child: _StatusBadge(status: trip.status)),
        SizedBox(width: 110, child: OutlinedButton(onPressed: () => _showDetails(trip), child: const Text('View Details'))),
      ]),
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
    final textColor = approved ? const Color(0xFF16A34A) : denied ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    final bgColor = approved ? const Color(0xFFDCFCE7) : denied ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

class _TripDetailDialog extends StatelessWidget {
  const _TripDetailDialog({required this.trip, required this.onApprove, required this.onDeny, required this.onViewTicket});

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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Trip Request Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
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
            _section('Passengers (${trip.passengers.length})', trip.passengers.isEmpty
                ? [const Padding(padding: EdgeInsets.all(12), child: Text('No passengers added.'))]
                : trip.passengers.map((passenger) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(passenger.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy))),
                        Expanded(flex: 2, child: Text(passenger.designation, style: const TextStyle(color: AppColors.mutedDark))),
                      ]),
                    )).toList()),
            const SizedBox(height: 22),
            OutlinedButton.icon(onPressed: onViewTicket, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('View Trip Ticket')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: onDeny, style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text('Deny'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(onPressed: onApprove, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: const Text('Approve'))),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy)),
      const SizedBox(height: 10),
      Container(decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: Column(children: children)),
    ]);
  }

  Widget _info(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.mutedDark))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy))),
    ]));
  }
}

class _TripTicketPreviewPage extends StatefulWidget {
  const _TripTicketPreviewPage({required this.trip});

  final _TripRequestData trip;

  @override
  State<_TripTicketPreviewPage> createState() => _TripTicketPreviewPageState();
}

class _TripTicketPreviewPageState extends State<_TripTicketPreviewPage> {
  bool _loading = true;
  String? _error;
  int _responseSize = 0;

  @override
  void initState() {
    super.initState();
    _fetchTicket();
  }

  Future<void> _fetchTicket() async {
    try {
      final response = await TripService.getTripTicket(widget.trip.id);
      if (!mounted) return;
      setState(() {
        _responseSize = response.bodyBytes.length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Official Trip Ticket')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Unable to load trip ticket: $_error'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 760),
                      padding: const EdgeInsets.all(40),
                      color: Colors.white,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Center(child: Text('PROVINCIAL GOVERNMENT OF NEGROS OCCIDENTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                        const SizedBox(height: 6),
                        const Center(child: Text('MOTORPOOL DIVISION\nTRIP TICKET', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                        const Divider(height: 32),
                        _ticketRow('Driver Name', widget.trip.driverName),
                        _ticketRow('Vehicle', widget.trip.vehicle),
                        _ticketRow('Origin', widget.trip.origin),
                        _ticketRow('Destination', widget.trip.destination),
                        _ticketRow('Purpose', widget.trip.purpose),
                        _ticketRow('Scheduled Departure', widget.trip.departure),
                        _ticketRow('Status', widget.trip.status),
                        const SizedBox(height: 24),
                        const Text('PASSENGERS', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Table(border: TableBorder.all(color: Colors.black54), columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2)}, children: [
                          const TableRow(children: [_TicketCell('Name', bold: true), _TicketCell('Signature', bold: true)]),
                          ...widget.trip.passengers.map((passenger) => TableRow(children: [_TicketCell(passenger.name), const _TicketCell('')])),
                        ]),
                        const SizedBox(height: 24),
                        Text('Official ticket response fetched ($_responseSize bytes).', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ]),
                    ),
                  ),
                ),
    );
  }

  Widget _ticketRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
      SizedBox(width: 180, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
      Expanded(child: Text(value)),
    ]));
  }
}

class _TicketCell extends StatelessWidget {
  const _TicketCell(this.value, {this.bold = false});

  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(8), child: Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)));
  }
}
