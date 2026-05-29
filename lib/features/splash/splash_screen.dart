import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Stack(
          children: [
            Positioned(
              top: -size.height * 0.1,
              left: -size.width * 0.2,
              child: _GlowCircle(
                size: size.width * 0.8,
                color: AppColors.primary.withValues(alpha: 0.07),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.05,
              right: -size.width * 0.2,
              child: _GlowCircle(
                size: size.width * 0.7,
                color: AppColors.secondary.withValues(alpha: 0.06),
              ),
            ),
            Positioned(
              top: size.height * 0.35,
              left: size.width * 0.5,
              child: _GlowCircle(
                size: size.width * 0.4,
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
            ),
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spaceLg,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  return Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Transform.scale(
                                        scale: _pulseAnimation.value,
                                        child: Container(
                                          width: 130,
                                          height: 130,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.2),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Transform.scale(
                                        scale: _pulseAnimation.value * 0.88,
                                        child: Container(
                                          width: 130,
                                          height: 130,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.35),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      child!,
                                    ],
                                  );
                                },
                                child: FadeInDown(
                                  duration: const Duration(milliseconds: 900),
                                  child: Container(
                                    width: 110,
                                    height: 110,
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
                                        color: AppColors.primary
                                            .withValues(alpha: 0.6),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.35),
                                          blurRadius: 32,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const _CaptioLogo(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              FadeInUp(
                                delay: const Duration(milliseconds: 400),
                                duration: const Duration(milliseconds: 700),
                                child: ShaderMask(
                                  shaderCallback: (bounds) =>
                                      AppColors.primaryGradient
                                          .createShader(bounds),
                                  child: const Text(
                                    'CAPTRIO',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FadeInUp(
                                delay: const Duration(milliseconds: 650),
                                duration: const Duration(milliseconds: 700),
                                child: const Text(
                                  AppConstants.appTagline,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppConstants.spaceLg,
                        right: AppConstants.spaceLg,
                        bottom: AppConstants.spaceXl,
                      ),
                      child: FadeIn(
                        delay: const Duration(milliseconds: 1000),
                        duration: const Duration(milliseconds: 600),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 140,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusFull,
                                ),
                                child: const LinearProgressIndicator(
                                  minHeight: 2.5,
                                  backgroundColor: AppColors.surface2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppConstants.spaceMd),
                            const Text(
                              'Empowering every conversation',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptioLogo extends StatelessWidget {
  const _CaptioLogo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        size: const Size(58, 58),
        painter: _LogoPainter(),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final teal = const Color(0xFF00D4AA);
    final white = Colors.white;
    final w = size.width;
    final h = size.height;

    final arcPaint = Paint()
      ..color = teal
      ..strokeWidth = 3.2
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

    arcPaint.strokeWidth = 2.8;
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
      ..strokeWidth = 2.8
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

    final dotPaint = Paint()
      ..color = teal
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.88, h * 0.64), 3.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}