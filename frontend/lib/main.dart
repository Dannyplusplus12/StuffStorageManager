import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config.dart';
import 'theme.dart';
import 'utils/app_mode_manager.dart';
import 'utils/device_detector.dart';
import 'services/notification_service.dart';
import 'services/mobile_notification_service.dart';
import 'services/delivery_proof_sync_service.dart';
import 'screens/home_screen.dart';
import 'screens/mobile_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await AppModeManager.init();
  await MobileNotificationService.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleThemeMode() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  void initState() {
    super.initState();
    // Start polling for pending orders
    NotificationService.startPolling(intervalSeconds: 10);
    NotificationService.onPendingOrdersUpdated = () {
      setState(() {});  // Rebuild to show notification badge
    };

    if (DeviceDetector.isDesktop) {
      DeliveryProofSyncService.startAutoSync(intervalSeconds: 10);
    }
  }

  @override
  void dispose() {
    NotificationService.stopPolling();
    DeliveryProofSyncService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fisd',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: _themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('vi', 'VN'),
      home: DeviceDetector.isMobile
          ? const MobileHomeScreen()
          : HomeScreen(
              isDarkMode: _themeMode == ThemeMode.dark,
              onToggleTheme: _toggleThemeMode,
            ),
    );
  }
}
