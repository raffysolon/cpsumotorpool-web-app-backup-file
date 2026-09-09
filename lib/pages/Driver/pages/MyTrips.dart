import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/pdf_opener.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';

// === My trips page: filterable list of driver trip requests ===
class MyTripsPage extends StatefulWidget {
  const MyTripsPage({super.key});

  @override
  State<MyTripsPage> createState() => _MyTripsPageState();
}

class _MyTripsPageState extends State<MyTripsPage> {
  static const _green = Color(0xFF0B8F5A);
  static const _greenDark = Color(0xFF087448);
  static const _greenSoft = Color(0xFFE8F7F0);
  static const _ink = Color(0xFF19332A);
  static const _muted = Color(0xFF71827B);
  static const _line = Color(0xFFDCE9E2);
  static const _background = Color(0xFFF7FAF8);

  static const _filters = ['All', 'Pending', 'Approved', 'Denied'];

  bool _isLoading = true;
  bool _isOpeningTicket = false;
  String _selectedFilter = 'All';
  List<Trip> _trips = [];

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      final result = await TripService.getMyTrips();
      final rawTrips = result is List ? result : const [];
      if (!mounted) return;
      setState(() {
        _trips = rawTrips
            .where((trip) {
              final map = trip as Map<String, dynamic>;
              final status =
                  (map['effective_status'] ?? map['status'] ?? 'pending')
                      .toString()
                      .trim()
                      .toLowerCase();
              return status != 'active' && status != 'completed';
            })
            .map<Trip>((trip) {
              final map = trip as Map<String, dynamic>;
              final rawStatus =
                  (map['effective_status'] ?? map['status'] ?? 'pending')
                      .toString();
              final status = _normalizeStatus(rawStatus);
              final vehicle = map['vehicle'] is Map
                  ? map['vehicle'] as Map<String, dynamic>
                  : const {};
              final vehicleLabel =
                  vehicle['plate_no']?.toString() ??
                  vehicle['name']?.toString() ??
                  '—';
              final scheduledDeparture = map['scheduled_departure']?.toString();
              return Trip(
                id: (map['id'] ?? 0).toString(),
                route: '${map['origin'] ?? ''} to ${map['destination'] ?? ''}'
                    .trim(),
                status: status,
                vehicle: vehicleLabel,
                departureTime: _formatDeparture(scheduledDeparture),
                scheduledBadge: _scheduledBadgeLabel(
                  status,
                  scheduledDeparture,
                ),
              );
            })
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _trips = [];
        _isLoading = false;
      });
    }
  }

  String _normalizeStatus(String raw) {
    final value = raw.trim().toLowerCase();
    switch (value) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'scheduled':
        return 'Scheduled';
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'denied':
        return 'Denied';
      default:
        return value.isEmpty
            ? 'Pending'
            : value[0].toUpperCase() + value.substring(1);
    }
  }

  String? _scheduledBadgeLabel(String status, String? scheduledDeparture) {
    if (status != 'Approved' ||
        scheduledDeparture == null ||
        scheduledDeparture.isEmpty) {
      return null;
    }

    final departureDate = DateTime.tryParse(scheduledDeparture)?.toLocal();
    if (departureDate == null) return null;

    final today = DateTime.now();
    final departureDay = DateTime(
      departureDate.year,
      departureDate.month,
      departureDate.day,
    );
    final todayDay = DateTime(today.year, today.month, today.day);

    if (departureDay.isAtSameMomentAs(todayDay)) {
      return 'Departing Today';
    }

    if (departureDay.isAfter(todayDay)) {
      return 'Scheduled';
    }

    return null;
  }

  String _formatDeparture(String? value) {
    if (value == null || value.isEmpty) return '—';
    try {
      final parsed = DateTime.tryParse(value)?.toLocal();
      if (parsed == null) return value;
      final month = _monthShort(parsed.month);
      final day = parsed.day;
      final year = parsed.year;
      final hour = parsed.hour;
      final minute = parsed.minute.toString().padLeft(2, '0');
      final suffix = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$month $day, $year • $formattedHour:$minute $suffix';
    } catch (_) {
      return value;
    }
  }

  String _monthShort(int month) {
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
    return months[month - 1];
  }

  List<Trip> get _filteredTrips {
    if (_selectedFilter == 'All') return _trips;
    return _trips.where((trip) => trip.status == _selectedFilter).toList();
  }

  int get _visibleTripCount => _trips.length;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: _ink,
            elevation: 0,
            surfaceTintColor: Colors.white,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'My Trips',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _greenSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$_visibleTripCount',
                    style: const TextStyle(
                      color: _greenDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildFilterTabs(),
                    Expanded(
                      child: _filteredTrips.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                32,
                              ),
                              itemCount: _filteredTrips.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                return _buildTripCard(_filteredTrips[index]);
                              },
                            ),
                    ),
                  ],
                ),
        ),
        if (_isOpeningTicket)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0x66000000),
              child: Center(
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 28,
                    ),
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
                          'Opening trip ticket...',
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

  // --- Filter tabs: select which trip statuses are visible ---
  Widget _buildFilterTabs() {
    return Container(
      color: Colors.white,
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            for (final filter in _filters) ...[
              _buildFilterTab(filter),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String filter) {
    final selected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(filter),
      selected: selected,
      onSelected: (_) => setState(() => _selectedFilter = filter),
      selectedColor: _green,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? _green : _line),
      labelStyle: TextStyle(
        color: selected ? Colors.white : _greenDark,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    );
  }

  // --- Trip card: route, status, details, and explicit summary action ---
  Widget _buildTripCard(Trip trip) {
    return InkWell(
      onTap: () => _showTripDetails(trip),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    trip.route,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusBadge(trip.status),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: _line, height: 1),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final details = [
                  _buildTripDetail(
                    'VEHICLE',
                    trip.vehicle,
                    expanded: constraints.maxWidth >= 480,
                  ),
                  _buildTripDetail(
                    'DEPARTURE',
                    trip.departureTime,
                    expanded: constraints.maxWidth >= 480,
                  ),
                  _buildTripDetail(
                    'STATUS',
                    trip.status,
                    expanded: constraints.maxWidth >= 480,
                  ),
                ];
                return constraints.maxWidth < 480
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: details,
                      )
                    : Row(children: details);
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _navigateToTripSummary(trip.id),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'View Details',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (trip.status == 'Approved' ||
                      trip.status == 'Scheduled' ||
                      trip.status == 'Active' ||
                      trip.status == 'Completed') ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF334155)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0F172A,
                            ).withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextButton.icon(
                        onPressed: () => _openTripTicket(trip.id),
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
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: const Text(
                          'View Trip Ticket',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, {bool accent = false}) {
    final denied = status == 'Denied';
    final isScheduledLabel =
        accent && (status == 'Departing Today' || status == 'Scheduled');
    final color = denied
        ? Colors.red.shade700
        : isScheduledLabel
        ? Colors.orange.shade900
        : _greenDark;
    final background = denied
        ? Colors.red.shade50
        : isScheduledLabel
        ? Colors.orange.shade50
        : _greenSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildTripDetail(String label, String value, {bool expanded = true}) {
    final detail = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _greenDark,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
    return expanded ? Expanded(child: detail) : detail;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, color: _green, size: 48),
          const SizedBox(height: 12),
          const Text(
            'No trips found',
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToTripSummary(String tripId) async {
    final trip = _trips.firstWhere(
      (item) => item.id == tripId,
      orElse: () => _trips.first,
    );
    await _showTripDetails(trip);
  }

  Future<void> _showTripDetails(Trip trip) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            trip.route,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TextRow(label: 'Status', value: trip.status),
              _TextRow(label: 'Vehicle', value: trip.vehicle),
              _TextRow(label: 'Departure', value: trip.departureTime),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openTripTicket(String tripId) async {
    if (_isOpeningTicket) return;
    setState(() => _isOpeningTicket = true);
    try {
      final id = int.tryParse(tripId);
      if (id == null) throw Exception('Invalid trip ID');
      final response = await TripService.getTripTicket(id);
      if (!mounted) return;
      setState(() => _isOpeningTicket = false);
      await openPdf(response.bodyBytes, id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open trip ticket: $error')),
      );
      setState(() => _isOpeningTicket = false);
    }
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF71827B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF19332A),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// === Trip model: temporary sample data until the backend is connected ===
class Trip {
  const Trip({
    required this.id,
    required this.route,
    required this.status,
    required this.vehicle,
    required this.departureTime,
    this.scheduledBadge,
  });

  final String id;
  final String route;
  final String status;
  final String vehicle;
  final String departureTime;
  final String? scheduledBadge;
}
