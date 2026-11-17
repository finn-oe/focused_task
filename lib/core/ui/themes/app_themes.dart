import 'package:material_ui/material_ui.dart';

class AppThemes {
  const AppThemes._();

  static const Color _seedColor = Color(0xFF2266EE);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seedColor, brightness: brightness),
      useMaterial3: true,
    );

    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(centerTitle: false),
      cardTheme: base.cardTheme.copyWith(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(extendedPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
    );
  }
}
