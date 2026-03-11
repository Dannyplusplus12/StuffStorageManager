import 'package:flutter/material.dart';

const kPrimary = Color(0xFFEE4D2D);
const kPrimaryDark = Color(0xFFD73211);
const kPrimaryLight = Color(0xFFFFF0ED);
const kBg = Color(0xFFF0F2F5);
const kSidebar = Color(0xFF1E293B);
const kSidebarActive = Color(0xFF334155);
const kLowStock = Color(0xFFFFF9C4);
const kNoStock = Color(0xFFFFEBEE);
const kBorder = Color(0xFFE2E8F0);
const kSuccess = Color(0xFF16A34A);
const kWarning = Color(0xFFF59E0B);
const kDanger = Color(0xFFDC2626);
const kTextPrimary = Color(0xFF0F172A);
const kTextSecondary = Color(0xFF64748B);

ThemeData buildTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      primary: kPrimary,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: kBg,
    fontFamily: 'Segoe UI',
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: kBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: kBorder),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
    dividerTheme: const DividerThemeData(color: kBorder, space: 1),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
      dataRowMinHeight: 44,
      dataRowMaxHeight: 52,
      horizontalMargin: 16,
      columnSpacing: 16,
    ),
  );
}
