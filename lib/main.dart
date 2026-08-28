import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'admin_login_page.dart';
import 'driver_login_page.dart';
import 'passenger_page.dart';
import 'services/notification_service.dart';

const String appFlavor = String.fromEnvironment(
  'APP_FLAVOR',
  defaultValue: 'customer',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();


  try {
    await NotificationService.initialize();
  } catch (_) {}

  runApp(const DarmaRideApp());
}

class DarmaRideApp extends StatelessWidget {
  const DarmaRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Darma Ride',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: _homePage(),
    );
  }

  Widget _homePage() {
    switch (appFlavor) {
      case 'driver':
        return const DriverLoginPage();

      case 'admin':
        return const AdminLoginPage();

      case 'customer':
      default:
        return const PassengerPage();
    }
  }
}
