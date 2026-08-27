import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

// ═══════════════════════════════════════════════════════════════
// ACTIVE TRIPS PAGE
// Shows currently in-progress trips with status and map link
// Route: /active-trips
// ═══════════════════════════════════════════════════════════════

// === Active trips page: trips currently in progress ===
// ─── Page Wrapper ───
class ActiveTrip extends StatelessWidget {
  const ActiveTrip({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/active-trips',
      child: const _ActiveTripContent(),
    );
  }
}

// ─── Data Model ───
class _ActiveTripData {
  final String driverName;
  final String vehicle;
  final String destination;
  final String status; // 'En Route', 'Loading'

  const _ActiveTripData({
    required this.driverName,
    required this.vehicle,
    required this.destination,
    required this.status,
  });
}

// ─── Mock Data (replace with API/database later) ───
const _mockTrips = [
  _ActiveTripData(
    driverName: 'Carlo Mendoza',
    vehicle: 'Toyota Innova — SJA 1123',
    destination: 'Bacolod to Victorias',
    status: 'En Route',
  ),
  _ActiveTripData(
    driverName: 'Ana Villanueva',
    vehicle: 'Mitsubishi L300 — SJB 4456',
    destination: 'Bacolod to Escalante',
    status: 'En Route',
  ),
  _ActiveTripData(
    driverName: 'Bert Ocampo',
    vehicle: 'Toyota Hi-Ace — SJC 7789',
    destination: 'Bacolod to Sagay',
    status: 'Loading',
  ),
];

// ─── Main Content Layout ───
class _ActiveTripContent extends StatelessWidget {
  const _ActiveTripContent();

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
              Text(
                'Active Trips',
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
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
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

  // ─── Section Header ("Trips Currently In Progress") ───
  Widget _buildSectionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Trips Currently In Progress',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Click a row to view on map',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }

  // ─── Table Container ───
  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 720 ? 720.0 : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
          _buildTableHeader(),
          const Divider(height: 1, color: AppColors.border),
              ..._mockTrips.asMap().entries.map((entry) {
                final i = entry.key;
                final trip = entry.value;
                return Column(
                  children: [
                    _buildTableRow(trip),
                    if (i < _mockTrips.length - 1)
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

  // ─── Table Header Row ───
  Widget _buildTableHeader() {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.mutedDark,
      letterSpacing: 0.8,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: const [
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

  // ─── Table Data Row ───
  Widget _buildTableRow(_ActiveTripData trip) {
    final isLoading = trip.status == 'Loading';
    final statusColor =
        isLoading ? const Color(0xFFD97706) : const Color(0xFF16A34A);
    final statusBg =
        isLoading ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7);

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
            child: Text(
              trip.driverName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
          // Vehicle
          Expanded(
            flex: 6,
            child: Text(
              trip.vehicle,
              style: const TextStyle(fontSize: 13, color: AppColors.navy),
            ),
          ),
          // Destination
          Expanded(
            flex: 6,
            child: Text(
              trip.destination,
              style: const TextStyle(fontSize: 13, color: AppColors.navy),
            ),
          ),
          // Status badge
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                trip.status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ),
          // "View on Map" link
          SizedBox(
            width: 120,
            child: TextButton.icon(
              onPressed: () {},
              icon: Icon(Icons.location_on_outlined,
                  size: 16, color: AppColors.primary),
              label: Text(
                'View on Map',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
