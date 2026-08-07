import 'package:flutter/material.dart';

ThemeData buildLightTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2266EE), brightness: Brightness.light),
    useMaterial3: true,
  );

  return base.copyWith(
    appBarTheme: base.appBarTheme.copyWith(centerTitle: false),
    cardTheme: base.cardTheme.copyWith(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(extendedPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
  );
}
