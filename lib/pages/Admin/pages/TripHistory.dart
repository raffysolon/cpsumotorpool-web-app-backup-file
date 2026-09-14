// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/pdf_opener.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

class TripHistory extends StatelessWidget {
  const TripHistory({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/trip-history',
      child: const _TripHistoryContent(),
    );
  }
}

class _TripHistoryData {
  const _TripHistoryData({
    required this.id,
    required this.driverName,
    required this.vehicle,
    required this.origin,
    required this.destination,
    required this.purpose,
    required this.departure,
    required this.returnSchedule,
    required this.passengers,
  });

  final int id;
  final String driverName;
  final String vehicle;
  final String origin;
  final String destination;
  final String purpose;
  final String departure;
  final String returnSchedule;
  final List<Map<String, dynamic>> passengers;

  factory _TripHistoryData.fromJson(Map<String, dynamic> json) {
    final driver = _map(json['driver']);
    final vehicle = _map(json['vehicle']);
    final passengers = json['passengers'] is List
          ? (json['passengers'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    return _TripHistoryData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      driverName: _text(driver['name']),
      vehicle: [
        _text(vehicle['name']),
        _text(vehicle['plate_no']),
      ].where((value) => value.isNotEmpty).join(' - '),
      origin: _text(json['origin']),
      destination: _text(json['destination']),
      purpose: _text(json['purpose']),
      departure: _text(json['scheduled_departure']),
      returnSchedule: _dateTime(json['return_scheduled_departure']),
      passengers: passengers,
    );
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _text(dynamic value) => value?.toString() ?? '';

String _dateTime(dynamic value) {
  final date = DateTime.tryParse(_text(value))?.toLocal();
  if (date == null) return '-';
  final hour = date.hour == 0
      ? 12
      : (date.hour > 12 ? date.hour - 12 : date.hour);
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${_month(date.month)} ${date.day}, ${date.year} at $hour:$minute $period';
}

String _month(int month) => const [
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
][month - 1];

class _TripHistoryContent extends StatefulWidget {
  const _TripHistoryContent();

  @override
  State<_TripHistoryContent> createState() => _TripHistoryContentState();
}

class _TripHistoryContentState extends State<_TripHistoryContent> {
  List<_TripHistoryData> _trips = [];
  bool _loading = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    AdminNotificationsController.instance.refresh();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _loading = true);
    try {
      final result = await TripService.getAllTrips();
      final rawTrips = result is Map && result['data'] is List
          ? result['data'] as List
          : result is List
          ? result
          : const [];
      final trips = rawTrips
          .whereType<Map>()
          .where((trip) {
            return _text(trip['status']).toLowerCase() == 'completed';
          })
          .map((trip) {
            return _TripHistoryData.fromJson(Map<String, dynamic>.from(trip));
          })
          .toList();

      if (!mounted) return;
      setState(() {
        _trips = trips;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Unable to load trip history: $error', error: true);
    }
  }

  Future<void> _downloadPdf(_TripHistoryData trip) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text(
                'Downloading PDF...',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
    try {
      final response = await TripService.getTripTicket(trip.id);
      await downloadPdf(response.bodyBytes, trip.id);
      if (mounted) _message('Trip ticket PDF is ready.');
    } catch (error) {
      if (mounted) {
        _message('Unable to download trip ticket: $error', error: true);
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _downloading = false);
      }
    }
  }

  void _showDetails(_TripHistoryData trip) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Trip Details'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail('Driver', trip.driverName),
                _detail('Vehicle', trip.vehicle),
                _detail('Route', '${trip.origin} to ${trip.destination}'),
                _detail('Purpose', trip.purpose),
                _detail('Departure', trip.departure),
                _detail('Return schedule', trip.returnSchedule),
                _detail(
                  'Passengers',
                  trip.passengers.isEmpty
                      ? 'None'
                      : trip.passengers
                            .map((passenger) {
                              final name = _text(passenger['name']);
                              final designation = _text(
                                passenger['designation'],
                              );
                              return designation.isEmpty
                                  ? name
                                  : '$name ($designation)';
                            })
                            .join(', '),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: _downloading ? null : () => _downloadPdf(trip),
            icon: _downloading
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined, size: 17),
            label: Text(_downloading ? 'Downloading...' : 'Download PDF'),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: AppColors.navy, fontSize: 14),
          children: [
            TextSpan(
              text: '$label\n',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value.isEmpty ? '-' : value),
          ],
        ),
      ),
    );
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadTrips,
          child: AdminPageScaffold(
            title: 'Trip History',
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Completed Trips',
                        style: AppTypography.bodyStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        '${_trips.length} records',
                        style: AppTypography.bodyStyle(
                          fontSize: 13,
                          color: AppColors.mutedDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _table(),
                    ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _table() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 850
              ? 850.0
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _header(),
                  const Divider(height: 1, color: AppColors.border),
                  if (_trips.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Text('No completed trips found.'),
                    )
                  else
                    ..._trips.asMap().entries.map(
                      (entry) => Column(
                        children: [
                          _row(entry.value),
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

  Widget _header() {
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
          Expanded(flex: 3, child: Text('VEHICLE', style: style)),
          Expanded(flex: 5, child: Text('DESTINATION', style: style)),
          Expanded(flex: 3, child: Text('DATE', style: style)),
          SizedBox(width: 260),
        ],
      ),
    );
  }

  Widget _row(_TripHistoryData trip) {
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
              trip.driverName.isEmpty ? 'Unknown Driver' : trip.driverName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              trip.vehicle.isEmpty ? 'N/A' : trip.vehicle,
              style: const TextStyle(fontSize: 13, color: AppColors.navy),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              trip.destination.isEmpty ? 'N/A' : trip.destination,
              style: const TextStyle(fontSize: 13, color: AppColors.navy),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              trip.departure,
              style: const TextStyle(fontSize: 13, color: AppColors.navy),
            ),
          ),
          SizedBox(
            width: 260,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showDetails(trip),
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text('View Details'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
