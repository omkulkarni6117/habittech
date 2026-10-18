import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/analytics_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/matrix_screen.dart';
import '../screens/reflections_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/sleep_screen.dart';
import '../screens/today_screen.dart';
import '../screens/workout_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'sections.dart';

/// Sections reachable from the compact bottom bar's "More" sheet.
const List<AppSection> _moreSections = [
  AppSection.sleep,
  AppSection.analytics,
  AppSection.reflections,
  AppSection.settings,
];

const List<AppSection> _bottomSections = [
  AppSection.dashboard,
  AppSection.today,
  AppSection.matrix,
  AppSection.workout,
];

Widget _screenFor(AppSection section) => switch (section) {
      AppSection.dashboard => const DashboardScreen(),
      AppSection.today => const TodayScreen(),
      AppSection.matrix => const MatrixScreen(),
      AppSection.workout => const WorkoutScreen(),
      AppSection.sleep => const SleepScreen(),
      AppSection.analytics => const AnalyticsScreen(),
      AppSection.reflections => const ReflectionsScreen(),
      AppSection.settings => const SettingsScreen(),
    };

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  Future<void> _openMore(BuildContext context) async {
    final state = context.read<AppState>();
    final chosen = await showModalBottomSheet<AppSection>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in _moreSections)
              ListTile(
                leading: Icon(
                  state.section == s ? s.selectedIcon : s.icon,
                  color: ctx.hc.primaryStrong,
                ),
                title: Text(s.title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                selected: state.section == s,
                onTap: () => Navigator.of(ctx).pop(s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) state.goTo(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final section = state.section;
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    // The side rail needs room for 8 destinations; short landscape windows
    // use the compact layout instead.
    final wide = width >= 840 && size.height >= 700;
    final c = context.hc;

    final banners = Column(
      children: [
        if (state.loadWarning != null)
          _Banner(
            icon: Icons.warning_amber_rounded,
            message: state.loadWarning!,
            color: c.warning,
            onClose: state.dismissLoadWarning,
          ),
        if (state.saveError != null)
          _Banner(
            icon: Icons.error_outline,
            message: state.saveError!,
            color: c.error,
          ),
      ],
    );

    final body = Column(
      children: [
        banners,
        // Only the visible screen is built, so it always reads current state.
        Expanded(
          child: AnimatedSwitcher(
            duration: motionDuration(context, 180),
            child: KeyedSubtree(
              key: ValueKey(section),
              child: _screenFor(section),
            ),
          ),
        ),
      ],
    );

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                extended: width >= 1100,
                selectedIndex: section.index,
                onDestinationSelected: (i) => state.goTo(AppSection.values[i]),
                labelType: width >= 1100
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: HabitTechLogo(showText: width >= 1100),
                ),
                destinations: [
                  for (final s in AppSection.values)
                    NavigationRailDestination(
                      icon: Icon(s.icon),
                      selectedIcon: Icon(s.selectedIcon, color: c.primaryStrong),
                      label: Text(s.shortLabel),
                    ),
                ],
              ),
              VerticalDivider(width: 1, color: c.border),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    final inMore = _moreSections.contains(section);
    final bottomIndex = inMore ? _bottomSections.length : _bottomSections.indexOf(section);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: const HabitTechLogo(size: 30),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                section.title,
                style: TextStyle(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: c.border),
        ),
      ),
      body: SafeArea(top: false, bottom: false, child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          if (i == _bottomSections.length) {
            _openMore(context);
          } else {
            state.goTo(_bottomSections[i]);
          }
        },
        destinations: [
          for (final s in _bottomSections)
            NavigationDestination(
              icon: Icon(s.icon),
              selectedIcon: Icon(s.selectedIcon, color: c.primaryStrong),
              label: s.shortLabel,
            ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz, color: c.primaryStrong),
            label: inMore ? section.shortLabel : 'More',
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.message,
    required this.color,
    this.onClose,
  });

  final IconData icon;
  final String message;
  final Color color;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        border: Border(bottom: BorderSide(color: color)),
      ),
      child: Row(
        children: [
          Icon(icon, color: c.text),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: c.text, fontSize: 13.5)),
          ),
          if (onClose != null)
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}
