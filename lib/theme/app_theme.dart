import 'package:flutter/material.dart';

class AppTheme {
  // Saudi Corporate Color Palette
  static const Color saudiEmerald = Color(0xFF006C4F);
  static const Color saudiEmeraldDark = Color(0xFF004D38);
  static const Color royalGold = Color(0xFFD4AF37);
  static const Color royalGoldLight = Color(0xFFF3E5AB);
  static const Color slateNavy = Color(0xFF0F172A);
  static const Color slateSurface = Color(0xFF1E293B);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderGrey = Color(0xFFE2E8F0);

  // Status Badge Colors
  static const Color statusNew = Color(0xFF3B82F6); // Blue
  static const Color statusContacted = Color(0xFFF59E0B); // Amber
  static const Color statusInterested = Color(0xFF10B981); // Emerald Green
  static const Color statusClosed = Color(0xFF8B5CF6); // Purple/Royal
  static const Color statusDisqualified = Color(0xFFEF4444); // Red

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      primaryColor: saudiEmerald,
      colorScheme: ColorScheme.fromSeed(
        seedColor: saudiEmerald,
        primary: saudiEmerald,
        secondary: royalGold,
        surface: cardBg,
        background: const Color(0xFFF8FAFC),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: saudiEmerald,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardTheme(
        color: cardBg,
        elevation: 1.5,
        shadowColor: Colors.black.withOpacity(0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderGrey, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: saudiEmerald,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: saudiEmerald, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
