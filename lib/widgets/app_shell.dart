import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/pages/Admin/pages/AdminCreateTripTicket.dart';
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';

// ═══════════════════════════════════════════════════════════════
// APP SHELL - Shared layout wrapper for all pages
// Contains: AppColors, AppShell, Sidebar, NavItem, PageHeader
// ═══════════════════════════════════════════════════════════════

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
  const AppShell({
    super.key,
    required this.currentRoute,
    required this.child,
  });

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

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await AuthService.getName();
    if (!mounted) return;
    setState(() => _name = name);
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
        badge: '3',
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
        label: 'Active Trips',
        badge: '3',
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
        label: 'Coordinator Assignments',
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
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
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
        color: selected ? Colors.white : AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        value,
        style: TextStyle(
          color: selected ? AppColors.primaryDark : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Reusable Page Header (title + notification + profile) ───
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title});

  final String title;

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
            Container(
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
                  Positioned(
                    top: 10,
                    right: 11,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
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
                children: [Expanded(child: titleBlock), actions],
              );
      },
    );
  }
}

// ─── Placeholder Page (used for pages not yet built) ───
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.route,
  });

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
