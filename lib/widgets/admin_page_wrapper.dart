// ═══════════════════════════════════════════════════════════════
// ADMIN PAGE WRAPPER - Persistent sidebar with dynamic content
// Prevents sidebar rebuild and position shift during navigation
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/pages/Admin/pages/Dashboard.dart';
import 'package:cpsumotorpooladmin/pages/Admin/pages/TripRequest.dart';
import 'package:cpsumotorpooladmin/pages/Admin/pages/Activetrip.dart';
import 'package:cpsumotorpooladmin/pages/Admin/pages/Map.dart';
import 'package:cpsumotorpooladmin/pages/Admin/pages/VehiclesDrivers.dart';
import 'package:cpsumotorpooladmin/pages/Admin/pages/CoordinatorAssignments.dart';
import 'package:cpsumotorpooladmin/pages/Admin/pages/TripHistory.dart';
import 'package:cpsumotorpooladmin/pages/Admin/pages/SnycLogs.dart';
import 'package:cpsumotorpooladmin/pages/Admin/pages/Settings.dart';
import 'app_shell.dart';

/// Wrapper that maintains a persistent sidebar while changing page content
/// This prevents the sidebar from rebuilding and shifting position
class AdminPageWrapper extends StatefulWidget {
  const AdminPageWrapper({super.key, this.initialRoute = '/'});
  
  final String initialRoute;

  @override
  State<AdminPageWrapper> createState() => AdminPageWrapperState();
}

class AdminPageWrapperState extends State<AdminPageWrapper> {
  late String _currentRoute;
  
  // Route to index mapping
  static const Map<String, int> _routeToIndex = {
    '/': 0,
    '/dashboard': 0,
    '/trip-request': 1,
    '/active-trips': 2,
    '/map': 3,
    '/vehicles': 4,
    '/coordinator-assignments': 5,
    '/trip-history': 6,
    '/sync-logs': 7,
    '/settings': 8,
  };
  
  // Index to route mapping (for named route support)
  static const Map<int, String> _indexToRoute = {
    0: '/',
    1: '/trip-request',
    2: '/active-trips',
    3: '/map',
    4: '/vehicles',
    5: '/coordinator-assignments',
    6: '/trip-history',
    7: '/sync-logs',
    8: '/settings',
  };

  @override
  void initState() {
    super.initState();
    _currentRoute = widget.initialRoute;
  }

  /// Navigate to a route by name
  void navigateToRoute(String route) {
    if (_currentRoute == route) return;
    setState(() {
      _currentRoute = route;
    });
  }

  /// Navigate to a page by index
  void navigateToIndex(int index) {
    final route = _indexToRoute[index] ?? '/';
    navigateToRoute(route);
  }

  @override
  Widget build(BuildContext context) {
    final index = _routeToIndex[_currentRoute] ?? 0;
    
    return AdminPageWrapperScope(
      state: this,
      child: _AdminLayoutWithPersistentSidebar(
        currentRoute: _currentRoute,
        currentIndex: index,
      ),
    );
  }
}

/// InheritedWidget to provide navigation capability to descendants
class AdminPageWrapperScope extends InheritedWidget {
  const AdminPageWrapperScope({
    super.key,
    required this.state,
    required super.child,
  });

  final AdminPageWrapperState state;

  static AdminPageWrapperState? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdminPageWrapperScope>()
        ?.state;
  }

  @override
  bool updateShouldNotify(AdminPageWrapperScope oldWidget) {
    return state != oldWidget.state;
  }
}

/// Layout with persistent sidebar and IndexedStack for content
class _AdminLayoutWithPersistentSidebar extends StatelessWidget {
  const _AdminLayoutWithPersistentSidebar({
    required this.currentRoute,
    required this.currentIndex,
  });

  final String currentRoute;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final rail = !narrow && constraints.maxWidth < 1180;

        if (narrow) {
          // Mobile layout with drawer
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.glassFill,
              foregroundColor: AppColors.navy,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              title: Text(
                'MotorPool',
                style: AppTypography.displayTitle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            drawer: Drawer(
              backgroundColor: Colors.transparent,
              child: _PersistentSidebar(currentRoute: currentRoute, compact: false),
            ),
            body: _ShellAtmosphere(
              child: _PageContent(currentIndex: currentIndex),
            ),
          );
        }

        // Desktop layout with persistent sidebar
        return Scaffold(
          backgroundColor: AppColors.background,
          body: _ShellAtmosphere(
            child: Row(
              children: [
                // Persistent sidebar (doesn't rebuild)
                _PersistentSidebar(currentRoute: currentRoute, compact: rail),
                // Content area (IndexedStack maintains all pages)
                Expanded(
                  child: _PageContent(currentIndex: currentIndex),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Wrapper for _ShellAtmosphere from app_shell.dart
class _ShellAtmosphere extends StatelessWidget {
  const _ShellAtmosphere({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF3F8F4),
                Color(0xFFE8F5EC),
                Color(0xFFF8FAFC),
                Color(0xFFEAF6EE),
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
        Positioned(
          right: -90,
          top: -70,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          left: -110,
          bottom: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.mint.withOpacity(0.18),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Persistent sidebar that uses InheritedWidget for navigation
class _PersistentSidebar extends StatelessWidget {
  const _PersistentSidebar({
    required this.currentRoute,
    this.compact = false,
  });

  final String currentRoute;
  final bool compact;

  void _navigateTo(BuildContext context, String route) {
    AdminPageWrapperScope.of(context)?.navigateToRoute(route);
    // Close drawer if open (mobile)
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Import the existing _Sidebar from app_shell and wrap it
    // Or rebuild the sidebar here with navigation callback
    return _SidebarContent(
      currentRoute: currentRoute,
      compact: compact,
      onNavigate: (route) => _navigateTo(context, route),
    );
  }
}

/// Content area using IndexedStack to keep all pages alive
/// This prevents rebuild and maintains scroll positions
class _PageContent extends StatelessWidget {
  const _PageContent({required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: currentIndex,
      sizing: StackFit.expand,
      children: const [
        Dashboard(),              // 0: /dashboard
        TripRequest(),            // 1: /trip-request
        ActiveTrip(),             // 2: /active-trips
        MapPage(),                // 3: /map
        VehiclesDriversPage(),    // 4: /vehicles
        CoordinatorAssignments(), // 5: /coordinator-assignments
        TripHistory(),            // 6: /trip-history
        SyncLogs(),               // 7: /sync-logs
        Settings(),               // 8: /settings
      ],
    );
  }
}

/// Sidebar content with navigation callback
class _SidebarContent extends StatelessWidget {
  const _SidebarContent({
    required this.currentRoute,
    required this.compact,
    required this.onNavigate,
  });

  final String currentRoute;
  final bool compact;
  final Function(String) onNavigate;

  @override
  Widget build(BuildContext context) {
    // For now, use the existing _Sidebar from app_shell.dart
    // We'll need to modify it to accept a navigation callback
    // Temporary: Return a placeholder
    return Container(
      width: compact ? 84 : 248,
      color: AppColors.glassFill,
      child: Center(
        child: Text('Sidebar - Route: $currentRoute'),
      ),
    );
  }
}
