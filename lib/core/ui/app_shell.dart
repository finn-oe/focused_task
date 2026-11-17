import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:focused_task/core/l10n/l10n.dart';

/// Which navigation the shell shows for a window width.
enum ShellNavigation {
  /// Phones: bottom [NavigationBar].
  bar,

  /// Tablets and small windows: [NavigationRail].
  rail,

  /// Wide windows: extended [NavigationRail] with labels (sidebar).
  sidebar;

  static ShellNavigation forWidth(double width) {
    if (width < 600) return ShellNavigation.bar;
    if (width < 1200) return ShellNavigation.rail;
    return ShellNavigation.sidebar;
  }
}

/// Main layout around Plan, Calendar, Statistics and Settings with adaptive navigation.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(int index) {
    // Tapping the current tab again returns to its first page.
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destinations = [
      (icon: Icons.checklist_outlined, selectedIcon: Icons.checklist, label: l10n.navPlan),
      (icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month, label: l10n.navCalendar),
      (icon: Icons.insights_outlined, selectedIcon: Icons.insights, label: l10n.navStatistics),
      (icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: l10n.navSettings),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final navigation = ShellNavigation.forWidth(constraints.maxWidth);
        if (navigation == ShellNavigation.bar) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _select,
              destinations: [
                for (final destination in destinations) NavigationDestination(icon: Icon(destination.icon), selectedIcon: Icon(destination.selectedIcon), label: destination.label),
              ],
            ),
          );
        }

        final extended = navigation == ShellNavigation.sidebar;
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                right: false,
                child: NavigationRail(
                  extended: extended,
                  labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _select,
                  destinations: [
                    for (final destination in destinations)
                      NavigationRailDestination(icon: Icon(destination.icon), selectedIcon: Icon(destination.selectedIcon), label: Text(destination.label)),
                  ],
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: navigationShell),
            ],
          ),
        );
      },
    );
  }
}
