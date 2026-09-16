import 'dart:ui';
import 'package:flutter/material.dart';

/// Glassmorphic Executive Dark Design System
/// Aesthetic: Deep Obsidian Void with Frosted Glass Overlay
class AppTheme {
  // Core Obsidian & Cyber Palette
  static const Color obsidianVoid = Color(0xFF05080E);
  static const Color frostedCharcoalSlate = Color(0xFF0D131F);
  static const Color cyberBorder = Color(0xFF1E293B);
  static const Color cyberBorderSubtle = Color(0xFF162032);

  // Accents & Dispatch Channels
  static const Color electricCyan = Color(0xFF00F2FE); // Primary Accent
  static const Color mintEmerald = Color(0xFF10B981); // WhatsApp Channel
  static const Color royalIris = Color(0xFF6366F1); // Email Channel
  static const Color amberAccent = Color(0xFFF59E0B); // Warning / Follow-up
  static const Color crimsonAccent = Color(0xFFEF4444); // Error / Disqualified
  static const Color royalGold = Color(0xFFD4AF37); // Quotation / VIP
  static const Color saudiEmerald = Color(0xFF006C4F); // Saudi Heritage Accent

  // Typography
  static const Color crispAlabaster = Color(0xFFF8FAFC);
  static const Color mutedSilver = Color(0xFF94A3B8);
  static const Color darkSlate = Color(0xFF0F172A);

  // Legacy & Theme Compatibility Aliases
  static const Color slateNavy = Color(0xFF0F172A);
  static const Color slateSurface = Color(0xFF1E293B);
  static const Color cardBg = Color(0xFF0D131F);
  static const Color textDark = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderGrey = Color(0xFF1E293B);

  // Status mapping
  static const Color statusNew = Color(0xFF00F2FE); // Electric Cyan
  static const Color statusContacted = Color(0xFFF59E0B); // Amber
  static const Color statusInterested = Color(0xFF10B981); // Mint Emerald
  static const Color statusClosed = Color(0xFF6366F1); // Royal Iris
  static const Color statusDisqualified = Color(0xFFEF4444); // Crimson

  // Helper for backward-compatible and zero-precision-loss alpha
  static Color withAlphaFactor(Color color, double opacity) {
    return color.withValues(alpha: opacity.clamp(0.0, 1.0));
  }

  /// Glassmorphic frosted container decoration
  static BoxDecoration glassBoxDecoration({
    Color? surfaceColor,
    Color? borderColor,
    double opacity = 0.85,
    double borderRadius = 14,
    bool showBorder = true,
  }) {
    return BoxDecoration(
      color: withAlphaFactor(surfaceColor ?? frostedCharcoalSlate, opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: showBorder
          ? Border.all(
              color: borderColor ?? cyberBorder,
              width: 1.0,
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Executive Dark ThemeData (Material 3 with Impeller optimizations)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: obsidianVoid,
      primaryColor: electricCyan,
      colorScheme: ColorScheme.dark(
        primary: electricCyan,
        secondary: royalIris,
        surface: frostedCharcoalSlate,
        onPrimary: obsidianVoid,
        onSecondary: crispAlabaster,
        onSurface: crispAlabaster,
        error: crimsonAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: obsidianVoid,
        foregroundColor: crispAlabaster,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: crispAlabaster,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: withAlphaFactor(frostedCharcoalSlate, 0.85),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: cyberBorder, width: 1.0),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: withAlphaFactor(frostedCharcoalSlate, 0.9),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: crispAlabaster,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: cyberBorder, width: 0.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: electricCyan,
          foregroundColor: obsidianVoid,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: withAlphaFactor(frostedCharcoalSlate, 0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cyberBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cyberBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: electricCyan, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: mutedSilver, fontSize: 13),
        labelStyle: const TextStyle(color: mutedSilver, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: cyberBorder,
        thickness: 0.8,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: crispAlabaster,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: crispAlabaster,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: crispAlabaster,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: crispAlabaster,
        ),
        bodyMedium: TextStyle(
          color: mutedSilver,
        ),
        bodySmall: TextStyle(
          color: mutedSilver,
          fontSize: 12,
        ),
      ),
    );
  }

  // Backward compatible alias
  static ThemeData get lightTheme => darkTheme;
}

/// Impeller-Optimized Frosted Glass Container
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final double blur;
  final double opacity;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 14,
    this.borderColor,
    this.blur = 10,
    this.opacity = 0.85,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      margin: margin,
      decoration: AppTheme.glassBoxDecoration(
        borderColor: borderColor,
        opacity: opacity,
        borderRadius: borderRadius,
      ),
      child: child,
    );

    if (blur > 0) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    return content;
  }
}
