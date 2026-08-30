import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class OrderAssignmentService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<bool> assignNearestDriver(String orderId) async {
    try {
      final orderRef = _db.collection('orders').doc(orderId);
      final orderSnap = await orderRef.get();

      if (!orderSnap.exists) return false;

      final order = orderSnap.data();
      if (order == null) return false;

      final currentDriverId = order['driverId'];
      final status = order['status']?.toString();

      if (currentDriverId != null && currentDriverId.toString().isNotEmpty) {
        return true;
      }

      if (status != 'menunggu') return false;

      final pickupLat = _toDouble(order['pickupLat']);
      final pickupLng = _toDouble(order['pickupLng']);

      if (pickupLat == null || pickupLng == null) {
        return false;
      }

      final rejectedBy =
          (order['rejectedBy'] as List?)?.map((e) => e.toString()).toSet() ??
          <String>{};

      final driversSnap = await _db
          .collection('drivers')
          .where('online', isEqualTo: true)
          .where('verificationStatus', isEqualTo: 'disetujui')
          .get();

      String? nearestUid;
      double nearestDistance = double.infinity;
      String nearestName = 'Driver TianRide';
      String nearestVehicle = 'Motor • TianRide';
      String nearestDriverId = '';

      for (final driverDoc in driversSnap.docs) {
        final driver = driverDoc.data();
        final uid = driverDoc.id;

        if (rejectedBy.contains(uid)) continue;

        final lat = _toDouble(driver['lat']);
        final lng = _toDouble(driver['lng']);

        if (lat == null || lng == null) continue;

        final distance = _distanceKm(pickupLat, pickupLng, lat, lng);

        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestUid = uid;
          nearestDriverId = driver['driverId']?.toString() ?? uid;
          nearestName =
              driver['driverName']?.toString() ??
              driver['name']?.toString() ??
              'Driver TianRide';
          nearestVehicle = driver['vehicle']?.toString() ?? 'Motor • TianRide';
        }
      }

      if (nearestUid == null) {
        return false;
      }

      await _db.runTransaction((transaction) async {
        final fresh = await transaction.get(orderRef);

        if (!fresh.exists) return;

        final freshData = fresh.data();
        if (freshData == null) return;

        final existingDriver = freshData['driverId'];

        if (existingDriver != null && existingDriver.toString().isNotEmpty) {
          return;
        }

        if (freshData['status'] != 'menunggu') {
          return;
        }

        transaction.update(orderRef, {
          'driverId': nearestUid,
          'driverIdNumber': nearestDriverId,
          'driverName': nearestName,
          'vehicle': nearestVehicle,
          'assignedDistanceKm': nearestDistance,
          'assignedAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      // Auto-assign gagal; caller akan menangani hasil false.
      return false;
    }
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static double _distanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  static double _rad(double degrees) {
    return degrees * math.pi / 180;
  }
}
