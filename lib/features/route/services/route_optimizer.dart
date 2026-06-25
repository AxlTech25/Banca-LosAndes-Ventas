import 'dart:math';

import '../../portfolio/models/daily_client.dart';

class RouteOptimizer {
  List<DailyClient> nearestNeighbor({
    required double startLat,
    required double startLng,
    required List<DailyClient> clients,
    bool includeVisited = false,
  }) {
    final pool = clients
        .where((client) => includeVisited || !client.isVisited)
        .where((client) => client.hasCoordinates)
        .toList();
    if (pool.isEmpty) {
      return [];
    }

    final ordered = <DailyClient>[];
    var currentLat = startLat;
    var currentLng = startLng;
    final remaining = List<DailyClient>.from(pool);

    while (remaining.isNotEmpty) {
      remaining.sort((a, b) {
        final distanceA = _distance(
          currentLat,
          currentLng,
          a.latitude!,
          a.longitude!,
        );
        final distanceB = _distance(
          currentLat,
          currentLng,
          b.latitude!,
          b.longitude!,
        );
        return distanceA.compareTo(distanceB);
      });

      final next = remaining.removeAt(0);
      ordered.add(next);
      currentLat = next.latitude!;
      currentLng = next.longitude!;
    }

    return ordered;
  }

  List<Map<String, double>> polylinePoints(List<DailyClient> orderedRoute) {
    return orderedRoute
        .where((client) => client.hasCoordinates)
        .map(
          (client) => {
            'lat': client.latitude!,
            'lng': client.longitude!,
          },
        )
        .toList();
  }

  double _distance(double lat1, double lng1, double lat2, double lng2) {
    final dLat = lat2 - lat1;
    final dLng = lng2 - lng1;
    return sqrt(dLat * dLat + dLng * dLng);
  }
}
