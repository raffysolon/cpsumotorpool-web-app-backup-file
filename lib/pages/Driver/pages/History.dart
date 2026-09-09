import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/pdf_opener.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

// === Trip history page: completed driver trip tickets ===
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // --- Shared dashboard colors: use the same driver dashboard palette ---
  static const _green = AppColors.primary;
  static const _greenDark = AppColors.primaryDark;
  static const _greenSoft = AppColors.mint;
  static const _ink = AppColors.navy;
  static const _muted = AppColors.mutedDark;
  static const _line = AppColors.border;
  static const _background = AppColors.background;

  static const _dateRanges = ['All time', 'This month', 'Last 3 months'];
  String _selectedDateRange = 'All time';
  bool _isLoading = true;
  List<Trip> _trips = [];

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      final result = await TripService.getMyTrips(status: 'completed');
      if (!mounted) return;
      setState(() {
        _trips = (result is List ? result : const [])
            .whereType<Map>()
            .map((trip) => _tripFromApi(Map<String, dynamic>.from(trip)))
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

  Trip _tripFromApi(Map<String, dynamic> data) {
    final origin = (data['origin'] ?? '').toString();
    final destination = (data['destination'] ?? '').toString();
    final departure = DateTime.tryParse(
      data['scheduled_departure']?.toString() ?? '',
    );
    final distance = data['total_distance']?.toString() ?? '0';
    return Trip(
      id: (data['id'] ?? '').toString(),
      route: '$origin to $destination',
      date: departure == null ? '—' : _formatDate(departure.toLocal()),
      distance: '$distance km',
      duration: '—',
      status: 'Completed',
      movements:
          (data['movements'] is List ? data['movements'] as List : const [])
              .whereType<Map>()
              .map((movement) => Map<String, dynamic>.from(movement))
              .toList(),
    );
  }

  String _formatDate(DateTime date) =>
      '${_month(date.month)} ${date.day}, ${date.year}';

  String _month(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: AppColors.glassFill,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Trip History (${_trips.length})',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: DriverShellAtmosphere(
        child: Column(
          children: [
            _buildDateRangeFilter(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _trips.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      itemCount: _trips.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) =>
                          _buildTripCard(_trips[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Date filter: UI is ready for date-range filtering logic ---
  Widget _buildDateRangeFilter() {
    return Container(
      color: Colors.white,
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            for (final dateRange in _dateRanges) ...[
              ChoiceChip(
                label: Text(dateRange),
                selected: _selectedDateRange == dateRange,
                onSelected: (_) => setState(() {
                  _selectedDateRange = dateRange;
                }),
                selectedColor: _green,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: _selectedDateRange == dateRange ? _green : _line,
                ),
                labelStyle: TextStyle(
                  color: _selectedDateRange == dateRange
                      ? Colors.white
                      : _greenDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                showCheckmark: false,
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  // --- Completed trip card: route, summary details, and ticket actions ---
  Widget _buildTripCard(Trip trip) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      borderRadius: 16,
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
              _buildCompletedBadge(trip.status),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: _line, height: 1),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final details = [
                _buildTripDetail(
                  'DATE',
                  trip.date,
                  expanded: constraints.maxWidth >= 480,
                ),
                _buildTripDetail(
                  'DISTANCE',
                  trip.distance,
                  expanded: constraints.maxWidth >= 480,
                ),
                _buildTripDetail(
                  'DURATION',
                  trip.duration,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showTripDetails(trip),
                icon: const Icon(Icons.visibility_outlined, size: 17),
                label: const Text('View Details'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => _downloadPdf(trip.id),
                icon: const Icon(Icons.download_outlined, size: 17),
                label: const Text('Download as PDF'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _greenSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: _greenDark,
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
          Icon(Icons.history_rounded, color: _green, size: 48),
          const SizedBox(height: 12),
          const Text(
            'No completed trips yet',
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

  Future<void> _showTripDetails(Trip trip) async {
    String time(Map<String, dynamic> movement, String key) {
      final value = DateTime.tryParse('${movement[key] ?? ''}')?.toLocal();
      return value == null ? 'Not recorded' : _formatDateTime(value);
    }

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(trip.route),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${trip.status}'),
              for (final movement in trip.movements) ...[
                const SizedBox(height: 10),
                Text(
                  'Movement ${movement['movement_no']}: ${movement['origin']} to ${movement['destination']}',
                ),
                Text('Departure: ${time(movement, 'actual_departure_at')}'),
                Text('Arrival: ${time(movement, 'actual_arrival_at')}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) =>
      '${_month(value.month)} ${value.day}, ${value.year} ${value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour)}:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';

  Future<void> _downloadPdf(String tripId) async {
    try {
      final response = await TripService.getTripTicket(int.parse(tripId));
      await downloadPdf(response.bodyBytes, int.parse(tripId));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to download PDF: $error')),
        );
      }
    }
  }
}

// === Trip model: temporary completed-trip data until the backend is connected ===
class Trip {
  const Trip({
    required this.id,
    required this.route,
    required this.date,
    required this.distance,
    required this.duration,
    required this.status,
    required this.movements,
  });

  final String id;
  final String route;
  final String date;
  final String distance;
  final String duration;
  final String status;
  final List<Map<String, dynamic>> movements;
}
