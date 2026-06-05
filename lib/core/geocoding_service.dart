import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// One geocoding result: a human label + its coordinates.
class GeoResult {
  final String label;
  final LatLng location;
  const GeoResult(this.label, this.location);
}

/// Address/place search → coordinates, via OpenStreetMap Nominatim.
/// Free, no API key, CORS-enabled. (Fair-use: low volume only.)
class GeocodingService {
  GeocodingService._();

  /// Search for a place or address. Biased toward Ghana so local names
  /// resolve well. Returns up to [limit] matches.
  static Future<List<GeoResult>> search(String query, {int limit = 6}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?format=json&addressdetails=0&limit=$limit'
      '&countrycodes=gh'
      '&q=${Uri.encodeComponent(q)}',
    );
    try {
      final resp = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return [];
      final list = jsonDecode(resp.body) as List;
      return list
          .map((e) {
            final m = e as Map<String, dynamic>;
            final lat = double.tryParse(m['lat']?.toString() ?? '');
            final lon = double.tryParse(m['lon']?.toString() ?? '');
            if (lat == null || lon == null) return null;
            return GeoResult(m['display_name']?.toString() ?? q, LatLng(lat, lon));
          })
          .whereType<GeoResult>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Reverse-geocode coordinates → a readable address (best effort).
  static Future<String?> reverse(LatLng point) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=json&zoom=18&addressdetails=0'
      '&lat=${point.latitude}&lon=${point.longitude}',
    );
    try {
      final resp = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;
      final m = jsonDecode(resp.body) as Map<String, dynamic>;
      return m['display_name']?.toString();
    } catch (_) {
      return null;
    }
  }
}
