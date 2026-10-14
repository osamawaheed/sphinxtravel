import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ─── Locale-aware font helper ─────────────────────────────────────────────
  /// Returns a [TextStyle] using Tajawal for Arabic locale, Inter otherwise.
  /// Use this in every widget instead of hardcoding GoogleFonts.inter().
  static TextStyle appFont(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (isArabic) {
      return GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // SPHINX TRAVEL Design System Colors — Light
  static const Color mainBackground = Color(0xFFF7F5F0);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF172331);
  static const Color brandNavy = Color(0xFF123047);
  static const Color luxuryAccent = Color(0xFFC6A15B);
  static const Color softGoldBg = Color(0xFFF2E8D5);
  static const Color secondaryText = Color(0xFF68727D);
  static const Color borderColor = Color(0xFFE7E3DC);
  static const Color successGreen = Color(0xFF5D8A72);
  static const Color errorRed = Color(0xFFD94F4F);
  static const Color shadowColor = Color(0x0F172331);

  // SPHINX TRAVEL Design System Colors — Dark
  static const Color darkBackground = Color(0xFF0F1923);
  static const Color darkCard = Color(0xFF1A2535);
  static const Color darkPrimaryText = Color(0xFFF0EDE8);
  static const Color darkSecondaryText = Color(0xFF8E9BAA);
  static const Color darkBorderColor = Color(0xFF2A3A4A);
  static const Color darkSoftGoldBg = Color(0xFF2A2215);
  static const Color darkShadowColor = Color(0x3F000000);

  static ThemeData get lightTheme {
    return _buildLightTheme(isArabic: false);
  }

  static ThemeData get darkTheme {
    return _buildDarkTheme(isArabic: false);
  }

  /// Returns a locale-aware light theme — Arabic uses Tajawal.
  static ThemeData lightThemeForLocale(Locale locale) {
    return _buildLightTheme(isArabic: locale.languageCode == 'ar');
  }

  /// Returns a locale-aware dark theme — Arabic uses Tajawal.
  static ThemeData darkThemeForLocale(Locale locale) {
    return _buildDarkTheme(isArabic: locale.languageCode == 'ar');
  }

  // ─── Internal builders ────────────────────────────────────────────────────

  static TextStyle _body(
    double size,
    FontWeight weight,
    Color color, {
    bool isArabic = false,
    double? letterSpacing,
  }) {
    if (isArabic) {
      return GoogleFonts.tajawal(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );
    }
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static ThemeData _buildLightTheme({required bool isArabic}) {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: mainBackground,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: brandNavy,
        onPrimary: cardWhite,
        primaryContainer: softGoldBg,
        onPrimaryContainer: brandNavy,
        secondary: luxuryAccent,
        onSecondary: cardWhite,
        secondaryContainer: softGoldBg,
        onSecondaryContainer: brandNavy,
        tertiary: successGreen,
        onTertiary: cardWhite,
        tertiaryContainer: Color(0xFFE8F2EC),
        onTertiaryContainer: successGreen,
        error: errorRed,
        onError: cardWhite,
        surface: cardWhite,
        onSurface: primaryText,
        onSurfaceVariant: secondaryText,
        outline: borderColor,
        outlineVariant: Color(0xFFF0EDE8),
        shadow: shadowColor,
        scrim: Color(0x80172331),
        inverseSurface: brandNavy,
        onInverseSurface: cardWhite,
        inversePrimary: luxuryAccent,
      ),
      cardColor: cardWhite,
      dividerColor: borderColor,
      appBarTheme: AppBarThemeData(
        backgroundColor: mainBackground,
        foregroundColor: primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: _body(
          18,
          FontWeight.w600,
          primaryText,
          isArabic: isArabic,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardWhite,
        selectedItemColor: brandNavy,
        unselectedItemColor: secondaryText,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandNavy,
          foregroundColor: cardWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: _body(
            16,
            FontWeight.w600,
            cardWhite,
            isArabic: isArabic,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandNavy,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          side: const BorderSide(color: borderColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandNavy,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        fillColor: cardWhite,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandNavy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
        labelStyle: _body(
          14,
          FontWeight.w400,
          secondaryText,
          isArabic: isArabic,
        ),
        hintStyle: _body(
          15,
          FontWeight.w400,
          const Color(0xFFB0B8C1),
          isArabic: isArabic,
        ),
      ),
      textTheme: _buildLightTextTheme(isArabic: isArabic),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandNavy,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brandNavy,
        contentTextStyle: _body(
          14,
          FontWeight.w400,
          cardWhite,
          isArabic: isArabic,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData _buildDarkTheme({required bool isArabic}) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: luxuryAccent,
        onPrimary: darkBackground,
        primaryContainer: darkSoftGoldBg,
        onPrimaryContainer: luxuryAccent,
        secondary: luxuryAccent,
        onSecondary: darkBackground,
        secondaryContainer: darkSoftGoldBg,
        onSecondaryContainer: luxuryAccent,
        tertiary: successGreen,
        onTertiary: darkCard,
        tertiaryContainer: Color(0xFF1A2E24),
        onTertiaryContainer: successGreen,
        error: errorRed,
        onError: darkCard,
        surface: darkCard,
        onSurface: darkPrimaryText,
        onSurfaceVariant: darkSecondaryText,
        outline: darkBorderColor,
        outlineVariant: Color(0xFF1E2D3D),
        shadow: darkShadowColor,
        scrim: Color(0x80000000),
        inverseSurface: darkPrimaryText,
        onInverseSurface: darkBackground,
        inversePrimary: brandNavy,
      ),
      cardColor: darkCard,
      dividerColor: darkBorderColor,
      appBarTheme: AppBarThemeData(
        backgroundColor: darkBackground,
        foregroundColor: darkPrimaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: _body(
          18,
          FontWeight.w600,
          darkPrimaryText,
          isArabic: isArabic,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorderColor, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkCard,
        selectedItemColor: luxuryAccent,
        unselectedItemColor: darkSecondaryText,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: luxuryAccent,
          foregroundColor: darkBackground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: _body(
            16,
            FontWeight.w600,
            darkBackground,
            isArabic: isArabic,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: luxuryAccent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          side: const BorderSide(color: darkBorderColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: luxuryAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        fillColor: darkCard,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorderColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: luxuryAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
        labelStyle: _body(
          14,
          FontWeight.w400,
          darkSecondaryText,
          isArabic: isArabic,
        ),
        hintStyle: _body(
          15,
          FontWeight.w400,
          const Color(0xFF5A6A7A),
          isArabic: isArabic,
        ),
      ),
      textTheme: _buildDarkTextTheme(isArabic: isArabic),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: luxuryAccent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCard,
        contentTextStyle: _body(
          14,
          FontWeight.w400,
          darkPrimaryText,
          isArabic: isArabic,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static TextTheme _buildLightTextTheme({bool isArabic = false}) {
    return TextTheme(
      displayLarge: _body(
        32,
        FontWeight.w700,
        primaryText,
        isArabic: isArabic,
        letterSpacing: -0.5,
      ),
      displayMedium: _body(
        28,
        FontWeight.w700,
        primaryText,
        isArabic: isArabic,
        letterSpacing: -0.5,
      ),
      displaySmall: _body(24, FontWeight.w600, primaryText, isArabic: isArabic),
      headlineLarge: _body(
        22,
        FontWeight.w700,
        primaryText,
        isArabic: isArabic,
      ),
      headlineMedium: _body(
        20,
        FontWeight.w600,
        primaryText,
        isArabic: isArabic,
      ),
      headlineSmall: _body(
        18,
        FontWeight.w600,
        primaryText,
        isArabic: isArabic,
      ),
      titleLarge: _body(17, FontWeight.w600, primaryText, isArabic: isArabic),
      titleMedium: _body(15, FontWeight.w600, primaryText, isArabic: isArabic),
      titleSmall: _body(13, FontWeight.w600, primaryText, isArabic: isArabic),
      bodyLarge: _body(16, FontWeight.w400, primaryText, isArabic: isArabic),
      bodyMedium: _body(14, FontWeight.w400, primaryText, isArabic: isArabic),
      bodySmall: _body(12, FontWeight.w400, secondaryText, isArabic: isArabic),
      labelLarge: _body(
        14,
        FontWeight.w600,
        primaryText,
        isArabic: isArabic,
        letterSpacing: 0.5,
      ),
      labelMedium: _body(
        12,
        FontWeight.w600,
        secondaryText,
        isArabic: isArabic,
        letterSpacing: 0.5,
      ),
      labelSmall: _body(
        11,
        FontWeight.w500,
        secondaryText,
        isArabic: isArabic,
        letterSpacing: 0.5,
      ),
    );
  }

  static TextTheme _buildDarkTextTheme({bool isArabic = false}) {
    return TextTheme(
      displayLarge: _body(
        32,
        FontWeight.w700,
        darkPrimaryText,
        isArabic: isArabic,
        letterSpacing: -0.5,
      ),
      displayMedium: _body(
        28,
        FontWeight.w700,
        darkPrimaryText,
        isArabic: isArabic,
        letterSpacing: -0.5,
      ),
      displaySmall: _body(
        24,
        FontWeight.w600,
        darkPrimaryText,
        isArabic: isArabic,
      ),
      headlineLarge: _body(
        22,
        FontWeight.w700,
        darkPrimaryText,
        isArabic: isArabic,
      ),
      headlineMedium: _body(
        20,
        FontWeight.w600,
        darkPrimaryText,
        isArabic: isArabic,
      ),
      headlineSmall: _body(
        18,
        FontWeight.w600,
        darkPrimaryText,
        isArabic: isArabic,
      ),
      titleLarge: _body(
        17,
        FontWeight.w600,
        darkPrimaryText,
        isArabic: isArabic,
      ),
      titleMedium: _body(
        15,
        FontWeight.w600,
        darkPrimaryText,
        isArabic: isArabic,
      ),
      titleSmall: _body(
        13,
        FontWeight.w600,
        darkPrimaryText,
        isArabic: isArabic,
      ),
      bodyLarge: _body(
        16,
        FontWeight.w400,
        darkPrimaryText,
        isArabic: isArabic,
      ),
      bodyMedium: _body(
        14,
        FontWeight.w400,
        darkPrimaryText,
        isArabic: isArabic,
      ),
      bodySmall: _body(
        12,
        FontWeight.w400,
        darkSecondaryText,
        isArabic: isArabic,
      ),
      labelLarge: _body(
        14,
        FontWeight.w600,
        darkPrimaryText,
        isArabic: isArabic,
        letterSpacing: 0.5,
      ),
      labelMedium: _body(
        12,
        FontWeight.w600,
        darkSecondaryText,
        isArabic: isArabic,
        letterSpacing: 0.5,
      ),
      labelSmall: _body(
        11,
        FontWeight.w500,
        darkSecondaryText,
        isArabic: isArabic,
        letterSpacing: 0.5,
      ),
    );
  }
}
