import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';
import '../../services/auth_service.dart';

// ═══════════════════════════════════════════════════════════════
// LOGIN PAGE (Web) — Fleet / operations redesign
// Route: /login
// ═══════════════════════════════════════════════════════════════

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _passwordVisibilityFocusNode = FocusNode(canRequestFocus: false);
  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _emailFocused = false;
  bool _passwordFocused = false;
  bool _isLoading = false;

  late final AnimationController _enterCtrl;
  late final Animation<double> _panelFade;
  late final Animation<Offset> _panelSlide;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;

  static const _brandGreen = Color(0xFF1F8A3D);
  static const _brandDeep = Color(0xFF0F3D24);
  static const _textDark = Color(0xFF1F2933);
  static const _textMuted = Color(0xFF6B7280);
  static const _fieldBorder = Color(0xFFE2E8F0);
  static const _fieldFill = Color(0xFFFAFBFC);

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _panelFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(-0.06, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _cardFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.2, 0.85, curve: Curves.easeOut),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocusNode.dispose();
    _passwordVisibilityFocusNode.dispose();
    super.dispose();
  }

  void _restorePasswordFocus({TextSelection? selection}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _passwordFocusNode.requestFocus();
      if (selection != null) {
        _passwordCtrl.selection = selection;
      }
    });
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    setState(() => _isLoading = true);

    try {
      final result = await AuthService.login(email, password);
      final role = (result['role'] as String?)?.toLowerCase();

      if (!mounted) return;

      if (role != 'admin' && role != 'driver') {
        throw Exception('Invalid role');
      }

      setState(() => _isLoading = false);
      _showLoginSnackBar(success: true);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        role == 'admin' ? '/' : '/driver-dashboard',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showLoginSnackBar(success: false);
      _restorePasswordFocus();
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showLoginSnackBar({required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success
            ? const Color(0xFF1F2933)
            : const Color(0xFF7F1D1D),
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.warning_rounded,
              color: success ? const Color(0xFF4ADE80) : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              success
                  ? 'Login successful — welcome back!'
                  : 'Invalid email or password',
              style: AppTypography.bodyStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Stack(
            fit: StackFit.expand,
            children: [
              const _FleetAtmosphere(),
              if (wide)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Container(
                      margin: const EdgeInsets.all(28),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _brandDeep.withValues(alpha: 0.2),
                            blurRadius: 34,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: 400,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 5,
                              child: FadeTransition(
                                opacity: _cardFade,
                                child: SlideTransition(
                                  position: _cardSlide,
                                  child: _buildFormSide(wide: true),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: FadeTransition(
                                opacity: _panelFade,
                                child: SlideTransition(
                                  position: _panelSlide,
                                  child: _buildBrandPanel(wide: true),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                SafeArea(
                  child: FadeTransition(
                    opacity: _cardFade,
                    child: SlideTransition(
                      position: _cardSlide,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                        child: Column(
                          children: [
                            _buildBrandPanel(wide: false),
                            const SizedBox(height: 28),
                            _buildFormSide(wide: false),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBrandPanel({required bool wide}) {
    return Container(
      width: double.infinity,
      decoration: wide
          ? BoxDecoration(
              color: _brandDeep,
              borderRadius: BorderRadius.circular(24),
            )
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 48 : 8,
        vertical: wide ? 36 : 8,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: wide ? 168 : 132,
            height: wide ? 168 : 132,
            padding: EdgeInsets.all(wide ? 20 : 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(wide ? 32 : 26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.24),
              ),
            ),
            child: Image.asset(
              'assets/images/cpsu logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.local_shipping_rounded,
                color: Colors.white,
                size: wide ? 72 : 56,
              ),
            ),
          ),
          SizedBox(height: wide ? 24 : 16),
          Text(
            'CPSU Motor Pool',
            textAlign: TextAlign.center,
            style: AppTypography.displayTitle(
              color: Colors.white,
              fontSize: 26,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fleet Operations',
            textAlign: TextAlign.center,
            style: AppTypography.labelCaps(
              color: const Color(0xFFB7E4C7).withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSide({required bool wide}) {
    final form = ClipRRect(
      borderRadius: BorderRadius.circular(wide ? 28 : 22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: EdgeInsets.fromLTRB(
            wide ? 28 : 18,
            wide ? 28 : 20,
            wide ? 28 : 18,
            wide ? 28 : 20,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: wide ? 0.92 : 0.94),
            borderRadius: BorderRadius.circular(wide ? 28 : 22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: _brandDeep.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Motor Pool Login',
                style: AppTypography.displayTitle(
                  color: _textDark,
                  fontSize: wide ? 26 : 24,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sign in to continue.',
                style: AppTypography.bodyStyle(
                  color: _textMuted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Email',
                style: AppTypography.bodyStyle(
                  color: _textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: _fieldFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _emailFocused ? _brandGreen : _fieldBorder,
                    width: _emailFocused ? 1.6 : 1,
                  ),
                ),
                child: TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onTap: () => setState(() => _emailFocused = true),
                  onEditingComplete: () {
                    setState(() => _emailFocused = false);
                    _passwordFocusNode.requestFocus();
                  },
                  onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    prefixIcon: Icon(
                      Icons.mail_outline_rounded,
                      color: _textMuted,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Password',
                style: AppTypography.bodyStyle(
                  color: _textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: _fieldFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _passwordFocused ? _brandGreen : _fieldBorder,
                    width: _passwordFocused ? 1.6 : 1,
                  ),
                ),
                child: TextField(
                  controller: _passwordCtrl,
                  focusNode: _passwordFocusNode,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onTap: () => setState(() => _passwordFocused = true),
                  onEditingComplete: () {
                    setState(() => _passwordFocused = false);
                    _handleLogin();
                  },
                  onSubmitted: (_) => _handleLogin(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: _textMuted,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      focusNode: _passwordVisibilityFocusNode,
                      onPressed: () {
                        final selection = _passwordCtrl.selection;
                        setState(() => _obscurePassword = !_obscurePassword);
                        _restorePasswordFocus(selection: selection);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: _textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    height: 22,
                    width: 22,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: _brandGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Remember me',
                    style: AppTypography.bodyStyle(
                      color: _textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _brandGreen.withValues(alpha: 0.7),
                    elevation: 3,
                    shadowColor: _brandGreen.withValues(alpha: 0.28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Log in',
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
    );

    if (!wide) return form;
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: form,
      ),
    );
  }
}

class _FleetAtmosphere extends StatelessWidget {
  const _FleetAtmosphere();

  @override
  Widget build(BuildContext context) {
    return Stack(
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
                Color(0xFF0B2E1A),
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
        CustomPaint(painter: _RoadMapPainter()),
        Positioned(
          right: -80,
          top: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),
        Positioned(
          left: -100,
          bottom: -40,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFB7E4C7).withValues(alpha: 0.08),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoadMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(-20, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.55,
        size.width * 0.48,
        size.height * 0.68,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.82,
        size.width + 40,
        size.height * 0.45,
      );
    canvas.drawPath(path, road);

    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double d = 0;
      while (d < m.length) {
        final next = math.min(d + 14, m.length);
        canvas.drawPath(m.extractPath(d, next), dash);
        d += 28;
      }
    }

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final node = Paint()..color = Colors.white.withValues(alpha: 0.2);
    final nodes = [
      Offset(size.width * 0.18, size.height * 0.28),
      Offset(size.width * 0.42, size.height * 0.22),
      Offset(size.width * 0.66, size.height * 0.34),
      Offset(size.width * 0.78, size.height * 0.58),
    ];
    for (final p in nodes) {
      canvas.drawCircle(p, 4.5, node);
    }
    final link = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.4;
    for (var i = 0; i < nodes.length - 1; i++) {
      canvas.drawLine(nodes[i], nodes[i + 1], link);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

