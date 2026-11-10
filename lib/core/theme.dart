import 'package:flutter/material.dart';

/// Màu cam thương hiệu (kiểu Shopee). Muốn đổi màu app chỉ cần sửa các dòng này.
const kBrand = Color(0xFFEE4D2D);
const kBrandDark = Color(0xFFD73211);
const kBrandSoft = Color(0xFFFFE9E3); // nền nhạt cho chip/được chọn
const kPriceColor = kBrand;
const kPageBg = Color(0xFFF5F5F5);

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrand,
    brightness: Brightness.light,
  ).copyWith(
    primary: kBrand,
    onPrimary: Colors.white,
    primaryContainer: kBrandSoft,
    onPrimaryContainer: const Color(0xFF8A1F00),
    surface: Colors.white,
  );

  final radius = BorderRadius.circular(12);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: kPageBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF222222),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Color(0xFF222222),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: Color(0xFFEDEDED)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF757575),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFEEEEEE), space: 16),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF2F2F2),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: kBrand, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        // Không dùng Size.fromHeight: width vô hạn sẽ lỗi trong Row/AlertDialog.
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kBrand,
        side: const BorderSide(color: kBrand),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kBrand),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kBrand,
      foregroundColor: Colors.white,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: kBrandSoft,
      side: const BorderSide(color: Color(0xFFE0E0E0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: kBrandSoft,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? kBrand
              : const Color(0xFF757575),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? kBrand
              : const Color(0xFF757575),
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: kBrandSoft,
        selectedForegroundColor: kBrandDark,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? kBrand : null),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
  );
}