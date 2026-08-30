import 'package:cloud_firestore/cloud_firestore.dart';

class FareConfig {
  final double baseDistanceKm;
  final double baseFare;
  final double extraFarePerKm;

  const FareConfig({
    required this.baseDistanceKm,
    required this.baseFare,
    required this.extraFarePerKm,
  });

  factory FareConfig.fromMap(Map<String, dynamic> data) {
    return FareConfig(
      baseDistanceKm:
          (data['baseDistanceKm'] ?? 4).toDouble(),
      baseFare:
          (data['baseFare'] ?? 8900).toDouble(),
      extraFarePerKm:
          (data['extraFarePerKm'] ?? 2300).toDouble(),
    );
  }

  static const defaultConfig = FareConfig(
    baseDistanceKm: 4,
    baseFare: 8900,
    extraFarePerKm: 2300,
  );
}

class FareService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static Future<FareConfig> getConfig() async {
    try {
      final doc = await _firestore
          .collection('settings')
          .doc('fare')
          .get();

      if (!doc.exists || doc.data() == null) {
        return FareConfig.defaultConfig;
      }

      return FareConfig.fromMap(doc.data()!);
    } catch (_) {
      // Jika internet/Firebase bermasalah,
      // aplikasi tetap memakai tarif default.
      return FareConfig.defaultConfig;
    }
  }

  static double calculateFare(
    double distanceKm,
    FareConfig config,
  ) {
    if (distanceKm <= 0) {
      return config.baseFare;
    }

    if (distanceKm <= config.baseDistanceKm) {
      return config.baseFare;
    }

    final extraKm =
        (distanceKm - config.baseDistanceKm).ceil();

    return config.baseFare +
        (extraKm * config.extraFarePerKm);
  }

  static String formatRupiah(double amount) {
    final value = amount.round().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(value[i]);
    }

    return 'Rp $buffer';
  }
}
