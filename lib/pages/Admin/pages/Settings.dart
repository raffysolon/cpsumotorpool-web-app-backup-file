import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  String _name = 'Loading...';
  String _email = 'Loading...';
  bool _saving = false;

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
    final token = await AuthService.getToken();
    if (token == null) return;
    final response = await http.get(
      Uri.parse('http://127.0.0.1:8000/api/user'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (!mounted || response.statusCode != 200) return;
    final profile = jsonDecode(response.body) as Map<String, dynamic>;
    setState(() {
      _name = (profile['name'] ?? 'Unknown').toString();
      _email = (profile['email'] ?? 'Unavailable').toString();
    });
  }

  Future<void> _changePassword() async {
    if (_newPassword.text != _confirmPassword.text) {
      _message('New passwords do not match.');
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthService.changePassword(_currentPassword.text, _newPassword.text);
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

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/settings',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader(title: 'Settings'),
                _section('Admin Account', [
                  _readOnly('Name', _name),
                  _readOnly('Email', _email),
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
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => GlassCard(
        padding: const EdgeInsets.all(24),
        borderRadius: 18,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            ...children.expand((child) => [child, const SizedBox(height: 14)]),
          ]),
      );

  Widget _readOnly(String label, String value) => InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: const Color(0xFFFAFBFC),
            labelStyle: const TextStyle(color: AppColors.mutedDark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        child: Text(value),
      );

  Widget _passwordField(String label, TextEditingController controller) => TextField(
        controller: controller,
        obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFFAFBFC),
        labelStyle: const TextStyle(color: AppColors.mutedDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
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
