import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _usePin = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _toggleLoginMode() {
    setState(() {
      _usePin = !_usePin;
      _passwordCtrl.clear();
      _pinCtrl.clear();
    });
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final success = await auth.login(
        loginId: _usernameCtrl.text.trim(),
        passwordOrPin:
        _usePin ? _pinCtrl.text.trim() : _passwordCtrl.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        final currentUser = auth.currentUser;
        if (currentUser != null) {
          context.read<LanguageProvider>().initFromUser(
            currentUser.preferredLanguage,
          );
        }

        setState(() => _isLoading = false);

        // No manual context.go() here.
        // Router redirect will move authenticated users to dashboard.
        return;
      }

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _usePin
                ? 'Invalid username/email or PIN'
                : 'Invalid username/email or password',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.surface3,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          margin: const EdgeInsets.all(AppConstants.spaceMd),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Login failed. Please try again.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.surface3,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          margin: const EdgeInsets.all(AppConstants.spaceMd),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.05),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  AppConstants.spaceLg,
                  0,
                  AppConstants.spaceLg,
                  bottomInset + AppConstants.spaceLg,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: size.height * 0.06),
                      FadeInDown(
                        duration: const Duration(milliseconds: 700),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0D3B52),
                                    Color(0xFF0A2E3E),
                                  ],
                                ),
                                border: Border.all(
                                  color:
                                  AppColors.primary.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.25),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: CustomPaint(
                                  size: const Size(36, 36),
                                  painter: _MiniLogoPainter(),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppConstants.spaceMd),
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  AppColors.primaryGradient.createShader(bounds),
                              child: const Text(
                                'CAPTRIO',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: size.height * 0.05),
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        duration: const Duration(milliseconds: 600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome back',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spaceXs),
                            const Text(
                              'Sign in to continue',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceLg),
                      FadeInUp(
                        delay: const Duration(milliseconds: 300),
                        duration: const Duration(milliseconds: 600),
                        child: _ModeToggle(
                          usePin: _usePin,
                          onToggle: _toggleLoginMode,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceLg),
                      FadeInUp(
                        delay: const Duration(milliseconds: 350),
                        duration: const Duration(milliseconds: 600),
                        child: _GlassField(
                          controller: _usernameCtrl,
                          label: 'Username or Email',
                          hint: 'Enter your username or email',
                          icon: Icons.person_outline_rounded,
                          validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Please enter your username or email'
                              : null,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceMd),
                      FadeInUp(
                        delay: const Duration(milliseconds: 400),
                        duration: const Duration(milliseconds: 600),
                        child: _usePin
                            ? _GlassField(
                          controller: _pinCtrl,
                          label: 'PIN',
                          hint: 'Enter your PIN',
                          icon: Icons.pin_outlined,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 6,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your PIN';
                            }
                            if (v.trim().length < 4) {
                              return 'PIN must be at least 4 digits';
                            }
                            return null;
                          },
                        )
                            : _GlassField(
                          controller: _passwordCtrl,
                          label: 'Password',
                          hint: 'Enter your password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Please enter your password'
                              : null,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceXl),
                      FadeInUp(
                        delay: const Duration(milliseconds: 450),
                        duration: const Duration(milliseconds: 600),
                        child: _GradientButton(
                          label: 'Sign In',
                          isLoading: _isLoading,
                          onTap: _handleLogin,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceLg),
                      FadeInUp(
                        delay: const Duration(milliseconds: 500),
                        duration: const Duration(milliseconds: 600),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Divider(color: AppColors.divider),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.spaceMd,
                              ),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: AppColors.divider),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceLg),
                      FadeInUp(
                        delay: const Duration(milliseconds: 550),
                        duration: const Duration(milliseconds: 600),
                        child: _OutlineButton(
                          label: 'Create New Account',
                          onTap: _isLoading
                              ? () {}
                              : () => context.go(AppConstants.routeRegister),
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceXl),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool usePin;
  final VoidCallback onToggle;
  const _ModeToggle({required this.usePin, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _ToggleTab(
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            isActive: !usePin,
            onTap: usePin ? onToggle : null,
          ),
          _ToggleTab(
            label: 'PIN',
            icon: Icons.pin_outlined,
            isActive: usePin,
            onTap: !usePin ? onToggle : null,
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;
  const _ToggleTab({
    required this.label,
    required this.icon,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: AppConstants.animFast),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isActive ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? AppColors.textDark : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.textDark : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final int? maxLength;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.validator,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppConstants.spaceXs + 2),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLength: maxLength,
          validator: validator,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;
  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.textDark,
              ),
            ),
          )
              : Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final teal = const Color(0xFF00D4AA);
    final white = Colors.white;
    final w = size.width;
    final h = size.height;

    final arcPaint = Paint()
      ..color = teal
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.42, h * 0.5),
        width: w * 0.72,
        height: h * 0.72,
      ),
      -2.4,
      4.8,
      false,
      arcPaint,
    );

    arcPaint.strokeWidth = 1.8;
    arcPaint.color = teal.withValues(alpha: 0.6);

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.42, h * 0.5),
        width: w * 0.48,
        height: h * 0.48,
      ),
      -2.0,
      4.0,
      false,
      arcPaint,
    );

    final linePaint = Paint()
      ..color = white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(w * 0.52, h * 0.36),
      Offset(w * 0.88, h * 0.36),
      linePaint,
    );
    canvas.drawLine(
      Offset(w * 0.52, h * 0.50),
      Offset(w * 0.88, h * 0.50),
      linePaint,
    );
    canvas.drawLine(
      Offset(w * 0.52, h * 0.64),
      Offset(w * 0.76, h * 0.64),
      linePaint,
    );

    canvas.drawCircle(
      Offset(w * 0.88, h * 0.64),
      2.2,
      Paint()..color = teal,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}