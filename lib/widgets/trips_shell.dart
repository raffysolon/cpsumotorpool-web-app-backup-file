import 'package:flutter/material.dart';

import 'admin_layout.dart';
import 'app_shell.dart';

/// Shared navigation for the existing trip workflows, each on its own route.
class TripsShell extends StatelessWidget {
  const TripsShell({
    super.key,
    required this.currentRoute,
    required this.child,
  });

  final String currentRoute;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppShell(
    currentRoute: '/active-trips',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AdminSpacing.gutter(context),
            16,
            AdminSpacing.gutter(context),
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Trips',
                      style: AppTypography.displayTitle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable:
                        AdminNotificationsController.instance.unreadCount,
                    builder: (context, count, _) => AdminNotificationBell(
                      count: count,
                      onTap: () => AdminNotificationsController.instance
                          .showNotificationsDialog(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TripsTabs(currentRoute: currentRoute),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

class TripsTabs extends StatelessWidget {
  const TripsTabs({super.key, required this.currentRoute});

  final String currentRoute;

  static const _sections = [
    (
      route: '/approval-letter',
      label: 'Trip Tickets',
      icon: Icons.confirmation_number_outlined,
    ),
    (
      route: '/trip-request',
      label: 'Trip Requests',
      icon: Icons.assignment_outlined,
    ),
    (
      route: '/active-trips',
      label: 'Scheduled & Active',
      icon: Icons.explore_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: AdminNotificationsController.instance.notifications,
        builder: (context, notifications, _) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final section in _sections)
              ChoiceChip(
                avatar: Icon(section.icon, size: 18),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(section.label),
                    if (_unreadFor(section.route, notifications) > 0) ...[
                      const SizedBox(width: 8),
                      Badge(
                        label: Text(
                          '${_unreadFor(section.route, notifications)}',
                        ),
                        backgroundColor: AppColors.primary,
                      ),
                    ],
                  ],
                ),
                selected: currentRoute == section.route,
                showCheckmark: false,
                onSelected: (_) {
                  if (currentRoute != section.route) {
                    Navigator.pushReplacementNamed(context, section.route);
                  }
                },
              ),
          ],
        ),
      );

  static int _unreadFor(String route, List<Map<String, dynamic>> items) {
    return items.where((item) {
      if (item['is_read'] == true || item['trip'] is! Map) return false;
      final trip = item['trip'] as Map;
      final status = '${trip['effective_status'] ?? trip['status']}'
          .toLowerCase();
      return route == '/trip-request'
          ? status == 'pending'
          : route == '/active-trips' &&
                ['approved', 'scheduled', 'active'].contains(status);
    }).length;
  }
}
