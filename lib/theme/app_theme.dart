import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

ThemeData buildTheme(Tokens tk) {
  final base = tk.isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

  return base.copyWith(
    extensions: [tk],
    scaffoldBackgroundColor: tk.canvas,
    canvasColor: tk.canvas,
    colorScheme: base.colorScheme.copyWith(
      brightness: tk.isDark ? Brightness.dark : Brightness.light,
      surface: tk.canvas,
      onSurface: tk.ink,
      primary: tk.accent,
      onPrimary: tk.onAccent,
      secondary: tk.cool,
      error: tk.alert,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: tk.ink,
      displayColor: tk.ink,
    ),
    dividerTheme: DividerThemeData(color: tk.hairline, thickness: 1, space: 1),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: tk.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: tk.ink,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: tk.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: Radii.brLg),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tk.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: Radii.brMd,
        borderSide: BorderSide(color: tk.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: Radii.brMd,
        borderSide: BorderSide(color: tk.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: Radii.brMd,
        borderSide: BorderSide(color: tk.accent, width: 1.4),
      ),
      hintStyle: GoogleFonts.inter(color: tk.inkDim, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: tk.isDark
          ? const Color(0xCC000000)
          : const Color(0x66100C06),
    ),
  );
}

ThemeData get lightTheme => buildTheme(Tokens.light);
ThemeData get darkTheme => buildTheme(Tokens.dark);
