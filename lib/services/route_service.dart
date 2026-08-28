import 'dart:convert';

import 'package:http/http.dart' as http;

class RouteResult {
  final double distanceKm;

  const RouteResult({
    required this.distanceKm,
  });
}

class RouteService {
  static Future<RouteResult?> getRoute({
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$pickupLng,$pickupLat;'
      '$destinationLng,$destinationLat'
      '?overview=false',
    );

    try {
      final response = await http.get(
        url,
        headers: const {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body);

      if (json['code'] != 'Ok') {
        return null;
      }

      final routes = json['routes'];

      if (routes is! List || routes.isEmpty) {
        return null;
      }

      final distanceMeters =
          (routes.first['distance'] as num).toDouble();

      return RouteResult(
        distanceKm: distanceMeters / 1000.0,
      );
    } catch (_) {
      return null;
    }
  }
}
