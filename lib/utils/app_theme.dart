import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App Theme Configuration
/// Defines colors, typography, and styling for the entire app

class AppTheme {
  // Primary Colors - Deep Professional Blue (from reference image)
  static const Color primaryGreen = Color(0xFF1E3A5F); // Deep Navy Blue (kept name for compatibility)
  static const Color primaryYellow = Color(0xFF2C5F8D); // Medium Blue (kept name for compatibility)
  static const Color primaryRed = Color(0xFF1A2F4F); // Darker Navy (kept name for compatibility)

  // Accent Colors - Minimal Orange Usage
  static const Color accentYellow = Color(0xFFFFA726); // Orange for CTAs only (minimal usage)
  static const Color accentOrange = Color(0xFFFFA726); // Orange accent

  // Secondary Colors - Blue Gradient Shades
  static const Color darkGreen = Color(0xFF152238); // Very Dark Navy for deep gradients
  static const Color lightGreen = Color(0xFF3D7AB8); // Lighter Blue for accents

  // Neutral Colors - Professional White & Light Gray-Blue
  static const Color backgroundColor = Color(0xFF1E3A5F); // Deep navy background
  static const Color cardColor = Color(0xFFD1DBE8); // Light blue-gray for cards
  static const Color glassCardColor = Color(0x40FFFFFF); // Semi-transparent white for glassmorphism
  static const Color textPrimary = Color(0xFFFFFFFF); // White text on dark backgrounds
  static const Color textSecondary = Color(0xFFB8C5D6); // Light gray-blue for secondary text
  static const Color dividerColor = Color(0x30FFFFFF); // Semi-transparent white divider

  // Status Colors
  static const Color successGreen = Color(0xFF10B981); // Keep green for success
  static const Color errorRed = Color(0xFFEF4444); // Keep red for errors
  static const Color warningOrange = Color(0xFFFFA726); // Orange for warnings
  static const Color infoBlue = Color(0xFF3D7AB8); // Blue for info

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryGreen,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,

    // Color Scheme
    colorScheme: const ColorScheme.light(
      primary: primaryGreen,
      secondary: primaryYellow,
      surface: cardColor,
      error: errorRed,
      onPrimary: Colors.white,
      onSecondary: textPrimary,
      onSurface: textPrimary,
      onError: Colors.white,
    ),

    // AppBar Theme
    appBarTheme: AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),

    // Text Theme
    textTheme: TextTheme(
      displayLarge: GoogleFonts.cairo(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displayMedium: GoogleFonts.cairo(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displaySmall: GoogleFonts.cairo(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineSmall: GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.cairo(
        fontSize: 16,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.cairo(
        fontSize: 14,
        color: textPrimary,
      ),
      bodySmall: GoogleFonts.cairo(
        fontSize: 12,
        color: textSecondary,
      ),
    ),

    // Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorRed),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    // Card Theme
    cardTheme: const CardThemeData(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );

  // Dark Theme - Professional Blue & White
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryGreen, // Blue
    scaffoldBackgroundColor: const Color(0xFF0F172A), // Dark blue-gray
    cardColor: const Color(0xFF1E293B), // Dark blue-tinted gray

    colorScheme: const ColorScheme.dark(
      primary: primaryGreen, // Blue
      secondary: lightGreen, // Light Blue
      surface: Color(0xFF1E293B),
      error: errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onError: Colors.white,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1E293B), // Dark blue-tinted gray
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),

    textTheme: TextTheme(
      displayLarge: GoogleFonts.cairo(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      bodyLarge: GoogleFonts.cairo(
        fontSize: 16,
        color: Colors.white,
      ),
    ),
  );

  // Common Decorations - Professional Glassmorphism Style
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );

  // Glassmorphism card with semi-transparent white
  static BoxDecoration glassCardDecoration = BoxDecoration(
    color: glassCardColor,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: Colors.white.withOpacity(0.2),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );

  // Deep blue gradient background (from reference image)
  static BoxDecoration gradientDecoration = const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF1E3A5F), Color(0xFF2C5F8D)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  // Alternative gradient for cards
  static BoxDecoration cardGradientDecoration = BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFD1DBE8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
}
