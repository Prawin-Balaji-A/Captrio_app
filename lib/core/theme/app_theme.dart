import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import '../constants/app_constants.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppConstants.fontFamily,
    scaffoldBackgroundColor: AppColors.gradientStart,
    colorScheme: const ColorScheme.dark(
      primary:        AppColors.primary,
      secondary:      AppColors.secondary,
      surface:        AppColors.surface1,
      error:          AppColors.danger,
      onPrimary:      AppColors.textDark,
      onSecondary:    AppColors.textPrimary,
      onSurface:      AppColors.textPrimary,
      onError:        AppColors.textPrimary,
    ),

    // ── AppBar ───────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor:    Colors.transparent,
      elevation:          0,
      centerTitle:        true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor:           Colors.transparent,
        statusBarIconBrightness:  Brightness.light,
      ),
      titleTextStyle: TextStyle(
        fontFamily:  AppConstants.fontFamily,
        fontSize:    20,
        fontWeight:  FontWeight.w700,
        color:       AppColors.textPrimary,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),

    // ── Text ────────────────────────────────────────────────
    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5),
      displayMedium: TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      displaySmall:  TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      headlineLarge: TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      headlineMedium:TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      headlineSmall: TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyLarge:     TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.6),
      bodyMedium:    TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.5),
      bodySmall:     TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted, height: 1.4),
      labelLarge:    TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: 0.5),
      labelMedium:   TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary, letterSpacing: 0.3),
      labelSmall:    TextStyle(fontFamily: AppConstants.fontFamily, fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted,      letterSpacing: 0.5),
    ),

    // ── ElevatedButton ──────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:  AppColors.primary,
        foregroundColor:  AppColors.textDark,
        minimumSize:      const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
        textStyle: const TextStyle(
          fontFamily:  AppConstants.fontFamily,
          fontSize:    16,
          fontWeight:  FontWeight.w700,
          letterSpacing: 0.5,
        ),
        elevation: 0,
      ),
    ),

    // ── OutlinedButton ──────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize:     const Size(double.infinity, 54),
        side:            const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
        textStyle: const TextStyle(
          fontFamily:  AppConstants.fontFamily,
          fontSize:    16,
          fontWeight:  FontWeight.w600,
        ),
      ),
    ),

    // ── TextButton ──────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontFamily:  AppConstants.fontFamily,
          fontSize:    14,
          fontWeight:  FontWeight.w600,
        ),
      ),
    ),

    // ── InputDecoration ─────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled:      true,
      fillColor:   AppColors.inputFill,
      hintStyle:   const TextStyle(color: AppColors.inputHint, fontSize: 14),
      labelStyle:  const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        borderSide: const BorderSide(color: AppColors.inputBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        borderSide: const BorderSide(color: AppColors.inputBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        borderSide: const BorderSide(color: AppColors.inputFocusBorder, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        borderSide: const BorderSide(color: AppColors.danger, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
    ),

    // ── BottomNavigationBar ─────────────────────────────────
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:      AppColors.navBackground,
      selectedItemColor:    AppColors.navActive,
      unselectedItemColor:  AppColors.navInactive,
      showSelectedLabels:   true,
      showUnselectedLabels: true,
      type:                 BottomNavigationBarType.fixed,
      selectedLabelStyle:   TextStyle(fontSize: 10, fontWeight: FontWeight.w600, fontFamily: AppConstants.fontFamily),
      unselectedLabelStyle: TextStyle(fontSize: 10, fontFamily: AppConstants.fontFamily),
      elevation:            0,
    ),

    // ── SnackBar ────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor:  AppColors.surface2,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontFamily: AppConstants.fontFamily),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
      behavior: SnackBarBehavior.floating,
    ),

    // ── Divider ─────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color:     AppColors.divider,
      thickness: 1,
      space:     1,
    ),

    // ── Dialog ──────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.gradientMid,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusXl)),
      titleTextStyle: const TextStyle(
        fontFamily:  AppConstants.fontFamily,
        fontSize:    18,
        fontWeight:  FontWeight.w700,
        color:       AppColors.textPrimary,
      ),
    ),

    // ── DropdownMenu ────────────────────────────────────────
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: const TextStyle(color: AppColors.textPrimary, fontFamily: AppConstants.fontFamily),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.gradientMid),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
        ),
      ),
    ),

    // ── Icon ────────────────────────────────────────────────
    iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
  );
}