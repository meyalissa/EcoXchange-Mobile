import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

/// EcoXchange Mobile — shared Material theme, rebuilt (Phase 4C.3) to
/// match the approved HTML/CSS design's real tokens (see design_tokens.dart)
/// rather than a generic Material seed colour. Plus Jakarta Sans is the
/// body/UI typeface; Sora is used for a handful of large display numbers/
/// headings exactly where the HTML design uses it (see [displayFont] —
/// applied ad hoc on those specific widgets, not globally, matching the
/// design's own selective use).
class AppTheme {
  AppTheme._();

  /// Kept for any pre-existing reference — now an alias for the real
  /// design's primary green.
  static const Color primaryGreen = AppColors.green500;

  static TextStyle displayFont({required double fontSize, required FontWeight fontWeight, Color? color}) {
    return GoogleFonts.sora(fontSize: fontSize, fontWeight: fontWeight, color: color);
  }

  /// Shared "header identity name" style — the signed-in user's OWN name,
  /// shown next to their avatar in a gradient hero header (Customer/Rider
  /// Home greeting, Customer/Rider Profile). Deliberately smaller/lighter
  /// than a true page title (e.g. "Rewards Hub"/"Pickup Hub", which use
  /// [displayFont] directly at 26/w900) — a real name is longer and more
  /// variable than a short page title, so giving it the same display-grade
  /// weight let it visually dominate the header instead of reading as a
  /// title (Typography Polish pass). Still Sora/bold so it stays prominent;
  /// just a tier below the actual page title.
  static TextStyle headerIdentityName({Color color = Colors.white}) {
    return GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w800, color: color);
  }

  static ThemeData get light {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green500,
        brightness: Brightness.light,
        primary: AppColors.green500,
        secondary: AppColors.green600,
        surface: AppColors.n0,
        error: AppColors.red,
      ),
      scaffoldBackgroundColor: AppColors.n50,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.n0,
        foregroundColor: AppColors.n800,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.n800),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green500,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.r12)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.green600,
          side: const BorderSide(color: AppColors.green200, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.r12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.n600,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.n50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.r12),
          borderSide: const BorderSide(color: AppColors.n200, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.r12),
          borderSide: const BorderSide(color: AppColors.n200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.r12),
          borderSide: const BorderSide(color: AppColors.green400, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.n400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: AppColors.n0,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.r16)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.n100, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.n100,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.n600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.rFull)),
        side: BorderSide.none,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
