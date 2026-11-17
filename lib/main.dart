import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/ui/themes/app_themes.dart';
import 'package:focused_task/core/services/target_alarm.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final targetAlarm = createTargetAlarm();
  await targetAlarm.init();
  final preferences = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [targetAlarmProvider.overrideWithValue(targetAlarm), sharedPreferencesProvider.overrideWithValue(preferences)], child: const FocusedTaskApp()));
}

class FocusedTaskApp extends ConsumerWidget {
  const FocusedTaskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Runs the launch work once; the UI does not wait for it.
    ref.watch(appStartupProvider);
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(settingsNotifierProvider.select((settings) => settings.themeMode));

    return MaterialApp.router(
      title: 'Focused Task',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.light,
      darkTheme: AppThemes.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
