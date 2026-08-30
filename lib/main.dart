import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_login_page.dart';
import 'driver_login_page.dart';
import 'driver_page.dart';
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
        return const DriverStartupPage();

      case 'admin':
        return const AdminLoginPage();

      case 'customer':
      default:
        return const PassengerPage();
    }
  }
}


class DriverStartupPage extends StatelessWidget {
  const DriverStartupPage({super.key});

  Future<Widget> _checkSession() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    // Tidak ada sesi login.
    if (user == null || user.isAnonymous) {
      if (user?.isAnonymous == true) {
        await auth.signOut();
      }
      return const DriverLoginPage();
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        await auth.signOut();
        return const DriverLoginPage();
      }

      final data = doc.data();
      final status = data?['verificationStatus']?.toString() ?? 'menunggu';

      if (status != 'disetujui') {
        await auth.signOut();
        return const DriverLoginPage();
      }

      // Sesi valid dan driver sudah disetujui.
      return const DriverPage();
    } catch (_) {
      // Jika pengecekan gagal, jangan paksa masuk.
      return const DriverLoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _checkSession(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return snapshot.data ?? const DriverLoginPage();
      },
    );
  }
}


@pragma("vm:entry-point")
void overlayMain() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TianRideDriverBubble(),
    ),
  );
}

class TianRideDriverBubble extends StatelessWidget {
  const TianRideDriverBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                spreadRadius: 2,
                color: Colors.black38,
              ),
            ],
          ),
          child: const Icon(
            Icons.two_wheeler,
            color: Colors.white,
            size: 38,
          ),
        ),
      ),
    );
  }
}
