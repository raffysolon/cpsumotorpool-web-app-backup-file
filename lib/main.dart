import 'pages/Admin/pages/AdminCreateTripTicket.dart'
    show AdminCreateTripTicketPage;
import 'dart:async';
import 'services/session_monitor.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widgets/app_shell.dart';
import 'widgets/persistent_admin_shell.dart';

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
import 'pages/Admin/pages/DeviceRegistry.dart';
import 'pages/Driver/pages/Dashboard.dart' as driver_dashboard;
import 'pages/Driver/pages/CreateTripTicket.dart';
import 'pages/Driver/pages/Settings.dart' as driver_settings;
import 'pages/feautures/auth/Login.dart';
import 'pages/feautures/auth/ForgotPassword.dart';
import 'pages/services/auth_service.dart';
import 'pages/splash_screen.dart';
import 'widgets/app_notification.dart';

// ─── App Entry Point ───
void main() {
  runApp(const MyApp());
}

// ─── Root App Widget ───
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Timer? _activityTimer;
  Timer? _sessionTimer;
  final _sessionMonitor = SessionMonitor();
  bool _appVisible = true;
  bool _recordingActivity = false;
  static const Duration _idleTimeout = Duration(minutes: 5);
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final _adminNavigation = AdminShellNavigation();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _resetActivityTimer();
    _sessionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_appVisible) _checkSession();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _activityTimer?.cancel();
    _sessionTimer?.cancel();
    _adminNavigation.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    if (!mounted) return;
    final expired = await _sessionMonitor.check();
    if (!mounted || !expired) return;
    AppNotification.dismiss();
    _navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  void _resetActivityTimer() {
    _activityTimer?.cancel();
    _activityTimer = Timer(_idleTimeout, () async {
      await _checkSession();
    });
  }

  Future<void> _markActivity() async {
    if (!mounted || !_appVisible || _recordingActivity) return;
    _recordingActivity = true;
    try {
      final expired = await AuthService.recordActivity();
      if (!mounted) return;
      if (expired) {
        AppNotification.dismiss();
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (_) => false,
        );
      } else {
        _resetActivityTimer();
      }
    } finally {
      _recordingActivity = false;
    }
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) _markActivity();
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = state == AppLifecycleState.resumed;
    if (_appVisible) {
      _checkSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _markActivity(),
      onPointerMove: (_) => _markActivity(),
      onPointerUp: (_) => _markActivity(),
      onPointerSignal: (_) => _markActivity(),
      behavior: HitTestBehavior.translucent,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        navigatorObservers: [_adminNavigation],
        title: 'CPSU MotorPool',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F8A3D)),
          useMaterial3: true,
          textTheme: AppTypography.textTheme(ThemeData.light().textTheme),
          scaffoldBackgroundColor: const Color(0xFFF6F8F7),
          dividerTheme: const DividerThemeData(
            color: Color(0xFFDEE7E1),
            thickness: 1,
          ),
          inputDecorationTheme: InputDecorationTheme(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAF9),
            hintStyle: const TextStyle(color: Color(0xFF718078), fontSize: 14),
            labelStyle: const TextStyle(color: Color(0xFF58675F), fontSize: 14),
            floatingLabelStyle: const TextStyle(
              color: Color(0xFF176E30),
              fontWeight: FontWeight.w600,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDEE7E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF1F8A3D),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFB42318)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFB42318),
                width: 1.5,
              ),
            ),
          ),
          dialogTheme: DialogThemeData(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: Color(0xFF1F8A3D),
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Color(0xFF1F8A3D),
            selectionColor: Color(0x331F8A3D),
            selectionHandleColor: Color(0xFF1F8A3D),
          ),
          tooltipTheme: TooltipThemeData(
            decoration: BoxDecoration(
              color: const Color(0xFF1F2933),
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: _filledButtonStyle(),
          ),
          filledButtonTheme: FilledButtonThemeData(style: _filledButtonStyle()),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: _outlinedButtonStyle(),
          ),
          textButtonTheme: TextButtonThemeData(style: _textButtonStyle()),
        ),
        builder: (context, child) => AppNotification.host(
          child: PersistentAdminShell(
            navigation: _adminNavigation,
            navigatorKey: _navigatorKey,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        // ─── Route Definitions ───
        initialRoute:
            WidgetsBinding.instance.platformDispatcher.defaultRouteName,
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginPage(),
          '/forgot-password': (context) => const ForgotPasswordPage(),
          '/': (context) => _RoleGuard(role: 'admin', child: const Dashboard()),
          '/trip-request': (context) =>
              _RoleGuard(role: 'admin', child: const TripRequest()),
          '/approval-letter': (context) => _RoleGuard(
            role: 'admin',
            child: const AdminCreateTripTicketPage(),
          ),
          '/active-trips': (context) =>
              _RoleGuard(role: 'admin', child: const ActiveTrip()),
          '/map': (context) =>
              _RoleGuard(role: 'admin', child: const MapPage()),
          '/vehicles': (context) =>
              _RoleGuard(role: 'admin', child: const VehiclesDriversPage()),
          '/devices': (context) =>
              _RoleGuard(role: 'admin', child: const DeviceRegistryPage()),
          '/coordinator-assignments': (context) =>
              _RoleGuard(role: 'admin', child: const CoordinatorAssignments()),
          '/trip-history': (context) =>
              _RoleGuard(role: 'admin', child: const TripHistory()),
          '/sync-logs': (context) =>
              _RoleGuard(role: 'admin', child: const SyncLogs()),
          '/settings': (context) =>
              _RoleGuard(role: 'admin', child: const Settings()),
          '/driver-dashboard': (context) => _RoleGuard(
            role: 'driver',
            child: const driver_dashboard.DriverDashboard(),
          ),
          '/driver-create-trip': (context) =>
              _RoleGuard(role: 'driver', child: const CreateTripTicket()),
          '/driver-settings': (context) => _RoleGuard(
            role: 'driver',
            child: const driver_settings.DriverSettings(),
          ),
        },
      ),
    );
  }

  static ButtonStyle _filledButtonStyle() {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? const Color(0xFFE3EAE5)
            : const Color(0xFF1F8A3D),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? const Color(0xFF718078)
            : Colors.white,
      ),
      overlayColor: WidgetStatePropertyAll(
        Colors.white.withValues(alpha: 0.12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevation: const WidgetStatePropertyAll(0),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
    );
  }

  static ButtonStyle _outlinedButtonStyle() {
    return ButtonStyle(
      backgroundColor: const WidgetStatePropertyAll(Colors.white),
      foregroundColor: const WidgetStatePropertyAll(Color(0xFF1F2933)),
      overlayColor: WidgetStatePropertyAll(
        const Color(0xFF1F8A3D).withValues(alpha: 0.08),
      ),
      side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFFC7D9CC))),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
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
      await AuthService.expireIdleSession();
      final token = await AuthService.getToken();
      final role = await AuthService.getRole();
      allowed =
          token != null &&
          token.isNotEmpty &&
          role?.trim().toLowerCase() == widget.role;
    } catch (_) {}

    if (!mounted) return;
    if (allowed) {
      if (widget.role == 'admin') AdminShellScope.of(context)?.authorize();
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
