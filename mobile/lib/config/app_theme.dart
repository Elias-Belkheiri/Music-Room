import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Acid Noir — Music Room design system (see DESIGN.md).
/// Black first, one loud acid-yellow accent, soft geometry, no shadows.
class AppTheme {
  // ── Color tokens ────────────────────────────────────────────────────
  static const Color background = Color(0xFF1C1C1C); // color-bg
  static const Color surface = Color(0xFF262626); // color-surface
  static const Color surfaceRaised = Color(0xFF2E2E2E); // color-surface-raised
  static const Color accent = Color(0xFFE9FE5C); // color-accent
  static const Color onAccent = Color(0xFF141414); // color-on-accent
  static const Color textPrimary = Color(0xFFF4F4F4);
  static const Color textSecondary = Color(0xFF9A9A9A);
  static const Color danger = Color(0xFFFF4D4D);
  static const Color unplayedBar = Color(0xFF5A5A5A);

  // Backwards-compat aliases (old code references these)
  static const Color surfaceLight = surfaceRaised;
  static const Color accentLight = accent;
  static const Color textMuted = textSecondary;
  static const Color error = danger;
  static const Color inputFill = surface;
  static const Color divider = surfaceRaised;

  // ── Radii ───────────────────────────────────────────────────────────
  static const double radiusSm = 12;
  static const double radiusMd = 20;
  static const double radiusLg = 28;
  static const double radiusPill = 999;

  // ── Scrim (mandatory on image cards with text) ──────────────────────
  static const LinearGradient scrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [
      Color.fromRGBO(0, 0, 0, 0.85),
      Color.fromRGBO(0, 0, 0, 0.35),
      Color.fromRGBO(0, 0, 0, 0.0),
    ],
    stops: [0.0, 0.45, 0.75],
  );

  // ── Typography (Space Grotesk) ──────────────────────────────────────
  static TextStyle get display => GoogleFonts.spaceGrotesk(
        fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5,
        color: textPrimary,
      );
  static TextStyle get titleLg => GoogleFonts.spaceGrotesk(
        fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary,
      );
  static TextStyle get titleMd => GoogleFonts.spaceGrotesk(
        fontSize: 17, fontWeight: FontWeight.w500, color: textPrimary,
      );
  static TextStyle get body => GoogleFonts.spaceGrotesk(
        fontSize: 15, fontWeight: FontWeight.w400, color: textPrimary,
      );
  static TextStyle get caption => GoogleFonts.spaceGrotesk(
        fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary,
      );
  static TextStyle get label => GoogleFonts.spaceGrotesk(
        fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary,
      );

  // ── ThemeData ───────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final base = ThemeData(brightness: Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
        error: danger,
        onPrimary: onAccent,
        onSecondary: onAccent,
        onSurface: textPrimary,
        onError: textPrimary,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusPill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusPill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusPill),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusPill),
          borderSide: const BorderSide(color: danger, width: 1),
        ),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 15),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 15),
        errorStyle: const TextStyle(color: danger, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: surfaceRaised,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceRaised,
        selectedColor: accent,
        labelStyle: caption,
        shape: const StadiumBorder(),
        elevation: 0,
        pressElevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
        elevation: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
        ),
        elevation: 0,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceRaised,
        contentTextStyle: TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
    );
  }
}
