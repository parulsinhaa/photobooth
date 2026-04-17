// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Primary Palette — Snapchat-level pastel aesthetic
  static const Color pink = Color(0xFFFF6B9D);
  static const Color pinkLight = Color(0xFFFFB3D1);
  static const Color pinkDark = Color(0xFFE91E8C);
  static const Color peach = Color(0xFFFF8C69);
  static const Color peachLight = Color(0xFFFFBEA3);
  static const Color lavender = Color(0xFF9B7FE8);
  static const Color lavenderLight = Color(0xFFC9B8F5);
  static const Color lavenderDark = Color(0xFF6C4DE6);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color mint = Color(0xFF4ECDC4);
  static const Color gold = Color(0xFFFFD93D);
  static const Color electricBlue = Color(0xFF00D4FF);

  // Backgrounds
  static const Color bgDark = Color(0xFF0D0D0D);
  static const Color bgDark2 = Color(0xFF1A1A1A);
  static const Color bgDark3 = Color(0xFF252525);
  static const Color bgCard = Color(0xFF2A2A2A);
  static const Color bgLight = Color(0xFFFAF0F5);
  static const Color bgLightCard = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF6B6B6B);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textDark2 = Color(0xFF333333);

  // Gradients
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D0D0D), Color(0xFF1A0A1A), Color(0xFF0D0D1A)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pink, lavender],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pink, peach, coral],
  );

  static const LinearGradient coolGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lavender, electricBlue],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD93D), Color(0xFFFF8C00)],
  );

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9B7FE8), Color(0xFFFF6B9D), Color(0xFFFFD93D)],
  );

  static const LinearGradient cameraBgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x88000000), Color(0x00000000), Color(0x88000000)],
  );

  // Subscription tiers
  static const Color freeTier = Color(0xFF6B6B6B);
  static const Color proTier = Color(0xFF4ECDC4);
  static const Color premiumTier = Color(0xFFFFD93D);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFB300);
  static const Color info = Color(0xFF2196F3);

  // Glassmorphism
  static Color glassWhite = Colors.white.withOpacity(0.08);
  static Color glassBorder = Colors.white.withOpacity(0.15);
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.pink,
        secondary: AppColors.lavender,
        tertiary: AppColors.peach,
        surface: AppColors.bgDark2,
        background: AppColors.bgDark,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onBackground: AppColors.textPrimary,
      ),
      textTheme: _buildTextTheme(Colors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgDark2,
        selectedItemColor: AppColors.pink,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontFamily: 'Poppins', fontSize: 11),
      ),
      cardTheme: CardTheme(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgDark3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.pink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins'),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'Poppins'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.pink,
          side: const BorderSide(color: AppColors.pink, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgCard,
        contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.08), thickness: 1),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgCard,
        selectedColor: AppColors.pink.withOpacity(0.3),
        labelStyle: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _buildTextTheme(Color color) {
    return TextTheme(
      displayLarge: TextStyle(fontFamily: 'Poppins', fontSize: 57, fontWeight: FontWeight.w700, color: color),
      displayMedium: TextStyle(fontFamily: 'Poppins', fontSize: 45, fontWeight: FontWeight.w700, color: color),
      displaySmall: TextStyle(fontFamily: 'Poppins', fontSize: 36, fontWeight: FontWeight.w600, color: color),
      headlineLarge: TextStyle(fontFamily: 'Poppins', fontSize: 32, fontWeight: FontWeight.w600, color: color),
      headlineMedium: TextStyle(fontFamily: 'Poppins', fontSize: 28, fontWeight: FontWeight.w600, color: color),
      headlineSmall: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w600, color: color),
      titleLarge: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w600, color: color),
      titleMedium: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w500, color: color),
      titleSmall: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: color),
      bodyLarge: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w400, color: color),
      bodyMedium: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w400, color: color),
      bodySmall: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w400, color: color),
      labelLarge: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: color),
      labelMedium: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: color),
      labelSmall: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w500, color: color),
    );
  }
}
