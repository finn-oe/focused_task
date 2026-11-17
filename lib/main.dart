import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/l10n/l10n.dart';
import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/ui/themes/app_themes.dart';
import 'package:focused_task/core/services/notification_service.dart';
import 'package:focused_task/core/services/target_alarm.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = createNotificationService();
  await notifications.init();
  final targetAlarm = createTargetAlarm(notifications: notifications);
  await targetAlarm.init();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        targetAlarmProvider.overrideWithValue(targetAlarm),
        sharedPreferencesProvider.overrideWithValue(preferences),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const FocusedTaskApp(),
    ),
  );
}

class FocusedTaskApp extends ConsumerWidget {
  const FocusedTaskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Runs the launch work once; the UI does not wait for it.
    ref.watch(appStartupProvider);
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(settingsNotifierProvider.select((settings) => settings.themeMode));
    final locale = ref.watch(settingsNotifierProvider.select((settings) => settings.locale));

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppThemes.light,
      darkTheme: AppThemes.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      routerConfig: router,
    );
  }
}
