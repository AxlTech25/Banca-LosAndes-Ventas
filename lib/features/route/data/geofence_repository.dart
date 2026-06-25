import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class WorkZone {
  const WorkZone({
    required this.id,
    required this.name,
    required this.color,
    required this.polygon,
  });

  final String id;
  final String name;
  final String color;
  final List<GeoPoint> polygon;

  factory WorkZone.fromJson(Map<String, dynamic> json) {
    final points = (json['poligono_json'] as List<dynamic>? ?? [])
        .map(
          (point) => GeoPoint(
            latitude: (point['lat'] as num).toDouble(),
            longitude: (point['lng'] as num).toDouble(),
          ),
        )
        .toList();
    return WorkZone(
      id: json['id'].toString(),
      name: (json['nombre'] ?? 'Zona').toString(),
      color: (json['color'] ?? '#00C1F9').toString(),
      polygon: points,
    );
  }
}

class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class GeofenceRepository {
  GeofenceRepository({required supabase.SupabaseClient client})
      : _client = client;

  final supabase.SupabaseClient _client;

  Future<List<WorkZone>> fetchZonesForAdvisor(String advisorId) async {
    final rows = await _client
        .from('zonas_asesores')
        .select('''
          zona_id,
          zonas_trabajo (
            id,
            nombre,
            color,
            poligono_json,
            activa
          )
        ''')
        .eq('asesor_id', advisorId);

    final zones = <WorkZone>[];
    for (final row in rows as List) {
      final zoneJson = row['zonas_trabajo'];
      if (zoneJson is! Map<String, dynamic>) {
        continue;
      }
      if (zoneJson['activa'] != true) {
        continue;
      }
      zones.add(WorkZone.fromJson(zoneJson));
    }
    return zones;
  }

  bool isInsideAnyZone(double lat, double lng, List<WorkZone> zones) {
    for (final zone in zones) {
      if (_pointInPolygon(lat, lng, zone.polygon)) {
        return true;
      }
    }
    return zones.isEmpty;
  }

  bool _pointInPolygon(double lat, double lng, List<GeoPoint> polygon) {
    if (polygon.length < 3) {
      return true;
    }
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;
      final intersect = ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi + 0.0000001) + xi);
      if (intersect) {
        inside = !inside;
      }
    }
    return inside;
  }
}
