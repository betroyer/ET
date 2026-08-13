import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'screens/home/dashboard_screen.dart';
import 'screens/settings/pin_lock_screen.dart';
import 'utils/constants.dart';

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    final lightScheme = ColorScheme.fromSeed(
      seedColor: AppConstants.brandTeal,
      brightness: Brightness.light,
      primary: AppConstants.brandTeal,
      secondary: AppConstants.brandMint,
      error: AppConstants.brandCoral,
      surface: AppConstants.brandSurface,
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: AppConstants.brandTeal,
      brightness: Brightness.dark,
      primary: AppConstants.brandMint,
      secondary: AppConstants.brandTeal,
      error: AppConstants.brandCoral,
    );

    // Prefer bundled Material text if Google Fonts fetch fails (offline / blocked).
    TextTheme textTheme;
    TextTheme darkTextTheme;
    try {
      textTheme = GoogleFonts.plusJakartaSansTextTheme();
      darkTextTheme = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme);
    } catch (_) {
      textTheme = ThemeData.light().textTheme;
      darkTextTheme = ThemeData.dark().textTheme;
    }

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        textTheme: textTheme.apply(
          bodyColor: AppConstants.brandInk,
          displayColor: AppConstants.brandInk,
        ),
        scaffoldBackgroundColor: AppConstants.brandSurface,
        appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 0),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: lightScheme.primary,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        textTheme: darkTextTheme,
        appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 0),
      ),
      home: settings.pinEnabled && !settings.unlocked
          ? const PinLockScreen(mode: PinMode.unlock)
          : const DashboardScreen(),
    );
  }
}
