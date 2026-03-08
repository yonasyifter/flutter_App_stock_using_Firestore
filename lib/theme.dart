import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const cream = Color(0xFFF5F0E8);
  static const ink = Color(0xFF1A1208);
  static const brown = Color(0xFF6B4226);
  static const amber = Color(0xFFD4870A);
  static const amberLight = Color(0xFFF0B84A);
  static const green = Color(0xFF2D6A4F);
  static const greenLight = Color(0xFF52B788);
  static const red = Color(0xFFB5323A);
  static const redLight = Color(0xFFE76F51);
  static const paper = Color(0xFFFBF8F2);
  static const rule = Color(0xFFD8CEBF);

  // ── Amharic / Ethiopic font helpers ─────────────
  // Noto Serif Ethiopic  → headings, brand, display text
  // Noto Sans Ethiopic   → body, labels, inputs, everything else

  static TextStyle serifAmharic({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color color = ink,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.notoSerifEthiopic(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle sansAmharic({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = ink,
    FontStyle fontStyle = FontStyle.normal,
    double? letterSpacing,
  }) =>
      GoogleFonts.notoSansEthiopic(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
      );

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: const ColorScheme.light(
        primary: ink,
        secondary: amber,
        surface: paper,
        error: red,
      ),
      textTheme: TextTheme(
        // Serif for display / headings
        displayLarge: serifAmharic(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1),
        displayMedium: serifAmharic(fontSize: 28, fontWeight: FontWeight.w700),
        displaySmall: serifAmharic(fontSize: 22, fontWeight: FontWeight.w700),
        headlineMedium: serifAmharic(fontSize: 18, fontWeight: FontWeight.w700),
        // Sans for body
        titleLarge: sansAmharic(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: sansAmharic(fontSize: 15),
        bodyMedium: sansAmharic(fontSize: 13, color: brown),
        labelSmall: sansAmharic(fontSize: 11, color: brown, letterSpacing: 0.5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: amber, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: sansAmharic(fontSize: 12, color: brown),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: cream,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: sansAmharic(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: rule),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: sansAmharic(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ink,
        foregroundColor: cream,
        elevation: 0,
        titleTextStyle: serifAmharic(fontSize: 20, fontWeight: FontWeight.w700, color: cream),
        iconTheme: const IconThemeData(color: amberLight),
      ),
      dividerTheme: const DividerThemeData(color: rule, thickness: 1),
      cardTheme: CardThemeData(
        color: paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: rule, width: 1.5),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
    );
  }
}

String formatCurrency(double amount) => 'ብር ${amount.toStringAsFixed(2)}';
