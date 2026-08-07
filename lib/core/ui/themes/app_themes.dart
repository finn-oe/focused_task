import 'package:flutter/material.dart';

import 'package:focused_task/core/ui/themes/dark_theme.dart';
import 'package:focused_task/core/ui/themes/light_theme.dart';

class AppThemes {
  const AppThemes._();

  static ThemeData get light => buildLightTheme();

  static ThemeData get dark => buildDarkTheme();
}
