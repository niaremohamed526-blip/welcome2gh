import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Central coordinate-transformation utility for the whole app.
///
/// Every conversion between *world* coordinates (latitude/longitude or
/// metres on the ground) and *screen* pixels goes through here. This is the
/// single source of truth for map math so the rendering, marker collision
/// detection, distance calculations and tests all agree on the same model.
///
/// The model is the standard Web-Mercator (EPSG:3857 / "Google") projection,
/// the exact projection `flutter_map` paints its tiles with, so our overlay
/// math lines up pixel-for-pixel with the rendered basemap.
/// ─────────────────────────────────────────────────────────────────────────

/// A point in absolute world-pixel space (origin at the top-left of the map
/// at a given zoom level) or in screen space, depending on context.
class Pixel {
  final double x;
  final double y;
  const Pixel(this.x, this.y);

  Pixel operator +(Pixel o) => Pixel(x + o.x, y + o.y);
  Pixel operator -(Pixel o) => Pixel(x - o.x, y - o.y);

  @override
  bool operator ==(Object other) =>
      other is Pixel && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
  @override
  String toString() => 'Pixel(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

/// Pure, stateless Web-Mercator projection math.
class GeoProjection {
  GeoProjection._();

  /// Tile size used by the basemap (Carto / OSM standard).
  static const int tileSize = 256;

  /// WGS-84 equatorial radius in metres.
  static const double earthRadius = 6378137.0;

  /// Web-Mercator is only defined up to ±85.05113° — beyond that y → ∞.
  static const double maxLatitude = 85.05112878;

  /// Clamp a latitude into the projectable range.
  static double clampLatitude(double lat) =>
      lat.clamp(-maxLatitude, maxLatitude).toDouble();

  /// Wrap a longitude into [-180, 180) so coordinates that cross the
  /// antimeridian behave predictably.
  static double normalizeLongitude(double lng) {
    var l = (lng + 180.0) % 360.0;
    if (l < 0) l += 360.0;
    return l - 180.0;
  }

  /// Width/height of the whole world in pixels at [zoom].
  static double mapSize(double zoom) => tileSize * math.pow(2.0, zoom).toDouble();

  /// Project a lat/lng to an absolute world-pixel coordinate at [zoom].
  static Pixel project(LatLng point, double zoom) {
    final size = mapSize(zoom);
    final lat = clampLatitude(point.latitude);
    final lng = normalizeLongitude(point.longitude);
    final x = (lng + 180.0) / 360.0 * size;
    final sinY = math.sin(lat * math.pi / 180.0).clamp(-0.9999, 0.9999);
    final y = (0.5 - math.log((1 + sinY) / (1 - sinY)) / (4 * math.pi)) * size;
    return Pixel(x, y);
  }

  /// Inverse of [project] — world pixel back to lat/lng.
  static LatLng unproject(Pixel px, double zoom) {
    final size = mapSize(zoom);
    final lng = px.x / size * 360.0 - 180.0;
    final n = math.pi - 2 * math.pi * px.y / size;
    final lat = 180.0 / math.pi *
        math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    return LatLng(lat, lng);
  }

  /// Metres represented by one pixel at the given latitude + zoom.
  static double groundResolution(double lat, double zoom) {
    final l = clampLatitude(lat);
    return math.cos(l * math.pi / 180.0) *
        2 *
        math.pi *
        earthRadius /
        mapSize(zoom);
  }

  /// Convert a real-world distance in metres to a pixel length at the given
  /// latitude + zoom. Used to draw geo-accurate radii (e.g. alert zones).
  static double metersToPixels(double meters, double lat, double zoom) =>
      meters / groundResolution(lat, zoom);

  /// Inverse of [metersToPixels].
  static double pixelsToMeters(double pixels, double lat, double zoom) =>
      pixels * groundResolution(lat, zoom);
}

/// An immutable viewport — everything needed to transform world → screen.
///
/// Treat this as a value: build a fresh one whenever the camera (centre/zoom)
/// or the widget size changes, then ask it to project points.
class MapViewport {
  final LatLng center;
  final double zoom;
  final double width;
  final double height;

  const MapViewport({
    required this.center,
    required this.zoom,
    required this.width,
    required this.height,
  });

  /// World-pixel coordinate of the viewport's top-left corner.
  Pixel get _origin {
    final c = GeoProjection.project(center, zoom);
    return Pixel(c.x - width / 2, c.y - height / 2);
  }

  /// Project a geographic point to screen pixels within this viewport.
  Pixel worldToScreen(LatLng point) =>
      GeoProjection.project(point, zoom) - _origin;

  /// Inverse — a screen pixel back to a geographic point.
  LatLng screenToWorld(Pixel screen) =>
      GeoProjection.unproject(screen + _origin, zoom);

  /// Whether [point] is currently visible (optionally with a pixel [margin]).
  bool contains(LatLng point, {double margin = 0}) {
    final s = worldToScreen(point);
    return s.x >= -margin &&
        s.x <= width + margin &&
        s.y >= -margin &&
        s.y <= height + margin;
  }

  MapViewport copyWith({
    LatLng? center,
    double? zoom,
    double? width,
    double? height,
  }) =>
      MapViewport(
        center: center ?? this.center,
        zoom: zoom ?? this.zoom,
        width: width ?? this.width,
        height: height ?? this.height,
      );
}

/// Great-circle distance in metres between two points (haversine).
double haversineMeters(LatLng a, LatLng b) {
  const r = GeoProjection.earthRadius;
  final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
  final dLng = (b.longitude - a.longitude) * math.pi / 180.0;
  final lat1 = a.latitude * math.pi / 180.0;
  final lat2 = b.latitude * math.pi / 180.0;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Degrees → radians (e.g. compass heading to a rotation angle).
double degreesToRadians(double degrees) => degrees * math.pi / 180.0;
