import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kIvory = Color(0xFFF8F6F0);
const kInk = Color(0xFF432B25);
const kRose = Color(0xFFD982A0);
const kBlue = Color(0xFF5079A8);
const kCream = Color(0xFFF0ECE3);
const kMute = Color(0xFF8A8078);
const kMuteText = Color(0xFF6B625A); // darker, for small-text contrast
const kLine = Color(0x29432B25);
const kError = Color(0xFF9A2F4F);

TextStyle serif(double size,
        {FontWeight w = FontWeight.w400, Color c = kInk, FontStyle? s}) =>
    GoogleFonts.newsreader(
        fontSize: size, fontWeight: w, color: c, fontStyle: s, height: 1.2);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kIvory,
    colorScheme: const ColorScheme.light(
        primary: kInk,
        onPrimary: kIvory,
        secondary: kBlue,
        onSecondary: kIvory,
        surface: kIvory,
        onSurface: kInk,
        error: kError),
  );
  final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: const BorderSide(color: kLine));
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(2));
  return base.copyWith(
    textTheme: GoogleFonts.dmSansTextTheme(base.textTheme)
        .apply(bodyColor: kInk, displayColor: kInk),
    dividerColor: kLine,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCream,
      border: border,
      enabledBorder: border,
      focusedBorder:
          border.copyWith(borderSide: const BorderSide(color: kBlue, width: 1.5)),
      errorBorder: border.copyWith(borderSide: const BorderSide(color: kError)),
      focusedErrorBorder:
          border.copyWith(borderSide: const BorderSide(color: kError, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      labelStyle: const TextStyle(color: kMuteText),
      errorStyle: const TextStyle(color: kError),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: kInk,
            foregroundColor: kIvory,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shape: shape,
            elevation: 0)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: kInk,
            minimumSize: const Size(48, 48),
            side: const BorderSide(color: kInk),
            shape: shape)),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: kInk, minimumSize: const Size(48, 48))),
    snackBarTheme: SnackBarThemeData(
        backgroundColor: kInk,
        contentTextStyle: const TextStyle(color: kIvory),
        behavior: SnackBarBehavior.floating,
        shape: shape),
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: kIvory,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)))),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: kIvory,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: const Color(0x40D982A0),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500, color: kInk)),
        iconTheme: WidgetStateProperty.all(
            const IconThemeData(color: kInk, size: 24))),
    dialogTheme: DialogTheme(
        backgroundColor: kIvory,
        surfaceTintColor: Colors.transparent,
        shape: shape),
  );
}
