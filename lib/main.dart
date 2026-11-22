import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'services/foreground_service.dart';
import 'services/license_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseService.registerCustomLicenses();
  await SettingsService().init();
  await ForegroundServiceManager().init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF11111B),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const PhantekVegaApp());
}

class PhantekVegaApp extends StatelessWidget {
  const PhantekVegaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, child) {
        final settings = SettingsService().settings;
        final isSystemTheme = settings.themeMode == 'system';
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        final theme = isSystemTheme
            ? AppTheme.buildLightTheme(cardOpacity: settings.cardOpacity)
            : AppTheme.getTheme(
                settings.themeMode,
                cardOpacity: settings.cardOpacity,
              );
        final darkTheme = isSystemTheme
            ? AppTheme.buildOledTheme(cardOpacity: settings.cardOpacity)
            : null;
        final activeTheme = isSystemTheme
            ? AppTheme.getTheme(
                settings.themeMode,
                cardOpacity: settings.cardOpacity,
                platformBrightness: platformBrightness,
              )
            : theme;

        // Sync system nav bar color with active theme
        final navBarColor = activeTheme.scaffoldBackgroundColor;
        final isDark = activeTheme.brightness == Brightness.dark;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarColor: navBarColor,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
        );

        return MaterialApp(
          title: 'Phantek',
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: darkTheme,
          themeMode: isSystemTheme ? ThemeMode.system : ThemeMode.light,
          home: const HomeScreen(),
        );
      },
    );
  }
}
