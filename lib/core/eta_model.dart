import 'dart:math' as math;

/// Hybrid, calibrated ETA engine.
///
/// Free routing engines (OSRM foot/bike on OSM data) frequently report
/// unrealistic walking/cycling durations — especially on sparse African
/// pedestrian/bike networks. So instead of trusting their duration blindly we:
///
///  * keep the engine's **road distance** (reliable) and the **car** duration
///    (road-speed aware), padding the car for urban congestion;
///  * **recompute walking & cycling** from realistic urban speeds plus
///    per-maneuver (turn/intersection) penalties.
///
/// This yields believable, consistently-ordered times (walking slowest, then
/// cycling, then car) tuned for mixed urban traffic such as Accra.
class EtaModel {
  EtaModel._();

  /// Realistic average urban speeds (metres/second).
  static const Map<String, double> _speedMps = {
    'foot': 1.30, // ~4.7 km/h
    'cycling': 4.2, // ~15 km/h
    'driving': 8.3, // ~30 km/h
  };

  /// Seconds added per maneuver (intersections, turns, stops).
  static const Map<String, double> _turnPenalty = {
    'foot': 1.0,
    'cycling': 3.0,
    'driving': 6.0,
  };

  /// Urban congestion multiplier applied to the engine's car duration.
  static const double _carCongestion = 1.30;

  /// A car can't realistically average more than this in the city, so the
  /// computed time never drops below distance / this speed.
  static const double _carMaxSpeedMps = 11.1; // 40 km/h

  /// Total trip seconds for [profile] ('foot' | 'cycling' | 'driving') given the
  /// engine's road [distanceMeters], its [apiDurationSec], and the maneuver
  /// count [turns].
  static double seconds({
    required String profile,
    required double distanceMeters,
    required double apiDurationSec,
    int turns = 0,
  }) {
    final v = _speedMps[profile] ?? _speedMps['driving']!;
    final pen = turns * (_turnPenalty[profile] ?? 4.0);

    if (profile == 'driving') {
      // Trust the road-speed-aware engine time, pad for traffic, but never
      // faster than is physically plausible for city driving.
      final padded = apiDurationSec * _carCongestion + pen;
      final floor = distanceMeters / _carMaxSpeedMps;
      return math.max(padded, floor);
    }
    // Walking / cycling: calibrated distance/speed model.
    return distanceMeters / v + pen;
  }

  /// Whole minutes (rounded up) for [profile].
  static int minutes({
    required String profile,
    required double distanceMeters,
    required double apiDurationSec,
    int turns = 0,
  }) =>
      (seconds(
                profile: profile,
                distanceMeters: distanceMeters,
                apiDurationSec: apiDurationSec,
                turns: turns,
              ) /
              60)
          .ceil();

  /// Detour ratio: route distance ÷ straight-line distance. A high value
  /// (e.g. > 2.5) signals a bad detour or poor map data for that mode.
  static double detourRatio({
    required double routeMeters,
    required double straightMeters,
  }) =>
      straightMeters <= 0 ? 1 : routeMeters / straightMeters;
}
