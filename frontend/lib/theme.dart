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

ThemeData buildLightTheme() {
  return ThemeData(
    brightness: Brightness.light,
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
      ).copyWith(
        mouseCursor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled) ? SystemMouseCursors.basic : SystemMouseCursors.click),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: kBorder),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ).copyWith(
        mouseCursor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled) ? SystemMouseCursors.basic : SystemMouseCursors.click),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ).copyWith(
        mouseCursor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled) ? SystemMouseCursors.basic : SystemMouseCursors.click),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        mouseCursor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled) ? SystemMouseCursors.basic : SystemMouseCursors.click),
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

ThemeData buildDarkTheme() {
  const darkBg = Color(0xFF0B1220);
  const darkSurface = Color(0xFF111A2E);
  const darkSurface2 = Color(0xFF17233A);
  const darkBorder = Color(0xFF263449);
  const darkTextPrimary = Color(0xFFE2E8F0);
  const darkTextSecondary = Color(0xFF94A3B8);

  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF60A5FA),
      secondary: Color(0xFF38BDF8),
      surface: darkSurface,
      onPrimary: Color(0xFF0B1220),
      onSecondary: Color(0xFF0B1220),
      onSurface: darkTextPrimary,
      error: Color(0xFFEF4444),
      onError: Colors.white,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: darkBg,
    fontFamily: 'Segoe UI',
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: darkBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
      filled: true,
      fillColor: darkSurface2,
      hintStyle: const TextStyle(color: darkTextSecondary),
      labelStyle: const TextStyle(color: darkTextSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ).copyWith(
        mouseCursor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled) ? SystemMouseCursors.basic : SystemMouseCursors.click),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: darkTextPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: darkBorder),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ).copyWith(
        mouseCursor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled) ? SystemMouseCursors.basic : SystemMouseCursors.click),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: darkTextPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ).copyWith(
        mouseCursor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled) ? SystemMouseCursors.basic : SystemMouseCursors.click),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(darkTextPrimary),
        mouseCursor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled) ? SystemMouseCursors.basic : SystemMouseCursors.click),
      ),
    ),
    dividerTheme: const DividerThemeData(color: darkBorder, space: 1),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(darkSurface2),
      dataRowMinHeight: 44,
      dataRowMaxHeight: 52,
      horizontalMargin: 16,
      columnSpacing: 16,
      dataTextStyle: const TextStyle(color: darkTextPrimary),
      headingTextStyle: const TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w600),
    ),
  );
}

ThemeData buildTheme() => buildLightTheme();

Color appPanelBg(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111A2E) : Colors.white;
}

Color appPanelSoftBg(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF17233A) : const Color(0xFFF8FAFC);
}

Color appBorderColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF263449) : kBorder;
}

Color appTextPrimary(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE2E8F0) : kTextPrimary;
}

Color appTextSecondary(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : kTextSecondary;
}
