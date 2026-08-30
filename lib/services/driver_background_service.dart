import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String driverUidKey = 'tianride_driver_uid';

Future<void> initializeDriverBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: driverBackgroundOnStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      foregroundServiceTypes: [
        AndroidForegroundType.location,
      ],
      initialNotificationTitle: 'TianRide Driver',
      initialNotificationContent: 'Driver sedang online',
      foregroundServiceNotificationId: 1001,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: driverBackgroundOnStart,
      onBackground: driverBackgroundIosBackground,
    ),
  );
}

Future<void> startDriverBackgroundService(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(driverUidKey, uid);

  final service = FlutterBackgroundService();

  if (!await service.isRunning()) {
    await service.startService();
  }
}

Future<void> stopDriverBackgroundService() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(driverUidKey);

  FlutterBackgroundService().invoke('stopService');
}

@pragma('vm:entry-point')
void driverBackgroundOnStart(ServiceInstance service) {
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 15), (timer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString(driverUidKey);

      if (uid == null || uid.isEmpty) {
        return;
      }

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .set({
        'lat': position.latitude,
        'lng': position.longitude,
        'online': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: 'TianRide Driver',
            content: 'Driver sedang online',
          );
        }
      }
    } catch (e) {
      // Jangan hentikan service hanya karena GPS/network bermasalah.
    }
  });
}

@pragma('vm:entry-point')
Future<bool> driverBackgroundIosBackground(ServiceInstance service) async {
  return true;
}
