import 'package:flutter/material.dart';

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
import 'pages/feautures/auth/Login.dart';
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
        fontFamily: 'CustomFont',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      // ─── Route Definitions ───
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/': (context) => const Dashboard(),
        '/trip-request': (context) => const TripRequest(),
        '/active-trips': (context) => const ActiveTrip(),
        '/map': (context) => const MapPage(),
        '/vehicles': (context) => const VehiclesDriversPage(),
        '/coordinator-assignments': (context) => const CoordinatorAssignments(),
        '/trip-history': (context) => const TripHistory(),
        '/sync-logs': (context) => const SyncLogs(),
        '/settings': (context) => const Settings(),
        '/driver-dashboard': (context) => const driver_dashboard.DriverDashboard(),
        '/driver-create-trip': (context) => const CreateTripTicket(),
      },
    );
  }
}
