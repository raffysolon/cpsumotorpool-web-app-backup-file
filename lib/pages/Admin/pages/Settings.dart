// ignore_for_file: file_names

import 'package:cpsumotorpooladmin/widgets/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/widgets/admin_layout.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'package:cpsumotorpooladmin/services/api_config.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final _currentPassword = TextEditingController();
  bool _hidePassword = true;
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
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final token = await AuthService.getToken();
    if (token == null) return;
    final response = await http.get(
      ApiConfig.apiUri('user'),
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
    setState(() => _saving = true);
    try {
      await AuthService.changePassword(_currentPassword.text);
      if (!mounted) return;
      _currentPassword.clear();
      _message('Check your registered email to finish changing your password.');
    } on LoginException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('Unable to send the password reset email.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) {
    AppNotification.show(context, SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/settings',
      child: SingleChildScrollView(
        padding: AdminSpacing.page(context),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader(title: 'Settings'),
                const SizedBox(height: 16),
                _section('Admin Account', [
                  _readOnly('Name', _name),
                  _readOnly('Email', _email),
                ]),
                const SizedBox(height: 20),
                _section('Change Password', [
                  const Text(
                    'Confirm your current password to receive a link at your registered email. Choose your new password using that link.',
                  ),
                  _passwordField('Current password', _currentPassword),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _saving ? null : _changePassword,
                      child: Text(
                        _saving ? 'Sending...' : 'Send password reset email',
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => GlassCard(
    padding: const EdgeInsets.all(20),
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
    child: SelectableText(value),
  );

  Widget _passwordField(String label, TextEditingController controller) =>
      TextField(
        controller: controller,
        obscureText: _hidePassword,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          suffixIcon: IconButton(
            tooltip: _hidePassword ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _hidePassword = !_hidePassword),
            icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
          ),
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
