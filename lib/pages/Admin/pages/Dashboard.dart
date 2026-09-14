// ignore_for_file: file_names

import 'package:flutter/material.dart';

import 'package:cpsumotorpooladmin/services/driver_service.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';
import 'package:cpsumotorpooladmin/services/vehicle_service.dart';
import 'package:cpsumotorpooladmin/widgets/active_vehicles_map.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

// === Admin dashboard page: overview of fleet activity ===
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _pendingRequests = 0;
  bool _isLoadingPending = true;
  int _totalVehicles = 0;
  int _totalDrivers = 0;
  int _activeTrips = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
    _loadDashboardStats();
    AdminNotificationsController.instance.refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDashboardStats();
    AdminNotificationsController.instance.refresh();
  }

  Future<void> _loadPendingRequests() async {
    try {
      final result = await TripService.getAllTrips();
      final rawTrips = result is Map && result['data'] is List
          ? result['data'] as List
          : result is List
              ? result
              : const [];

      final pendingTrips = rawTrips.whereType<Map>().where((trip) {
        final status = (trip['status'] ?? '').toString().trim().toLowerCase();
        return status == 'pending';
      }).toList();

      final count = pendingTrips.length;

      if (!mounted) return;
      setState(() {
        _pendingRequests = count;
        _isLoadingPending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pendingRequests = 0;
        _isLoadingPending = false;
      });
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final results = await Future.wait([
        TripService.getAllTrips(),
        VehicleService.getVehicles(),
        DriverService.getDrivers(),
      ]);

      final tripResponse = results[0];
      final vehicleResponse = results[1];
      final driverResponse = results[2];

      final rawTrips = tripResponse is Map && tripResponse['data'] is List
          ? tripResponse['data'] as List
          : tripResponse is List
              ? tripResponse
              : const [];

      final rawVehicles = vehicleResponse is Map && vehicleResponse['data'] is List
          ? vehicleResponse['data'] as List
          : vehicleResponse is List
              ? vehicleResponse
              : const [];

      final rawDrivers = driverResponse is Map && driverResponse['data'] is List
          ? driverResponse['data'] as List
          : driverResponse is List
              ? driverResponse
              : const [];

      final activeTripCount = rawTrips.whereType<Map>().fold<int>(0, (total, trip) {
        final status = (trip['status'] ?? '').toString().trim().toLowerCase();
        return total + ((status == 'approved' || status == 'active') ? 1 : 0);
      });

      final vehicleCount = rawVehicles.whereType<Map>().length;
      final driverCount = rawDrivers.whereType<Map>().length;

      if (!mounted) return;
      setState(() {
        _activeTrips = activeTripCount;
        _totalVehicles = vehicleCount;
        _totalDrivers = driverCount;
        _isLoadingStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeTrips = 0;
        _totalVehicles = 0;
        _totalDrivers = 0;
        _isLoadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pad = constraints.maxWidth < 700 ? 16.0 : 32.0;
          final wideStats = constraints.maxWidth >= 900;
          final twoCol = constraints.maxWidth >= 560;

          final cards = [
            _StatCard(
              label: 'Pending Requests',
              value: _isLoadingPending ? '...' : _pendingRequests.toString(),
              icon: Icons.assignment_outlined,
              iconColor: AppColors.primary,
            ),
            _StatCard(
              label: 'Active Trips',
              value: _isLoadingStats ? '...' : _activeTrips.toString(),
              icon: Icons.explore_outlined,
              iconColor: AppColors.iconGreen2,
            ),
            _StatCard(
              label: 'Total Vehicles',
              value: _isLoadingStats ? '...' : _totalVehicles.toString(),
              icon: Icons.local_shipping_outlined,
              iconColor: AppColors.iconGreen3,
            ),
            _StatCard(
              label: 'Total Drivers',
              value: _isLoadingStats ? '...' : _totalDrivers.toString(),
              icon: Icons.people_outline,
              iconColor: AppColors.iconGreen4,
            ),
          ];

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, 24, pad, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: AdminNotificationsController.instance.unreadCount,
                  builder: (context, count, _) {
                    return PageHeader(
                      title: 'Dashboard',
                      notificationCount: count,
                      onNotificationsTap: () =>
                          AdminNotificationsController.instance.showNotificationsDialog(context),
                    );
                  },
                ),
                const SizedBox(height: 24),
                _StatCardsRow(
                  wide: wideStats,
                  twoCol: twoCol,
                  maxWidth: constraints.maxWidth,
                  cards: cards,
                ),
                const SizedBox(height: 20),
                const ActiveVehiclesMapCard(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCardsRow extends StatelessWidget {
  const _StatCardsRow({
    required this.wide,
    required this.twoCol,
    required this.maxWidth,
    required this.cards,
  });

  final bool wide;
  final bool twoCol;
  final double maxWidth;
  final List<_StatCard> cards;

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    final cols = twoCol ? 2 : 1;
    final itemWidth = cols == 1 ? maxWidth : (maxWidth - 16) / 2;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final card in cards) SizedBox(width: itemWidth, child: card),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
      borderRadius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

