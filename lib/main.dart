import 'package:flutter/material.dart';

import 'widgets/app_shell.dart';

// ─── Page Imports ───
import 'pages/Admin/pages/Activetrip.dart';
import 'pages/Admin/pages/Dashboard.dart';
import 'pages/Admin/pages/VehiclesDrivers.dart';
import 'pages/Admin/pages/Map.dart';
import 'pages/Admin/pages/Settings.dart';
import 'pages/Admin/pages/SnycLogs.dart';
import 'pages/Admin/pages/TripHistory.dart';
import 'pages/Admin/pages/TripRequest.dart';
import 'pages/Admin/pages/CoordinatorAssignments.dart';
import 'pages/Driver/pages/Dashboard.dart' as driver_dashboard;
import 'pages/Driver/pages/CreateTripTicket.dart';
import 'pages/Driver/pages/Settings.dart' as driver_settings;
import 'pages/feautures/auth/Login.dart';
import 'pages/services/auth_service.dart';
import 'pages/splash_screen.dart';

// ─── App Entry Point ───
void main() {
  runApp(const MyApp());
}

// ─── Root App Widget ───
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MotorPool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF22C55E)),
        useMaterial3: true,
        textTheme: AppTypography.textTheme(ThemeData.light().textTheme),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        elevatedButtonTheme: ElevatedButtonThemeData(style: _filledButtonStyle()),
        filledButtonTheme: FilledButtonThemeData(style: _filledButtonStyle()),
        outlinedButtonTheme: OutlinedButtonThemeData(style: _outlinedButtonStyle()),
        textButtonTheme: TextButtonThemeData(style: _textButtonStyle()),
      ),
      // ─── Route Definitions ───
      initialRoute: '/login',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/': (context) => _RoleGuard(
          role: 'admin',
          child: const Dashboard(),
        ),
        '/trip-request': (context) => _RoleGuard(
          role: 'admin',
          child: const TripRequest(),
        ),
        '/active-trips': (context) => _RoleGuard(
          role: 'admin',
          child: const ActiveTrip(),
        ),
        '/map': (context) => _RoleGuard(
          role: 'admin',
          child: const MapPage(),
        ),
        '/vehicles': (context) => _RoleGuard(
          role: 'admin',
          child: const VehiclesDriversPage(),
        ),
        '/coordinator-assignments': (context) => _RoleGuard(
          role: 'admin',
          child: const CoordinatorAssignments(),
        ),
        '/trip-history': (context) => _RoleGuard(
          role: 'admin',
          child: const TripHistory(),
        ),
        '/sync-logs': (context) => _RoleGuard(
          role: 'admin',
          child: const SyncLogs(),
        ),
        '/settings': (context) => _RoleGuard(
          role: 'admin',
          child: const Settings(),
        ),
        '/driver-dashboard': (context) =>
            _RoleGuard(role: 'driver', child: const driver_dashboard.DriverDashboard()),
        '/driver-create-trip': (context) =>
            _RoleGuard(role: 'driver', child: const CreateTripTicket()),
        '/driver-settings': (context) =>
            _RoleGuard(role: 'driver', child: const driver_settings.DriverSettings()),
      },
    );
  }

  static ButtonStyle _filledButtonStyle() {
    return ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(Color(0xFF1F8A3D)),
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      overlayColor: WidgetStatePropertyAll(
        Colors.white.withValues(alpha: 0.12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      elevation: const WidgetStatePropertyAll(0),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
    );
  }

  static ButtonStyle _outlinedButtonStyle() {
    return ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(Colors.white),
      foregroundColor: const WidgetStatePropertyAll(Color(0xFF1F2933)),
      overlayColor: WidgetStatePropertyAll(
        const Color(0xFF1F8A3D).withValues(alpha: 0.08),
      ),
      side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFF86EFAC))),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
    );
  }

  static ButtonStyle _textButtonStyle() {
    return ButtonStyle(
      foregroundColor: const WidgetStatePropertyAll(Color(0xFF176E30)),
      overlayColor: WidgetStatePropertyAll(
        const Color(0xFF1F8A3D).withValues(alpha: 0.08),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

class _RoleGuard extends StatefulWidget {
  const _RoleGuard({required this.role, required this.child});

  final String role;
  final Widget child;

  @override
  State<_RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<_RoleGuard> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    var allowed = false;
    try {
      final token = await AuthService.getToken();
      final role = await AuthService.getRole();
      allowed = token != null &&
          token.isNotEmpty &&
          role?.trim().toLowerCase() == widget.role;
    } catch (_) {}

    if (!mounted) return;
    if (allowed) {
      setState(() => _isChecking = false);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return widget.child;
  }
}
