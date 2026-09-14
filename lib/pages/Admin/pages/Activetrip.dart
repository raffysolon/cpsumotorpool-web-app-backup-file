// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/pdf_opener.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

// ═══════════════════════════════════════════════════════════════
// ACTIVE TRIPS PAGE
// Shows currently approved and active trips from the backend.
// Route: /active-trips
// ═══════════════════════════════════════════════════════════════

class ActiveTrip extends StatefulWidget {
  const ActiveTrip({super.key});

  @override
  State<ActiveTrip> createState() => _ActiveTripState();
}

class _ActiveTripData {
  final int id;
  final String driverName;
  final String vehicle;
  final String destination;
  final String status;

  const _ActiveTripData({
    required this.id,
    required this.driverName,
    required this.vehicle,
    required this.destination,
    required this.status,
  });

  factory _ActiveTripData.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'] is Map
        ? Map<String, dynamic>.from(json['driver'])
        : {};
    final vehicle = json['vehicle'] is Map
        ? Map<String, dynamic>.from(json['vehicle'])
        : {};

    final driverName = (driver['name'] ?? json['driver_name'] ?? '').toString();
    final vehicleName = (vehicle['name'] ?? '').toString();
    final plateNo = (vehicle['plate_no'] ?? '').toString();
    final vehicleText = [
      vehicleName,
      plateNo,
    ].where((value) => value.isNotEmpty).join(' — ');

    return _ActiveTripData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      driverName: driverName,
      vehicle: vehicleText.isNotEmpty ? vehicleText : 'N/A',
      destination: (json['destination'] ?? '').toString(),
      status: (json['effective_status'] ?? json['status'] ?? '').toString(),
    );
  }
}

class _ActiveTripState extends State<ActiveTrip> {
  List<_ActiveTripData> _trips = [];
  String _selectedStatus = 'scheduled';
  bool _isLoading = true;
  bool _isOpeningTicket = false;

  @override
  void initState() {
    super.initState();
    AdminNotificationsController.instance.refresh();
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

      final activeTrips = rawTrips
          .whereType<Map>()
          .map((trip) {
            return _ActiveTripData.fromJson(Map<String, dynamic>.from(trip));
          })
          .where((trip) {
            final status = trip.status.trim().toLowerCase();
            return status == 'scheduled' || status == 'active';
          })
          .toList();

      if (!mounted) return;
      setState(() {
        _trips = activeTrips;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load active trips: $error')),
      );
    }
  }

  List<_ActiveTripData> get _visibleTrips {
    return _trips
        .where((trip) => trip.status.trim().toLowerCase() == _selectedStatus)
        .toList();
  }

  Future<void> _openTripTicket(_ActiveTripData trip) async {
    if (_isOpeningTicket) return;

    setState(() => _isOpeningTicket = true);
    var loadingDialogOpen = true;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open trip ticket: $error')),
      );
    } finally {
      if (mounted && loadingDialogOpen) {
        loadingDialogOpen = false;
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
    return AppShell(
      currentRoute: '/active-trips',
      child: AdminPageScaffold(
        title: 'Active Trips',
        child: RefreshIndicator(
          onRefresh: _loadTrips,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(),
                const SizedBox(height: 14),
                _buildStatusFilters(),
                const SizedBox(height: 16),
                _buildTable(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scheduled and Active Trips',
          style: AppTypography.bodyStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Scheduled trips are approved and waiting for departure. Active trips have already started.',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _buildStatusFilters() {
    return Wrap(
      spacing: 8,
      children: [
        _statusFilter(
          'scheduled',
          'Scheduled',
          _trips
              .where((trip) => trip.status.toLowerCase() == 'scheduled')
              .length,
        ),
        _statusFilter(
          'active',
          'Active',
          _trips.where((trip) => trip.status.toLowerCase() == 'active').length,
        ),
      ],
    );
  }

  Widget _statusFilter(String value, String label, int count) {
    final selected = _selectedStatus == value;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => setState(() => _selectedStatus = value),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.mutedDark,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
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
          final tableWidth = constraints.maxWidth < 720
              ? 720.0
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  _buildTableHeader(),
                  const Divider(height: 1, color: AppColors.border),
                  if (_visibleTrips.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No trips found for this view.'),
                    )
                  else
                    ..._visibleTrips.asMap().entries.map((entry) {
                      final i = entry.key;
                      final trip = entry.value;
                      return Column(
                        children: [
                          _buildTableRow(trip),
                          if (i < _visibleTrips.length - 1)
                            const Divider(height: 1, color: AppColors.border),
                        ],
                      );
                    }),
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
          Expanded(flex: 4, child: Text('STATUS', style: style)),
          SizedBox(width: 120),
        ],
      ),
    );
  }

  Widget _buildTableRow(_ActiveTripData trip) {
    final status = trip.status.trim();
    final isScheduled = status.toLowerCase() == 'scheduled';
    final statusLabel = isScheduled ? 'Scheduled' : 'Active';
    final textColor = isScheduled
        ? const Color(0xFF166534)
        : const Color(0xFF0F766E);
    final bgColor = isScheduled
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFCCFBF1);
    final borderColor = isScheduled
        ? const Color(0xFF86EFAC)
        : const Color(0xFF99F6E4);

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
              trip.driverName.isNotEmpty ? trip.driverName : 'Unknown Driver',
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
              trip.vehicle.isNotEmpty ? trip.vehicle : 'N/A',
              style: const TextStyle(fontSize: 13, color: AppColors.navy),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              trip.destination.isNotEmpty ? trip.destination : 'N/A',
              style: const TextStyle(fontSize: 13, color: AppColors.navy),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
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
                    isScheduled
                        ? Icons.schedule_rounded
                        : Icons.trip_origin_rounded,
                    size: 12,
                    color: textColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: OutlinedButton.icon(
              onPressed: _isOpeningTicket ? null : () => _openTripTicket(trip),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: const Text('View Ticket'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 38),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: OutlinedButton.icon(
              onPressed: _goToMap,
              icon: const Icon(Icons.location_on_outlined, size: 16),
              label: const Text('View on Map'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 38),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
