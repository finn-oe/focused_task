import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';

/// Week and month views follow in #22.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navCalendar)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(l10n.calendarComingSoon, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
