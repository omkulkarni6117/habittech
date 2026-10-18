import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_shell.dart';
import 'data/storage_repository.dart';
import 'models/user_settings.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(repository: LocalStorageRepository(prefs));
  await state.init();
  runApp(HabitTechApp(state: state));
}

class HabitTechApp extends StatefulWidget {
  const HabitTechApp({super.key, required this.state});

  final AppState state;

  @override
  State<HabitTechApp> createState() => _HabitTechAppState();
}

class _HabitTechAppState extends State<HabitTechApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// When the app comes back (possibly the next morning) "today" must move.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) widget.state.refreshDate();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: widget.state,
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp(
          title: 'HabitTech',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: switch (state.settings.theme) {
            ThemeSetting.system => ThemeMode.system,
            ThemeSetting.light => ThemeMode.light,
            ThemeSetting.dark => ThemeMode.dark,
          },
          home: const AppShell(),
        ),
      ),
    );
  }
}
