import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../router/app_router_delegate.dart';
import '../widgets/google_sign_in_button.dart';

/// Unified Auth landing screen + Splash Screen experience.
class AuthScreen extends StatefulWidget {
  final AppRouterDelegate routerDelegate;

  const AuthScreen({super.key, required this.routerDelegate});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _riseController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _riseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // Initial check session logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.authStatus == AuthStatus.loading) {
        // Run animation, then check session status
        _riseController.forward().then((_) {
          auth.checkSession();
        });
      } else {
        // Already loaded, jump animation to the end instantly
        _riseController.value = 1.0;
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _riseController.dispose();
    super.dispose();
  }

  // Reusable modern text style helper
  TextStyle _modernStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color color = Colors.white,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    bool isTitle = false,
  }) {
    if (isTitle) {
      return GoogleFonts.anton(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
        decorationColor: decorationColor,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── 1. Base background (Acid Noir dark) ────────────────────────────
          Container(
            color: AppTheme.background,
            width: double.infinity,
            height: double.infinity,
          ),

          // ── 2. Splash Components (Static in the background) ────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                Text(
                  'MUSICROOM',
                  style: GoogleFonts.anton(
                    color: Colors.white,
                    fontSize: 52,
                    letterSpacing: -1.5,
                  ),
                ),
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

          // ── 3. Rising Black Wave Shape ─────────────────────────────────────
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

          // ── 4. Auth Content ─────────────────────────────────────────────────
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: size.height * 0.30),
                    Text(
                      'WELCOME TO\nMUSICROOM',
                      style: _modernStyle(
                        fontSize: 60,
                        isTitle: true,
                        height: 0.95,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        style: _modernStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'Sign up for free or '),
                          TextSpan(
                            text: 'log in',
                            style: _modernStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => widget.routerDelegate.navigateToLogin(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => widget.routerDelegate.navigateToSignup(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: AppTheme.onAccent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusPill),
                          ),
                        ),
                        child: Text(
                          'Continue with email',
                          style: _modernStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: AppTheme.onAccent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: AppTheme.textSecondary.withValues(alpha: 0.3),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'or',
                            style: _modernStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: AppTheme.textSecondary.withValues(alpha: 0.3),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildGoogleSignInPlatformButton(
                          size: 60,
                          onPressed: () async {
                            final auth = Provider.of<AuthProvider>(context, listen: false);
                            final success = await auth.signInWithGoogle();
                            if (!success && context.mounted && auth.errorMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(auth.errorMessage!)),
                              );
                            }
                          },
                          child: const _GoogleLogo(size: 24),
                        ),
                      ],
                    ),
                    const Spacer(),
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
// Google "G" logo
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.white);

    final segments = [
      (0.0, 0.5 * 3.14159, const Color(0xFF4285F4)),
      (0.5 * 3.14159, 0.5 * 3.14159, const Color(0xFF34A853)),
      (1.0 * 3.14159, 0.5 * 3.14159, const Color(0xFFFBBC05)),
      (1.5 * 3.14159, 0.5 * 3.14159, const Color(0xFFEA4335)),
    ];

    for (final seg in segments) {
      final paint = Paint()
        ..color = seg.$3
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.38;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.62),
        seg.$1, seg.$2, false, paint,
      );
    }

    canvas.drawCircle(Offset(cx, cy), r * 0.43, Paint()..color = Colors.white);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.1, r * 0.7, r * 0.2),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Rising Black wavy background shape
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
    final dy = size.height * 0.015;
    final dx = size.width * 0.02;

    final curvedRise = Curves.easeInOutCubic.transform(riseProgress);
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

// ─────────────────────────────────────────────────────────────────────────────
// Rising Black wavy background shape (Clipper for Auth Content)
// ─────────────────────────────────────────────────────────────────────────────
class _RisingBlackWavesClipper extends CustomClipper<Path> {
  final double animationValue;
  final double riseProgress;

  _RisingBlackWavesClipper(this.animationValue, this.riseProgress);

  @override
  Path getClip(Size size) {
    final path = Path();

    // If the wave is fully risen, do not clip anything to ensure all gestures register perfectly
    if (riseProgress >= 0.99) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      return path;
    }

    final t = animationValue * 2 * pi;
    final dy = size.height * 0.015;
    final dx = size.width * 0.02;

    final curvedRise = Curves.easeInOutCubic.transform(riseProgress);
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
    return path;
  }

  @override
  bool shouldReclip(covariant _RisingBlackWavesClipper oldClipper) {
    return oldClipper.animationValue != animationValue || 
           oldClipper.riseProgress != riseProgress;
  }
}
