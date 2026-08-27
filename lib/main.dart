import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'admin_page.dart';
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

  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  try {
    await NotificationService.initialize();
  } catch (_) {}

  runApp(const TianRideApp());
}

class TianRideApp extends StatelessWidget {
  const TianRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TianRide',
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
        return const AdminPage();

      case 'customer':
      default:
        return const PassengerPage();
    }
  }
}
