import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';

/// Splash screen shown on app launch.
/// Displays the MusicRoom brand while checking for a persisted session.
/// Dark background with animated fade-in of the logo and name.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _riseController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    // Wave animation (continuous)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Rising animation (bottom to top)
    _riseController = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 2000),
    );

    // Fade + scale animation for the logo that happens as the wave rises
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _riseController, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _riseController, curve: const Interval(0.0, 0.4, curve: Curves.elasticOut)),
    );

    // Start rise, then check session to trigger navigation
    _riseController.forward().then((_) {
      Provider.of<AuthProvider>(context, listen: false).checkSession();
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _riseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Rising Black Wave ───────────────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_waveController, _riseController]),
              builder: (context, _) {
                return CustomPaint(
                  painter: _RisingBlackWavesPainter(
                    _waveController.value,
                    _riseController.value,
                  ),
                );
              },
            ),
          ),

          // ── Foreground Splash Content ───────────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Modern Logo ──────────────────────────────────────────
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLg),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.headphones_rounded,
                          size: 80,
                          color: AppTheme.onAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── App name ───────────────────────────────────────────
                    Text(
                      'MUSICROOM',
                      style: GoogleFonts.anton(
                        color: Colors.white,
                        fontSize: 52,
                        letterSpacing: -1.5,
                      ),
                    ),
                    
                    // ── Subtitle ───────────────────────────────────────────
                    Text(
                      'Your Music. Your Room.',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Black wavy background shape that rises from the bottom
// ─────────────────────────────────────────────────────────────────────────────
class _RisingBlackWavesPainter extends CustomPainter {
  final double animationValue;
  final double riseProgress;

  _RisingBlackWavesPainter(this.animationValue, this.riseProgress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.surface;
    final path = Path();

    final t = animationValue * 2 * pi;
    final dy = size.height * 0.015; // Vertical sway
    final dx = size.width * 0.02;   // Horizontal sway

    // Apply an easing curve to the rise progress for a smooth arrival
    final curvedRise = Curves.easeInOutCubic.transform(riseProgress);
    
    // When riseProgress is 0, offset is full height (hidden at bottom).
    // When riseProgress is 1, offset is 0 (exact target position).
    final yOffset = (1 - curvedRise) * size.height;

    path.moveTo(0, size.height);
    path.lineTo(size.width, size.height);
    
    path.lineTo(size.width, yOffset + size.height * 0.30 + sin(t) * dy);

    path.quadraticBezierTo(
      size.width * 0.85 + cos(t) * dx, yOffset + size.height * 0.14 + sin(t + 1) * dy,
      size.width * 0.72 + cos(t + 1) * dx, yOffset + size.height * 0.26 + sin(t + 2) * dy,
    );

    path.quadraticBezierTo(
      size.width * 0.52 + cos(t + 2) * dx, yOffset + size.height * 0.06 + sin(t + 3) * dy,
      size.width * 0.38 + cos(t + 3) * dx, yOffset + size.height * 0.28 + sin(t + 4) * dy,
    );

    path.quadraticBezierTo(
      size.width * 0.14 + cos(t + 4) * dx, yOffset + size.height * 0.00 + sin(t + 5) * dy,
      0, yOffset + size.height * 0.16 + sin(t + 6) * dy,
    );

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RisingBlackWavesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || 
           oldDelegate.riseProgress != riseProgress;
  }
}
