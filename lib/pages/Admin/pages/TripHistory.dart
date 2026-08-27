import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

// ═══════════════════════════════════════════════════════════════
// TRIP HISTORY PAGE
// Shows completed trips with download PDF option
// Route: /trip-history
// ═══════════════════════════════════════════════════════════════

// === Trip history page: completed and past trip records ===
// ─── Page Wrapper ───
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

// ─── Data Model ───
class _TripHistoryData {
  final String driverName;
  final String vehicle;
  final String destination;
  final String date;
  final String duration;

  const _TripHistoryData({
    required this.driverName,
    required this.vehicle,
    required this.destination,
    required this.date,
    required this.duration,
  });
}

// ─── Mock Data (replace with API/database later) ───
const _mockHistory = [
  _TripHistoryData(
    driverName: 'Ramon Dela Cruz',
    vehicle: 'SJA 4421',
    destination: 'Bacolod to Silay',
    date: '2026-08-15',
    duration: '1h 10m',
  ),
  _TripHistoryData(
    driverName: 'Maria Santos',
    vehicle: 'SJB 8832',
    destination: 'Bacolod to Kabankalan',
    date: '2026-08-14',
    duration: '2h 30m',
  ),
  _TripHistoryData(
    driverName: 'Jose Reyes',
    vehicle: 'SJC 1194',
    destination: 'Bacolod to Sagay',
    date: '2026-08-13',
    duration: '3h 15m',
  ),
  _TripHistoryData(
    driverName: 'Eduardo Flores',
    vehicle: 'SJE 2289',
    destination: 'Bacolod to La Carlota',
    date: '2026-08-12',
    duration: '1h 45m',
  ),
  _TripHistoryData(
    driverName: 'Carlo Mendoza',
    vehicle: 'SJA 1123',
    destination: 'Bacolod to Victorias',
    date: '2026-08-11',
    duration: '1h 00m',
  ),
];

// ─── Main Content Layout ───
class _TripHistoryContent extends StatelessWidget {
  const _TripHistoryContent();

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
                _buildSectionHeader(),
                const SizedBox(height: 16),
                _buildTable(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Top Bar (Title + Notification + Profile) ───
  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Trip History',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              SizedBox(height: 2),
              Text('Province of Negros Occidental — Motorpool Division',
                  style: TextStyle(fontSize: 13, color: AppColors.mutedDark)),
            ],
          ),
          const Spacer(),
          // Notification bell
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded,
                    size: 24, color: AppColors.navy),
                onPressed: () {},
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                      color: Colors.amber, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          // Profile avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  // ─── Section Header ("Completed Trips" + record count) ───
  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Completed Trips',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.navy)),
        Text('${_mockHistory.length} records',
            style: const TextStyle(fontSize: 13, color: AppColors.mutedDark)),
      ],
    );
  }

  // ─── Table Container ───
  Widget _buildTable() {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.mutedDark,
      letterSpacing: 0.8,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 780 ? 780.0 : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
          // ─── Table Header Row ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: const [
                SizedBox(width: 36),
                SizedBox(width: 12),
                Expanded(flex: 5, child: Text('DRIVER NAME', style: headerStyle)),
                Expanded(flex: 3, child: Text('VEHICLE', style: headerStyle)),
                Expanded(flex: 5, child: Text('DESTINATION', style: headerStyle)),
                Expanded(flex: 3, child: Text('DATE', style: headerStyle)),
                Expanded(flex: 3, child: Text('DURATION', style: headerStyle)),
                SizedBox(width: 130),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // ─── Table Data Rows ───
              ..._mockHistory.asMap().entries.map((entry) {
                final i = entry.key;
                final trip = entry.value;
                return Column(
                  children: [
                    _buildRow(trip),
                    if (i < _mockHistory.length - 1)
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

  // ─── Table Data Row ───
  Widget _buildRow(_TripHistoryData trip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Driver avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: const Icon(Icons.person_outline,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          // Driver name
          Expanded(
            flex: 5,
            child: Text(trip.driverName,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy)),
          ),
          // Vehicle plate
          Expanded(
            flex: 3,
            child: Text(trip.vehicle,
                style: const TextStyle(fontSize: 13, color: AppColors.navy)),
          ),
          // Destination
          Expanded(
            flex: 5,
            child: Text(trip.destination,
                style: const TextStyle(fontSize: 13, color: AppColors.navy)),
          ),
          // Date
          Expanded(
            flex: 3,
            child: Text(trip.date,
                style: const TextStyle(fontSize: 13, color: AppColors.navy)),
          ),
          // Duration
          Expanded(
            flex: 3,
            child: Text(trip.duration,
                style: const TextStyle(fontSize: 13, color: AppColors.navy)),
          ),
          // Download PDF button
          SizedBox(
            width: 130,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download_outlined, size: 15),
              label: const Text('Download PDF'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                textStyle: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
