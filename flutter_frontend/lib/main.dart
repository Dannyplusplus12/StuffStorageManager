import 'package:flutter/material.dart';
import 'config.dart';
import 'theme.dart';
import 'utils/app_mode_manager.dart';
import 'utils/device_detector.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/mobile_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await AppModeManager.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Start polling for pending orders
    NotificationService.startPolling(intervalSeconds: 10);
    NotificationService.onPendingOrdersUpdated = () {
      setState(() {});  // Rebuild to show notification badge
    };
  }

  @override
  void dispose() {
    NotificationService.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý kho & Công nợ',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Builder(
        builder: (context) {
          final shortestSide = MediaQuery.of(context).size.shortestSide;
          final useMobileLayout = DeviceDetector.isMobile || shortestSide < 700;
          return useMobileLayout ? const MobileHomeScreen() : const HomeScreen();
        },
      ),
    );
  }
}
