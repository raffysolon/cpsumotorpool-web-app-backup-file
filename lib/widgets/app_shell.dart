import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/pages/Admin/pages/AdminCreateTripTicket.dart';
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'package:cpsumotorpooladmin/services/notification_service.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';

// ═══════════════════════════════════════════════════════════════
// APP SHELL - Shared layout wrapper for all pages
// Contains: AppColors, AppShell, Sidebar, NavItem, PageHeader
// ═══════════════════════════════════════════════════════════════

final ValueNotifier<int> adminTripTicketCountNotifier = ValueNotifier<int>(0);

class AdminNotificationsController {
  AdminNotificationsController._();

  static final AdminNotificationsController instance =
      AdminNotificationsController._();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  final ValueNotifier<List<Map<String, dynamic>>> notifications =
      ValueNotifier<List<Map<String, dynamic>>>(const []);
  Future<void> refresh() async {
    try {
      final countResult = await NotificationService.getUnreadCount();
      final listResult = await NotificationService.getNotifications();

      final count = countResult is Map
          ? ((countResult['count'] ?? 0) as num).toInt()
          : 0;
      final items = (listResult is List ? listResult : const [])
          .whereType<Map>()
          .map<Map<String, dynamic>>(
            (item) => {
              'id': item['id'] ?? 0,
              'message': item['message'] ?? 'Notification',
              'created_at': item['created_at'] ?? '',
            },
          )
          .toList();

      unreadCount.value = count;
      notifications.value = items;
    } catch (_) {
      unreadCount.value = 0;
      notifications.value = const [];
    }
  }

  Future<void> markAsReadAndRefresh(int id) async {
    try {
      await NotificationService.markAsRead(id);
    } finally {
      await refresh();
    }
  }

  String relativeTime(String value) {
    if (value.isEmpty) return 'Just now';
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return 'Just now';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.month}/${date.day}';
  }

  void showNotificationsDialog(BuildContext context) {
    final items = notifications.value;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Notifications'),
          content: SizedBox(
            width: 420,
            child: items.isEmpty
                ? const Text('No notifications.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notification = items[index];
                      final id = (notification['id'] ?? 0) as int;
                      final message = (notification['message'] ?? '')
                          .toString();
                      final relativeTime = this.relativeTime(
                        (notification['created_at'] ?? '').toString(),
                      );

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          message,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: Text(
                          relativeTime,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.mutedDark,
                          ),
                        ),
                        onTap: () async {
                          try {
                            await markAsReadAndRefresh(id);
                          } finally {
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          }
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

// ─── App Color Palette ───
class AppColors {
  static const Color primary = Color(0xFF22C55E);
  static const Color primaryDark = Color(0xFF16A34A);
  static const Color navy = Color(0xFF1E293B);
  static const Color muted = Color(0xFF94A3B8);
  static const Color mutedDark = Color(0xFF64748B);
  static const Color background = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color iconGreen2 = Color(0xFF4ADE80);
  static const Color iconGreen3 = Color(0xFF15803D);
  static const Color iconGreen4 = Color(0xFF166534);
}

// ─── App Shell (responsive layout: sidebar + content) ───
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.currentRoute, required this.child});

  final String currentRoute;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final rail = !narrow && constraints.maxWidth < 1180;

        // Mobile layout: drawer sidebar
        if (narrow) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.navy,
              elevation: 0,
              surfaceTintColor: Colors.white,
              title: const Text(
                'MotorPool',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            drawer: Drawer(
              backgroundColor: Colors.white,
              child: _Sidebar(currentRoute: currentRoute, compact: false),
            ),
            body: child,
          );
        }

        // Desktop layout: fixed sidebar
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: [
              _Sidebar(currentRoute: currentRoute, compact: rail),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

// ─── Sidebar Navigation ───
class _Sidebar extends StatefulWidget {
  const _Sidebar({required this.currentRoute, this.compact = false});

  final String currentRoute;
  final bool compact;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  String? _name;
  String _tripRequestCount = '0';
  String _activeTripsCount = '0';

  @override
  void initState() {
    super.initState();
    _loadName();
    _loadTripCounts();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadName() async {
    final name = await AuthService.getName();
    if (!mounted) return;
    setState(() => _name = name);
  }

  Future<void> _loadTripCounts() async {
    try {
          final result = await TripService.getAllTrips();
        final rawTrips = result is Map && result['data'] is List
          ? result['data'] as List
          : result is List
          ? result
          : const [];

      if (!mounted) return;

      final pendingCount = rawTrips.whereType<Map>().fold<int>(0, (
        total,
        trip,
      ) {
        final status = (trip['status'] ?? '').toString().trim().toLowerCase();
        return total + (status == 'pending' ? 1 : 0);
      });

      final activeCount = rawTrips.whereType<Map>().fold<int>(0, (total, trip) {
        final status = (trip['effective_status'] ?? trip['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        return total + ((status == 'scheduled' || status == 'active') ? 1 : 0);
      });

      setState(() {
        _tripRequestCount = pendingCount.toString();
        _activeTripsCount = activeCount.toString();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tripRequestCount = '0';
        _activeTripsCount = '0';
      });
    }
  }

  void _go(BuildContext context, String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    if (current == route) return;
    Navigator.pushReplacementNamed(context, route);
  }

  void _openRequestLetters(BuildContext context) {
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminCreateTripTicketPage()),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Log out?',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Are you sure you want to log out of the admin account?',
            style: TextStyle(color: AppColors.mutedDark, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.mutedDark),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = widget.currentRoute;
    final compact = widget.compact;

    // ─── Navigation Items ───
    final items = <Widget>[
      _NavItem(
        icon: Icons.grid_view_rounded,
        label: 'Dashboard',
        compact: compact,
        selected: currentRoute == '/',
        onTap: () => _go(context, '/'),
      ),
      _NavItem(
        icon: Icons.assignment_outlined,
        label: 'Trip Request',
        badge: _tripRequestCount,
        compact: compact,
        selected: currentRoute == '/trip-request',
        onTap: () => _go(context, '/trip-request'),
      ),
      _NavItem(
        icon: Icons.mail_outline,
        label: 'Create Trip Ticket',
        compact: compact,
        selected: currentRoute == '/approval-letter',
        onTap: () => _openRequestLetters(context),
      ),
      _NavItem(
        icon: Icons.explore_outlined,
        label: 'Scheduled / Active Trips',
        badge: _activeTripsCount,
        compact: compact,
        selected: currentRoute == '/active-trips',
        onTap: () => _go(context, '/active-trips'),
      ),
      _NavItem(
        icon: Icons.map_outlined,
        label: 'Map',
        compact: compact,
        selected: currentRoute == '/map',
        onTap: () => _go(context, '/map'),
      ),
      _NavItem(
        icon: Icons.local_shipping_outlined,
        label: 'Vehicle & Drivers',
        compact: compact,
        selected: currentRoute == '/vehicles',
        onTap: () => _go(context, '/vehicles'),
      ),
      _NavItem(
        icon: Icons.assignment_ind_outlined,
        label: 'Administrator assignment',
        compact: compact,
        selected: currentRoute == '/coordinator-assignments',
        onTap: () => _go(context, '/coordinator-assignments'),
      ),
      _NavItem(
        icon: Icons.history,
        label: 'Trip History',
        compact: compact,
        selected: currentRoute == '/trip-history',
        onTap: () => _go(context, '/trip-history'),
      ),
      _NavItem(
        icon: Icons.sync,
        label: 'Sync Logs',
        compact: compact,
        selected: currentRoute == '/sync-logs',
        onTap: () => _go(context, '/sync-logs'),
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        label: 'Settings',
        compact: compact,
        selected: currentRoute == '/settings',
        onTap: () => _go(context, '/settings'),
      ),
    ];

    return Container(
      width: compact ? 84 : 248,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // ─── Logo / Brand Header ───
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MotorPool',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Fleet Management',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ─── Nav Item List ───
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: items,
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // ─── Account Footer ───
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 20,
              12,
              compact ? 12 : 20,
              16,
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(
                    Icons.person,
                    color: AppColors.primaryDark,
                    size: 20,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name ?? 'Loading...',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          'Motorpool Admin',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                IconButton(
                  tooltip: 'Log out',
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(
                    Icons.logout,
                    color: AppColors.mutedDark,
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Single Navigation Item (sidebar button) ───
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.badge,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final String? badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final item = Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 14,
            vertical: 11,
          ),
          child: compact
              ? Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: selected ? Colors.white : AppColors.mutedDark,
                    ),
                    if (badge != null)
                      Positioned(
                        top: -4,
                        right: 8,
                        child: _Badge(value: badge!, selected: selected),
                      ),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: selected ? Colors.white : AppColors.mutedDark,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected ? Colors.white : AppColors.navy,
                        ),
                      ),
                    ),
                    if (badge != null)
                      _Badge(value: badge!, selected: selected),
                  ],
                ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: compact ? Tooltip(message: label, child: item) : item,
    );
  }
}

// ─── Badge Widget (notification count circle) ───
class _Badge extends StatelessWidget {
  const _Badge({required this.value, required this.selected});

  final String value;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: Text(
        value,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AdminNotificationBell extends StatelessWidget {
  const AdminNotificationBell({super.key, this.count, this.onTap});

  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bellCount =
        count ?? AdminNotificationsController.instance.unreadCount.value;

    return InkWell(
      onTap:
          onTap ??
          () => AdminNotificationsController.instance.showNotificationsDialog(
            context,
          ),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(
                Icons.notifications_none_rounded,
                color: AppColors.navy,
                size: 22,
              ),
            ),
            if (bellCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    bellCount > 9 ? '9+' : bellCount.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable Page Header (title + notification + profile) ───
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.notificationCount = 0,
    this.onNotificationsTap,
  });

  final String title;
  final int notificationCount;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Province of Negros Occidental - Motorpool Division',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: AppColors.mutedDark),
            ),
          ],
        );

        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<int>(
              valueListenable:
                  AdminNotificationsController.instance.unreadCount,
              builder: (context, count, _) {
                return AdminNotificationBell(
                  count: notificationCount > 0 ? notificationCount : count,
                  onTap:
                      onNotificationsTap ??
                      () => AdminNotificationsController.instance
                          .showNotificationsDialog(context),
                );
              },
            ),
            const SizedBox(width: 10),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 22),
            ),
          ],
        );

        return narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [titleBlock, const SizedBox(height: 14), actions],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleBlock),
                  actions,
                ],
              );
      },
    );
  }
}

// ─── Placeholder Page (used for pages not yet built) ───
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.route});

  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: route,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pad = constraints.maxWidth < 700 ? 16.0 : 32.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, 24, pad, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(title: title),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '$title content coming soon.',
                    style: const TextStyle(color: AppColors.mutedDark),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
