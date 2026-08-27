import 'package:flutter/material.dart';

import 'package:cpsumotorpooladmin/widgets/active_vehicles_map.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

// === Admin dashboard page: overview of fleet activity ===
class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  // --- Dashboard layout: responsive summary and activity sections ---
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pad = constraints.maxWidth < 700 ? 16.0 : 32.0;
          final wideStats = constraints.maxWidth >= 900;
          final twoCol = constraints.maxWidth >= 560;
          final stackedPanels = constraints.maxWidth < 980;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, 24, pad, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader(title: 'Dashboard'),
                const SizedBox(height: 24),
                _StatCardsRow(
                  wide: wideStats,
                  twoCol: twoCol,
                  maxWidth: constraints.maxWidth,
                ),
                const SizedBox(height: 20),
                const ActiveVehiclesMapCard(),
                const SizedBox(height: 20),
                if (stackedPanels) ...[
                  const _RecentActivityCard(),
                  const SizedBox(height: 20),
                  const _StatusCard(),
                ] else
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _RecentActivityCard()),
                      SizedBox(width: 20),
                      Expanded(flex: 2, child: _StatusCard()),
                    ],
                  ),
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
  });

  final bool wide;
  final bool twoCol;
  final double maxWidth;

  static const _cards = [
    _StatCard(
      label: 'Pending Requests',
      value: '3',
      icon: Icons.assignment_outlined,
      iconColor: AppColors.primary,
    ),
    _StatCard(
      label: 'Active Trips',
      value: '3',
      icon: Icons.explore_outlined,
      iconColor: AppColors.iconGreen2,
    ),
    _StatCard(
      label: 'Total Vehicles',
      value: '6',
      icon: Icons.local_shipping_outlined,
      iconColor: AppColors.iconGreen3,
    ),
    _StatCard(
      label: 'Total Drivers',
      value: '6',
      icon: Icons.people_outline,
      iconColor: AppColors.iconGreen4,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < _cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: _cards[i]),
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
        for (final card in _cards) SizedBox(width: itemWidth, child: card),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
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

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  static const _items = [
    ('Trip request submitted by Ramon Dela Cruz', '5 min ago'),
    ('Vehicle assigned to Maria Santos', '12 min ago'),
    ('Trip completed by Juan Reyes', '1 hour ago'),
    ('New driver registered: Pedro Garcia', '2 hours ago'),
    ('Vehicle maintenance scheduled', '3 hours ago'),
    ('Trip request approved for Ana Lopez', '4 hours ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _items[i].$1,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _items[i].$2,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (i < _items.length - 1)
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fleet Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 18),
          _StatusRow(
            label: 'Available',
            value: '3',
            dotColor: AppColors.primary,
          ),
          SizedBox(height: 14),
          _StatusRow(
            label: 'In Use',
            value: '2',
            dotColor: Color(0xFF86EFAC),
          ),
          SizedBox(height: 14),
          _StatusRow(
            label: 'Maintenance',
            value: '1',
            dotColor: Color(0xFFCBD5E1),
          ),
          SizedBox(height: 20),
          Divider(height: 1, color: Color(0xFFF1F5F9)),
          SizedBox(height: 20),
          Text(
            'Driver Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 18),
          _StatusRow(label: 'Available', value: '3'),
          SizedBox(height: 14),
          _StatusRow(label: 'On Trip', value: '2'),
          SizedBox(height: 14),
          _StatusRow(label: 'Off Duty', value: '1'),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.dotColor,
  });

  final String label;
  final String value;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (dotColor != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppColors.navy),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }
}
