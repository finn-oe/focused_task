import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';

/// [MaterialApp] with the app's localizations, for widget tests.
Widget localizedApp({required Widget home, Locale locale = const Locale('en')}) {
  return MaterialApp(localizationsDelegates: appLocalizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, locale: locale, home: home);
}

/// [MaterialApp.router] with the app's localizations, for widget tests.
Widget localizedRouterApp({required RouterConfig<Object> routerConfig, Locale locale = const Locale('en')}) {
  return MaterialApp.router(localizationsDelegates: appLocalizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, locale: locale, routerConfig: routerConfig);
}
