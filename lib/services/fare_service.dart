class FareService {
  static const double baseDistanceKm = 4.0;
  static const double baseFare = 8900.0;
  static const double extraFarePerKm = 2300.0;

  /// Tarif:
  /// <= 4 km  = Rp8.900
  /// > 4 km   = Rp8.900 + Rp2.300 setiap km tambahan
  ///
  /// Jarak tambahan dibulatkan ke atas agar driver tidak dirugikan.
  static double calculateFare(double distanceKm) {
    if (distanceKm <= 0) {
      return baseFare;
    }

    if (distanceKm <= baseDistanceKm) {
      return baseFare;
    }

    final extraKm = (distanceKm - baseDistanceKm).ceil();

    return baseFare + (extraKm * extraFarePerKm);
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
