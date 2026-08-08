import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focused_task/core/providers/app_providers.dart';
import 'package:focused_task/core/routing/app_router.dart';
import 'package:focused_task/core/ui/themes/app_themes.dart';
import 'package:focused_task/core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await NotificationService.requestPermissions();
  runApp(const ProviderScope(child: FocusedTaskApp()));
}

class FocusedTaskApp extends ConsumerStatefulWidget {
  const FocusedTaskApp({super.key});

  @override
  ConsumerState<FocusedTaskApp> createState() => _FocusedTaskAppState();
}

class _FocusedTaskAppState extends ConsumerState<FocusedTaskApp> {
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_bootstrapped) {
        return;
      }

      _bootstrapped = true;
      final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
      await settingsNotifier.initialize();
      await settingsNotifier.runLaunchCleanupIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(settingsNotifierProvider);

    return MaterialApp.router(
      title: 'Focused Task',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.light,
      darkTheme: AppThemes.dark,
      themeMode: settings.themeMode,
      routerConfig: router,
    );
  }
}
