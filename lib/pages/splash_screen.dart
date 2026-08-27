import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'Admin/pages/Dashboard.dart' as admin_dashboard;
import 'Driver/pages/Dashboard.dart' as driver_dashboard;
import 'feautures/auth/Login.dart';
import '../widgets/app_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _startAuthCheck();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  Future<void> _startAuthCheck() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final role = await _checkAuthStatus();
    if (!mounted) return;

    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const admin_dashboard.Dashboard()),
      );
    } else if (role == 'driver') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const driver_dashboard.DriverDashboard(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  Future<String?> _checkAuthStatus() async {
    // TODO: Read the persisted session and return its user role.
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CPSU MOTORPOOL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'VEHICLE TRACKING SYSTEM',
                        style: TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 38),
              AnimatedBuilder(
                animation: _dotsController,
                builder: (context, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, _buildDot),
                  );
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Verifying account access…',
                style: TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  letterSpacing: .3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    final progress = (_dotsController.value + index * .2) % 1;
    final pulse = (math.sin(progress * math.pi * 2) + 1) / 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Opacity(
        opacity: .45 + pulse * .55,
        child: Transform.scale(
          scale: 1 + pulse * .3,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
