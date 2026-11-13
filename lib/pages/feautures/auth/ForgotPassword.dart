import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'package:cpsumotorpooladmin/widgets/app_notification.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';
import 'package:cpsumotorpooladmin/widgets/interaction_loading_overlay.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late final AnimationController _enterController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _isLoading = false;
  bool _submitted = false;

  Timer? _cooldownTimer;
  final _attempts = <String, int>{};
  final _quotaExpires = <String, DateTime>{};
  final _cooldownUntil = <String, DateTime>{};
  String get _email => _emailController.text.trim().toLowerCase();
  int get _secondsLeft {
    final until = _cooldownUntil[_email];
    if (until == null) return 0;
    return (until.difference(DateTime.now()).inMilliseconds / 1000)
        .ceil()
        .clamp(0, 86400);
  }

  String get _countdown =>
      '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}';

  void _recordQuota(String email, {int? remaining, int retryAfter = 0}) {
    final now = DateTime.now();
    if (remaining != null) {
      _attempts[email] = remaining;
      _quotaExpires[email] = now.add(const Duration(minutes: 5));
    }
    if (retryAfter > 0) {
      _cooldownUntil[email] = now.add(Duration(seconds: retryAfter));
    }
  }

  @override
  void initState() {
    super.initState();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        final now = DateTime.now();
        for (final email in _quotaExpires.keys.toList()) {
          if (!now.isBefore(_quotaExpires[email]!)) {
            _attempts.remove(email);
            _quotaExpires.remove(email);
          }
        }
        _cooldownUntil.removeWhere((_, until) => !now.isBefore(until));
      });
    });
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _enterController, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic),
        );
    _enterController.forward();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _enterController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || _secondsLeft > 0 || !_formKey.currentState!.validate()) {
      return;
    }
    final email = _email;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _submitted = false;
    });

    try {
      final result = await AuthService.requestPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _recordQuota(
          email,
          remaining: result.attemptsRemaining,
          retryAfter: result.retryAfter,
        );
        _submitted = _email == email;
      });
    } on PasswordResetLimitException catch (error) {
      if (mounted) {
        setState(() => _recordQuota(email, retryAfter: error.retryAfter));
        AppNotification.showMessage(error.message, isError: true);
      }
    } on LoginException catch (error) {
      if (mounted) {
        AppNotification.showMessage(error.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        AppNotification.showMessage(
          'Unable to send the request. Check your connection and try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F3D24),
                  Color(0xFF176E30),
                  Color(0xFF1F8A3D),
                ],
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.97),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF0F3D24,
                              ).withValues(alpha: 0.2),
                              blurRadius: 34,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                tooltip: 'Back to login',
                                icon: const Icon(Icons.arrow_back_rounded),
                                style: IconButton.styleFrom(
                                  foregroundColor: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Icon(
                                Icons.lock_reset_rounded,
                                color: AppColors.primary,
                                size: 40,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Forgot password?',
                                style: AppTypography.displayTitle(
                                  color: const Color(0xFF1F2933),
                                  fontSize: 25,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Enter the email address linked to your account. If it is registered, we will send password reset instructions.',
                                style: AppTypography.bodyStyle(
                                  color: const Color(0xFF6B7280),
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'Email',
                                style: AppTypography.bodyStyle(
                                  color: const Color(0xFF1F2933),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                enabled: !_isLoading,
                                onChanged: (_) =>
                                    setState(() => _submitted = false),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.email],
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  hintText: 'name@cpsu.edu.ph',
                                  prefixIcon: const Icon(
                                    Icons.mail_outline_rounded,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFFAFBFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1F8A3D),
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) return 'Enter your email.';
                                  if (!RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  ).hasMatch(email)) {
                                    return 'Enter a valid email address.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _secondsLeft > 0
                                      ? const Color(0xFFFFF3E0)
                                      : const Color(0xFFEAF6EE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _secondsLeft > 0
                                      ? 'Please wait $_countdown before requesting another link.'
                                      : _attempts.containsKey(_email)
                                      ? '${_attempts[_email]} of 3 attempts remaining. A 5-minute cooldown follows the third attempt.'
                                      : 'Up to 3 attempts per email, then a 5-minute cooldown.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_submitted) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF6EE),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Request received',
                                              style: AppTypography.bodyStyle(
                                                color: AppColors.brandDeep,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'If an account exists with this email, you will receive password reset instructions. Check your inbox and spam folder.',
                                              style: AppTypography.bodyStyle(
                                                color: AppColors.brandDeep,
                                                fontSize: 13,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading || _secondsLeft > 0
                                      ? null
                                      : _submit,
                                  child: Text(
                                    _secondsLeft > 0
                                        ? 'Try again in $_countdown'
                                        : _submitted
                                        ? 'Send another link'
                                        : 'Send Reset Link',
                                    style: AppTypography.buttonLabel(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const InteractionLoadingOverlay(
              message: 'Sending reset instructions...',
            ),
        ],
      ),
    );
  }
}
