import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:welcome2gh/core/geo/geo_math.dart';

void main() {
  group('GeoProjection.mapSize', () {
    test('doubles every zoom level', () {
      expect(GeoProjection.mapSize(0), 256);
      expect(GeoProjection.mapSize(1), 512);
      expect(GeoProjection.mapSize(2), 1024);
    });

    test('is finite and large at maximum zoom', () {
      final size = GeoProjection.mapSize(22);
      expect(size.isFinite, isTrue);
      expect(size, greaterThan(1e9));
    });
  });

  group('GeoProjection.project / unproject', () {
    test('null island projects to the centre of the world at zoom 0', () {
      final px = GeoProjection.project(const LatLng(0, 0), 0);
      expect(px.x, closeTo(128, 1e-6)); // 256 / 2
      expect(px.y, closeTo(128, 1e-6));
    });

    test('round-trips within tolerance across zoom levels', () {
      const points = [
        LatLng(5.6037, -0.1870), // Accra
        LatLng(51.5074, -0.1278), // London
        LatLng(-33.8688, 151.2093), // Sydney
        LatLng(0, 0),
      ];
      for (final zoom in [0.0, 5.0, 12.5, 19.0, 22.0]) {
        for (final p in points) {
          final back = GeoProjection.unproject(
              GeoProjection.project(p, zoom), zoom);
          expect(back.latitude, closeTo(p.latitude, 1e-6),
              reason: 'lat @zoom $zoom for $p');
          expect(back.longitude, closeTo(p.longitude, 1e-6),
              reason: 'lng @zoom $zoom for $p');
        }
      }
    });

    test('clamps extreme latitudes instead of producing NaN/Infinity', () {
      for (final lat in [89.0, -89.0, 90.0, -90.0]) {
        final px = GeoProjection.project(LatLng(lat, 0), 10);
        expect(px.y.isFinite, isTrue, reason: 'lat $lat must stay finite');
        expect(px.y.isNaN, isFalse);
      }
    });
  });

  group('GeoProjection.normalizeLongitude (antimeridian crossing)', () {
    test('wraps values beyond ±180', () {
      expect(GeoProjection.normalizeLongitude(190), closeTo(-170, 1e-9));
      expect(GeoProjection.normalizeLongitude(-190), closeTo(170, 1e-9));
      expect(GeoProjection.normalizeLongitude(360), closeTo(0, 1e-9));
      expect(GeoProjection.normalizeLongitude(540), closeTo(-180, 1e-9));
    });

    test('leaves in-range values untouched', () {
      expect(GeoProjection.normalizeLongitude(0), closeTo(0, 1e-9));
      expect(GeoProjection.normalizeLongitude(179.9), closeTo(179.9, 1e-9));
      expect(GeoProjection.normalizeLongitude(-179.9), closeTo(-179.9, 1e-9));
    });
  });

  group('GeoProjection.groundResolution / metersToPixels', () {
    test('matches the known Web-Mercator resolution at the equator, zoom 0', () {
      // ~156543.03 metres per pixel at the equator, zoom 0.
      expect(GeoProjection.groundResolution(0, 0), closeTo(156543.03, 0.5));
    });

    test('one pixel maps back to one pixel through meters↔pixels', () {
      final meters = GeoProjection.pixelsToMeters(1, 0, 0);
      expect(GeoProjection.metersToPixels(meters, 0, 0), closeTo(1, 1e-9));
    });

    test('the same distance covers more pixels as zoom increases', () {
      final z10 = GeoProjection.metersToPixels(1000, 5.6, 10);
      final z14 = GeoProjection.metersToPixels(1000, 5.6, 14);
      expect(z14, greaterThan(z10));
      // 4 zoom levels => 2^4 = 16x more pixels.
      expect(z14 / z10, closeTo(16, 1e-6));
    });

    test('resolution shrinks toward the poles', () {
      final atEquator = GeoProjection.groundResolution(0, 10);
      final atHighLat = GeoProjection.groundResolution(60, 10);
      expect(atHighLat, lessThan(atEquator));
    });
  });

  group('haversineMeters', () {
    test('is zero for identical points', () {
      expect(haversineMeters(const LatLng(5.6, -0.18), const LatLng(5.6, -0.18)),
          closeTo(0, 1e-6));
    });

    test('one degree of longitude at the equator ≈ 111.32 km', () {
      final d = haversineMeters(const LatLng(0, 0), const LatLng(0, 1));
      expect(d, closeTo(111319.49, 1));
    });

    test('is symmetric', () {
      const a = LatLng(5.6037, -0.1870);
      const b = LatLng(5.6500, -0.2000);
      expect(haversineMeters(a, b), closeTo(haversineMeters(b, a), 1e-6));
    });

    test('handles the antimeridian (179 → -179 is ~2 degrees, not 358)', () {
      final d = haversineMeters(const LatLng(0, 179), const LatLng(0, -179));
      // Short way around: 2 degrees of longitude at the equator.
      expect(d, closeTo(2 * 111319.49, 5));
    });
  });

  group('MapViewport', () {
    const vp = MapViewport(
      center: LatLng(5.6037, -0.1870),
      zoom: 13,
      width: 400,
      height: 800,
    );

    test('projects its own centre to the middle of the screen', () {
      final s = vp.worldToScreen(vp.center);
      expect(s.x, closeTo(200, 1e-6));
      expect(s.y, closeTo(400, 1e-6));
    });

    test('worldToScreen / screenToWorld round-trip', () {
      const probe = LatLng(5.6100, -0.1900);
      final back = vp.screenToWorld(vp.worldToScreen(probe));
      expect(back.latitude, closeTo(probe.latitude, 1e-6));
      expect(back.longitude, closeTo(probe.longitude, 1e-6));
    });

    test('contains() reports on/off screen correctly', () {
      expect(vp.contains(vp.center), isTrue);
      expect(vp.contains(const LatLng(45, 100)), isFalse);
    });
  });

  group('degreesToRadians', () {
    test('converts known angles', () {
      expect(degreesToRadians(0), 0);
      expect(degreesToRadians(180), closeTo(3.14159265, 1e-6));
      expect(degreesToRadians(90), closeTo(1.57079632, 1e-6));
    });
  });
}
