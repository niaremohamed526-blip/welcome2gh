import 'package:latlong2/latlong.dart';
import 'geo_math.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Structured layout system for map markers.
///
/// Markers are described declaratively (where they are, how big they are on
/// screen, and how important they are). The [MarkerCollisionResolver] then
/// projects each one into the current [MapViewport], computes its screen-space
/// [ScreenBox], and hides any lower-priority marker whose box overlaps a
/// higher-priority one that has already been placed.
///
/// This keeps the map readable at every zoom level without depending on the
/// rendering library's internal clustering.
/// ─────────────────────────────────────────────────────────────────────────

/// An axis-aligned bounding box in screen pixels.
class ScreenBox {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const ScreenBox(this.left, this.top, this.right, this.bottom);

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  /// True when this box and [other] share any area. Edge-touching boxes
  /// (e.g. right == other.left) are treated as *not* overlapping.
  bool overlaps(ScreenBox other) =>
      left < other.right &&
      right > other.left &&
      top < other.bottom &&
      bottom > other.top;

  /// Grow the box outward by [margin] on every side (used as collision
  /// padding so markers keep a little breathing room).
  ScreenBox inflate(double margin) =>
      ScreenBox(left - margin, top - margin, right + margin, bottom + margin);

  /// Whether the box lies entirely outside a viewport of the given size.
  bool isOutside(double viewWidth, double viewHeight) =>
      right < 0 || bottom < 0 || left > viewWidth || top > viewHeight;

  @override
  String toString() =>
      'ScreenBox(l:${left.toStringAsFixed(1)}, t:${top.toStringAsFixed(1)}, '
      'r:${right.toStringAsFixed(1)}, b:${bottom.toStringAsFixed(1)})';
}

/// How a marker's box is positioned relative to its world point.
enum MarkerAnchor {
  /// Point sits at the centre of the box (dots, chips).
  center,

  /// Point sits at the bottom-centre of the box (pins, teardrops).
  bottom,
}

/// A declarative description of one marker.
///
/// [T] is whatever domain object the caller wants to carry through to the
/// render step (a `Place`, an `AlertItem`, …).
class MarkerSpec<T> {
  /// Stable identity — used to de-dupe and to key widgets.
  final String id;

  /// Geographic location of the marker.
  final LatLng point;

  /// On-screen size of the marker, in logical pixels.
  final double width;
  final double height;

  /// Higher wins. When two markers collide the lower priority is hidden.
  final int priority;

  /// Where [point] sits inside the box.
  final MarkerAnchor anchor;

  /// Caller payload, returned untouched in the resolved list.
  final T data;

  const MarkerSpec({
    required this.id,
    required this.point,
    required this.width,
    required this.height,
    required this.priority,
    required this.data,
    this.anchor = MarkerAnchor.center,
  });

  /// Compute this marker's screen-space bounding box within [viewport].
  ScreenBox boxIn(MapViewport viewport) {
    final s = viewport.worldToScreen(point);
    switch (anchor) {
      case MarkerAnchor.center:
        return ScreenBox(
          s.x - width / 2,
          s.y - height / 2,
          s.x + width / 2,
          s.y + height / 2,
        );
      case MarkerAnchor.bottom:
        return ScreenBox(
          s.x - width / 2,
          s.y - height,
          s.x + width / 2,
          s.y,
        );
    }
  }
}

/// Greedy, deterministic priority-based de-clutter.
///
/// 1. Sort markers by priority (highest first); ties broken by id for stable
///    ordering so the same input always yields the same output.
/// 2. Walk the list, keeping a marker only if its (padded) box does not
///    overlap any box already kept and it is at least partially on screen.
class MarkerCollisionResolver {
  /// Extra padding (px) added around every box before the overlap test.
  final double padding;

  const MarkerCollisionResolver({this.padding = 2});

  /// Returns the subset of [specs] that should be drawn in [viewport],
  /// highest-priority-first, with collisions removed.
  List<MarkerSpec<T>> resolve<T>(
    List<MarkerSpec<T>> specs,
    MapViewport viewport,
  ) {
    final sorted = [...specs]..sort((a, b) {
        final byPriority = b.priority.compareTo(a.priority);
        return byPriority != 0 ? byPriority : a.id.compareTo(b.id);
      });

    final kept = <MarkerSpec<T>>[];
    final keptBoxes = <ScreenBox>[];

    for (final spec in sorted) {
      final box = spec.boxIn(viewport).inflate(padding);

      // Cull anything entirely off-screen — it can never collide or be seen.
      if (box.isOutside(viewport.width, viewport.height)) continue;

      var collides = false;
      for (final other in keptBoxes) {
        if (box.overlaps(other)) {
          collides = true;
          break;
        }
      }
      if (!collides) {
        kept.add(spec);
        keptBoxes.add(box);
      }
    }
    return kept;
  }
}
