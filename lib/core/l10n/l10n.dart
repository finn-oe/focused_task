import 'dart:ui' show PlatformDispatcher;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/utils/date_utils.dart';
import 'package:focused_task/l10n/generated/app_localizations.dart';

export 'package:focused_task/l10n/generated/app_localizations.dart';

/// Delegates for [MaterialApp.localizationsDelegates].
///
/// Don't use the generated `AppLocalizations.localizationsDelegates`: it references the deprecated SDK Material
/// localizations, which the `material_ui` widgets don't read.
const List<LocalizationsDelegate<Object?>> appLocalizationsDelegates = [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates];

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The locale the app shows when no language is chosen in the settings (outside of the widget tree, e.g. for notifications).
Locale systemAppLocale() => basicLocaleListResolution(PlatformDispatcher.instance.locales, AppLocalizations.supportedLocales);

/// First day of the week for the current locale, as a [DateTime.weekday] value (e.g. [DateTime.sunday] for `en_US`).
int firstDayOfWeek(BuildContext context) {
  final index = MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0 = Sunday
  return index == 0 ? DateTime.sunday : index;
}

/// "Today", "Tomorrow", "Yesterday" or the localized date, e.g. "Tue, Nov 17, 2026".
String relativeDayLabel(BuildContext context, DateTime day, {required DateTime today}) {
  final l10n = context.l10n;
  return switch (today.calendarDaysUntil(day)) {
    0 => l10n.commonToday,
    1 => l10n.commonTomorrow,
    -1 => l10n.commonYesterday,
    _ => DateFormat.yMMMEd(Localizations.localeOf(context).toLanguageTag()).format(day),
  };
}
