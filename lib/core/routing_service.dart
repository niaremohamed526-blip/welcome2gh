import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Distance + duration for one route, from OSRM.
class RouteSummary {
  final double distanceMeters;
  final double durationSeconds;
  const RouteSummary(this.distanceMeters, this.durationSeconds);

  int get minutes => (durationSeconds / 60).round();
}

/// Thin wrapper over the FOSSGIS OSRM engines — one engine per travel mode so
/// car / bike / foot return real, mode-specific times (the public
/// router.project-osrm.org demo only knows cars). No API key required.
class RoutingService {
  RoutingService._();

  static const Map<String, String> _host = {
    'driving': 'https://routing.openstreetmap.de/routed-car',
    'cycling': 'https://routing.openstreetmap.de/routed-bike',
    'foot': 'https://routing.openstreetmap.de/routed-foot',
  };

  /// Fetch just the distance + duration for [profile] ('driving' | 'cycling' |
  /// 'foot'). Returns null on any failure so callers can fall back gracefully.
  static Future<RouteSummary?> summary({
    required LatLng from,
    required LatLng to,
    required String profile,
  }) async {
    final host = _host[profile] ?? _host['driving']!;
    final uri = Uri.parse(
      '$host/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=false',
    );
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final r = routes.first as Map<String, dynamic>;
      return RouteSummary(
        (r['distance'] as num).toDouble(),
        (r['duration'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
