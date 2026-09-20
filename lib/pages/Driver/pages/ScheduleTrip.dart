import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/pdf_opener.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

// === Scheduled trips page: approved trips that have not started ===
class ScheduleTripPage extends StatefulWidget {
  const ScheduleTripPage({super.key});

  @override
  State<ScheduleTripPage> createState() => _ScheduleTripPageState();
}

class _ScheduleTripPageState extends State<ScheduleTripPage>
    with WidgetsBindingObserver {
  static const _green = AppColors.primary;
  static const _greenDark = AppColors.primaryDark;
  static const _greenSoft = AppColors.mint;
  static const _ink = AppColors.navy;
  static const _muted = AppColors.mutedDark;
  static const _line = AppColors.border;
  static const _background = AppColors.background;

  bool _isLoading = true;
  bool _isPrintingTicket = false;
  bool _isPageVisible = true;
  bool _isRefreshRunning = false;
  List<Trip> _trips = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTrips();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || !_isPageVisible || _isRefreshRunning) {
        return;
      }
      _loadTrips(background: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isPageVisible = true;
      if (!_isRefreshRunning) {
        _loadTrips(background: true);
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _isPageVisible = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadTrips({bool background = false}) async {
    if (background) {
      if (_isRefreshRunning || !mounted || !_isPageVisible) {
        return;
      }
      _isRefreshRunning = true;
    } else if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final result = await TripService.getMyTrips();
      final rawTrips = result is List ? result : const [];
      final nextTrips = rawTrips.whereType<Map>().where((trip) {
        final status = (trip['effective_status'] ?? trip['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        return status == 'scheduled';
      }).map<Trip>((trip) {
        final map = trip as Map<String, dynamic>;
        final vehicle = map['vehicle'] is Map
          ? Map<String, dynamic>.from(map['vehicle'] as Map)
          : const <String, dynamic>{};
        final vehicleLabel = _vehicleLabel(vehicle);
        final scheduled = map['scheduled_departure']?.toString();
        final route = '${map['origin'] ?? ''} to ${map['destination'] ?? ''}'
            .trim();
        return Trip(
          id: (map['id'] ?? 0).toString(),
          route: route.isEmpty ? 'Trip request' : route,
          status: 'Scheduled',
          vehicle: vehicleLabel,
          departureTime: _formatDeparture(scheduled),
          expectedArrival: '—',
          scheduledDeparture: DateTime.tryParse(scheduled ?? '') ?? DateTime.now(),
        );
      }).toList();

      if (!mounted) return;
      if (!background || _hasTripsChanged(nextTrips)) {
        setState(() {
          _trips = nextTrips;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (background) return;
      if (!mounted) return;
      setState(() {
        _trips = [];
        _isLoading = false;
      });
    } finally {
      if (background) {
        _isRefreshRunning = false;
      }
    }
  }

  String _vehicleLabel(Map<String, dynamic> vehicle) {
    final name = vehicle['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    final plateNumber = vehicle['plate_no']?.toString().trim() ?? '';
    return plateNumber.isNotEmpty ? plateNumber : '—';
  }

  bool _hasTripsChanged(List<Trip> nextTrips) {
    if (_trips.length != nextTrips.length) return true;
    for (var i = 0; i < nextTrips.length; i++) {
      final current = _trips[i];
      final next = nextTrips[i];
      if (current.id != next.id ||
          current.route != next.route ||
          current.status != next.status ||
          current.vehicle != next.vehicle ||
          current.departureTime != next.departureTime ||
          current.scheduledDeparture != next.scheduledDeparture) {
        return true;
      }
    }
    return false;
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

  List<Trip> get _upcomingTrips {
    return _trips..sort(
      (first, second) =>
          first.scheduledDeparture.compareTo(second.scheduledDeparture),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trips = _upcomingTrips;
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _background,
          appBar: AppBar(
            backgroundColor: AppColors.glassFill,
            foregroundColor: _ink,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scheduled Trips',
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
                    '${_trips.length}',
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
          body: DriverShellAtmosphere(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : trips.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    itemCount: trips.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) => _buildTripCard(trips[index]),
                  ),
          ),
        ),
        if (_isPrintingTicket)
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

  Widget _buildTripCard(Trip trip) {
    final departingSoon = trip.scheduledDeparture.isBefore(
      DateTime.now().add(const Duration(hours: 24)),
    );
    final now = DateTime.now();
    final sameDate =
        trip.scheduledDeparture.year == now.year &&
        trip.scheduledDeparture.month == now.month &&
        trip.scheduledDeparture.day == now.day;
    final canStart = sameDate && !now.isBefore(trip.scheduledDeparture);

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
              _buildStatusBadge(),
            ],
          ),
          if (departingSoon) ...[
            const SizedBox(height: 10),
            _buildDepartingSoonLabel(),
          ],
          const SizedBox(height: 16),
          const Divider(color: _line, height: 1),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final details = [
                _buildTripDetail(
                  'VEHICLE',
                  trip.vehicle,
                  expanded: constraints.maxWidth >= 560,
                ),
                _buildTripDetail(
                  'SCHEDULED DEPARTURE',
                  trip.departureTime,
                  expanded: constraints.maxWidth >= 560,
                ),
                _buildTripDetail(
                  'EXPECTED ARRIVAL',
                  trip.expectedArrival,
                  expanded: constraints.maxWidth >= 560,
                ),
              ];
              return constraints.maxWidth < 560
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: details,
                    )
                  : Row(children: details);
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: canStart ? () => _startTrip(trip.id) : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('Start Trip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canStart ? _green : Colors.grey.shade300,
                  foregroundColor: Colors.black,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _navigateToTripSummary(trip.id),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View Details'),
                style: _actionButtonStyle(),
              ),
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
                      color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: TextButton.icon(
                  onPressed: () => _printTripTicket(trip.id),
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
                  icon: const Icon(Icons.print_outlined, size: 18),
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
          ),
        ],
      ),
    );
  }

  ButtonStyle _actionButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.black,
      side: const BorderSide(color: _green),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _greenSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'SCHEDULED',
        style: TextStyle(
          color: _greenDark,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildDepartingSoonLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _greenSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_outlined, color: _greenDark, size: 14),
          SizedBox(width: 5),
          Text(
            'Departing soon',
            style: TextStyle(
              color: _greenDark,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 2,
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
          Icon(Icons.schedule_outlined, color: _green, size: 48),
          const SizedBox(height: 12),
          const Text(
            'No upcoming trips scheduled',
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
      (trip) => trip.id == tripId,
      orElse: () => _trips.first,
    );
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
              _TextRow(label: 'Scheduled Departure', value: trip.departureTime),
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

  Future<void> _startTrip(String tripId) async {
    try {
      await TripService.startTrip(int.tryParse(tripId) ?? 0);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Trip started. Departure time was recorded automatically.',
          ),
        ),
      );
      await _loadTrips();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start trip: $error')));
    }
  }

  Future<void> _printTripTicket(String tripId) async {
    if (_isPrintingTicket) return;
    setState(() => _isPrintingTicket = true);
    try {
      final response = await TripService.getTripTicket(
        int.tryParse(tripId) ?? 0,
      );
      if (!mounted) return;
      await openPdf(response.bodyBytes, int.tryParse(tripId) ?? 0);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to print trip ticket: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPrintingTicket = false);
      }
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

class Trip {
  const Trip({
    required this.id,
    required this.route,
    required this.status,
    required this.vehicle,
    required this.departureTime,
    required this.expectedArrival,
    required this.scheduledDeparture,
  });

  final String id;
  final String route;
  final String status;
  final String vehicle;
  final String departureTime;
  final String expectedArrival;
  final DateTime scheduledDeparture;
}
