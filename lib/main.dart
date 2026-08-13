import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/budget_provider.dart';
import 'providers/category_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chrome/web cannot use sqflite, ML Kit, or the Android camera stack.
  // Show guidance instead of a blank white page.
  if (kIsWeb) {
    runApp(const _UnsupportedPlatformApp());
    return;
  }

  try {
    final db = DatabaseService.instance;
    await db.database;

    final notifications = NotificationService();
    try {
      await notifications.init();
    } catch (e) {
      debugPrint('Notifications init skipped: $e');
    }

    final settings = SettingsProvider(notifications: notifications);
    final transactions = TransactionProvider(db, notifications: notifications);
    final categories = CategoryProvider(db);
    final budgets = BudgetProvider(db);

    await Future.wait([
      settings.load(),
      transactions.load(),
      categories.load(),
      budgets.load(),
    ]);

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: transactions),
          ChangeNotifierProvider.value(value: categories),
          ChangeNotifierProvider.value(value: budgets),
        ],
        child: const ExpenseApp(),
      ),
    );
  } catch (e, st) {
    debugPrint('App failed to start: $e\n$st');
    runApp(_StartupErrorApp(error: e.toString()));
  }
}

class _UnsupportedPlatformApp extends StatelessWidget {
  const _UnsupportedPlatformApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppConstants.brandSurface,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_android, size: 64, color: AppConstants.brandTeal),
                  SizedBox(height: 20),
                  Text(
                    'ExTra is an Android app',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Chrome cannot run the local database, camera, or receipt OCR.\n\n'
                    'In Android Studio, choose an Android emulator or phone, then press Run.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not start the app.\n\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
