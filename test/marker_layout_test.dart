import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:welcome2gh/core/geo/geo_math.dart';
import 'package:welcome2gh/core/geo/marker_layout.dart';

void main() {
  group('ScreenBox.overlaps', () {
    test('detects overlapping boxes', () {
      const a = ScreenBox(0, 0, 10, 10);
      const b = ScreenBox(5, 5, 15, 15);
      expect(a.overlaps(b), isTrue);
      expect(b.overlaps(a), isTrue);
    });

    test('edge-touching boxes do not count as overlapping', () {
      const a = ScreenBox(0, 0, 10, 10);
      const b = ScreenBox(10, 0, 20, 10); // shares the x=10 edge only
      expect(a.overlaps(b), isFalse);
    });

    test('fully disjoint boxes do not overlap', () {
      const a = ScreenBox(0, 0, 10, 10);
      const b = ScreenBox(100, 100, 110, 110);
      expect(a.overlaps(b), isFalse);
    });

    test('containment counts as overlap', () {
      const outer = ScreenBox(0, 0, 100, 100);
      const inner = ScreenBox(40, 40, 60, 60);
      expect(outer.overlaps(inner), isTrue);
    });
  });

  group('ScreenBox.inflate / isOutside', () {
    test('inflate grows on all sides', () {
      const b = ScreenBox(10, 10, 20, 20);
      final i = b.inflate(5);
      expect(i.left, 5);
      expect(i.top, 5);
      expect(i.right, 25);
      expect(i.bottom, 25);
    });

    test('isOutside is true only when entirely beyond the viewport', () {
      const onScreen = ScreenBox(10, 10, 20, 20);
      const offLeft = ScreenBox(-30, 10, -10, 20);
      const partial = ScreenBox(-5, 10, 5, 20);
      expect(onScreen.isOutside(400, 800), isFalse);
      expect(offLeft.isOutside(400, 800), isTrue);
      expect(partial.isOutside(400, 800), isFalse);
    });
  });

  group('MarkerCollisionResolver', () {
    const resolver = MarkerCollisionResolver(padding: 0);

    MarkerSpec<String> marker(String id, LatLng p, int priority) => MarkerSpec(
          id: id,
          point: p,
          width: 40,
          height: 40,
          priority: priority,
          data: id,
        );

    test('keeps the higher-priority marker when two collide', () {
      const vp = MapViewport(
        center: LatLng(5.6037, -0.1870),
        zoom: 13,
        width: 400,
        height: 800,
      );
      // Same point => guaranteed collision.
      final specs = [
        marker('low', const LatLng(5.6037, -0.1870), 1),
        marker('high', const LatLng(5.6037, -0.1870), 10),
      ];
      final kept = resolver.resolve(specs, vp);
      expect(kept.length, 1);
      expect(kept.single.id, 'high');
    });

    test('keeps both markers when they do not collide', () {
      const vp = MapViewport(
        center: LatLng(5.6037, -0.1870),
        zoom: 15, // far enough apart on screen, both still visible
        width: 400,
        height: 800,
      );
      final specs = [
        marker('a', const LatLng(5.6037, -0.1870), 1),
        marker('b', const LatLng(5.6060, -0.1900), 1),
      ];
      final kept = resolver.resolve(specs, vp);
      expect(kept.length, 2);
    });

    test('low zoom collapses clustered markers; high zoom separates them', () {
      final specs = [
        marker('a', const LatLng(5.6037, -0.1870), 3),
        marker('b', const LatLng(5.6050, -0.1880), 2),
        marker('c', const LatLng(5.6060, -0.1890), 1),
      ];

      const lowZoom = MapViewport(
        center: LatLng(5.6050, -0.1880),
        zoom: 2, // whole world tiny => everything overlaps
        width: 400,
        height: 800,
      );
      const highZoom = MapViewport(
        center: LatLng(5.6050, -0.1880),
        zoom: 16, // zoomed in enough to separate, all still on screen
        width: 400,
        height: 800,
      );

      final low = resolver.resolve(specs, lowZoom);
      final high = resolver.resolve(specs, highZoom);

      expect(low.length, 1, reason: 'at zoom 2 all three collide into one');
      expect(low.single.id, 'a', reason: 'highest priority survives');
      expect(high.length, 3, reason: 'at zoom 19 all three are distinct');
    });

    test('culls markers that are entirely off-screen', () {
      const vp = MapViewport(
        center: LatLng(5.6037, -0.1870),
        zoom: 13,
        width: 400,
        height: 800,
      );
      final specs = [
        marker('onscreen', const LatLng(5.6037, -0.1870), 1),
        marker('faraway', const LatLng(40.0, 100.0), 5),
      ];
      final kept = resolver.resolve(specs, vp);
      expect(kept.map((m) => m.id), ['onscreen']);
    });

    test('is deterministic for equal-priority collisions (tie-break by id)', () {
      const vp = MapViewport(
        center: LatLng(5.6037, -0.1870),
        zoom: 13,
        width: 400,
        height: 800,
      );
      final specs = [
        marker('zebra', const LatLng(5.6037, -0.1870), 5),
        marker('apple', const LatLng(5.6037, -0.1870), 5),
      ];
      final kept = resolver.resolve(specs, vp);
      expect(kept.single.id, 'apple', reason: 'lexicographically first wins');
    });

    test('empty input yields empty output', () {
      const vp = MapViewport(
        center: LatLng(0, 0),
        zoom: 10,
        width: 400,
        height: 800,
      );
      expect(resolver.resolve(<MarkerSpec<String>>[], vp), isEmpty);
    });
  });

  group('MarkerSpec.boxIn anchoring', () {
    const vp = MapViewport(
      center: LatLng(0, 0),
      zoom: 10,
      width: 400,
      height: 800,
    );

    test('center anchor centres the box on the point', () {
      const spec = MarkerSpec<int>(
        id: 'c',
        point: LatLng(0, 0),
        width: 40,
        height: 40,
        priority: 1,
        data: 0,
        anchor: MarkerAnchor.center,
      );
      final box = spec.boxIn(vp);
      expect(box.centerX, closeTo(200, 1e-6));
      expect(box.centerY, closeTo(400, 1e-6));
    });

    test('bottom anchor places the point at the bottom edge', () {
      const spec = MarkerSpec<int>(
        id: 'p',
        point: LatLng(0, 0),
        width: 40,
        height: 40,
        priority: 1,
        data: 0,
        anchor: MarkerAnchor.bottom,
      );
      final box = spec.boxIn(vp);
      expect(box.bottom, closeTo(400, 1e-6)); // point is the screen-centre
      expect(box.top, closeTo(360, 1e-6)); // 40px above
    });
  });
}
