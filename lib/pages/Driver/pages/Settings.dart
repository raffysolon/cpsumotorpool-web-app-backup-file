import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

class DriverSettings extends StatefulWidget {
  const DriverSettings({super.key});

  @override
  State<DriverSettings> createState() => _DriverSettingsState();
}

class _DriverSettingsState extends State<DriverSettings> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  Map<String, dynamic> _profile = const {};
  bool _saving = false;
  bool _loadingProfile = true;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final storedRole = await AuthService.getRole();
      if (storedRole?.toLowerCase() != 'driver') {
        throw _DriverAccountException();
      }
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found');
      }
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/user'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode != 200) {
        throw Exception('Profile request failed');
      }
      final profile = jsonDecode(response.body);
      if (profile is! Map) throw Exception('Invalid profile response');
      if (profile['role']?.toString().toLowerCase() != 'driver') {
        throw _DriverAccountException();
      }
      if (!mounted) return;
      setState(() {
        _profile = Map<String, dynamic>.from(profile);
        _loadingProfile = false;
        _profileError = null;
      });
    } on _DriverAccountException {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _profileError =
            'This is an admin account. Log out and sign in with a driver account.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _profileError = 'Unable to load driver details.';
      });
    }
  }

  Future<void> _changePassword() async {
    if (_newPassword.text != _confirmPassword.text) {
      _message('New passwords do not match.');
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthService.changePassword(
        _currentPassword.text,
        _newPassword.text,
      );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      _message('Password changed successfully.');
    } catch (_) {
      _message('Unable to change password.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _value(String key, String fallback) =>
      (_profile[key] ?? fallback).toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.glassFill,
        foregroundColor: AppColors.navy,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Driver Settings'),
      ),
      body: DriverShellAtmosphere(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Text(
                  'Settings',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                _section('Driver Details', [
                  if (_loadingProfile)
                    const Center(child: CircularProgressIndicator())
                  else if (_profileError != null)
                    Text(
                      _profileError!,
                      style: const TextStyle(color: Colors.redAccent),
                    )
                  else ...[
                    _readOnly('Name', _value('name', 'Not provided')),
                    _readOnly('Email', _value('email', 'Not provided')),
                    _readOnly(
                      'Contact Number',
                      _value('contact_number', 'Not provided'),
                    ),
                    _readOnly(
                      'License Number',
                      _value('license_number', 'Not provided'),
                    ),
                  ],
                ]),
                const SizedBox(height: 20),
                _section('Change Password', [
                  _passwordField('Current password', _currentPassword),
                  _passwordField('New password', _newPassword),
                  _passwordField('Confirm new password', _confirmPassword),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _saving ? null : _changePassword,
                      child: Text(_saving ? 'Saving...' : 'Change Password'),
                    ),
                  ),
                ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => GlassCard(
    padding: const EdgeInsets.all(24),
    borderRadius: 18,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          ...children.expand((child) => [child, const SizedBox(height: 14)]),
      ],
    ),
  );

  Widget _readOnly(String label, String value) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFFAFBFC),
      labelStyle: const TextStyle(color: AppColors.mutedDark),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    child: Text(value),
  );

  Widget _passwordField(String label, TextEditingController controller) =>
      TextField(
        controller: controller,
        obscureText: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFFAFBFC),
          labelStyle: const TextStyle(color: AppColors.mutedDark),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      );
}

class _DriverAccountException implements Exception {}
