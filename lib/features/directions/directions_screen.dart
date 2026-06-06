import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
// geobase (re-exported by maplibre) also defines `Position` — hide it so it
// doesn't clash with geolocator's `Position`.
import 'package:maplibre/maplibre.dart' hide Position;
import '../../shared/theme/app_theme.dart';
import '../../core/geo/geo_math.dart';
import '../map/map_helpers.dart' show glass;

// ── Data model ──────────────────────────────────────────────────────────────

class RouteStep {
  final String instruction;
  final double distanceM;
  final String maneuverType;
  final String? modifier;

  const RouteStep({
    required this.instruction,
    required this.distanceM,
    required this.maneuverType,
    this.modifier,
  });
}

// ── Screen ──────────────────────────────────────────────────────────────────

/// MapLibre (vector + 3D) directions & turn-by-turn navigation.
///
/// Planning mode frames the whole route with an animated glowing line, a
/// flowing light "comet", and a pulsing destination. Tapping START dives the
/// camera into an immersive, tilted, heading-up chase view that follows the
/// user and adapts zoom to speed — the Google/Tesla-style driving experience.
class DirectionsScreen extends StatefulWidget {
  final double destLat;
  final double destLng;
  final String destName;

  /// When true, navigation mode starts automatically once the route loads
  /// (used for previews/demos). Normal entry leaves this false.
  final bool autoStart;

  const DirectionsScreen({
    super.key,
    required this.destLat,
    required this.destLng,
    required this.destName,
    this.autoStart = false,
  });

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen>
    with TickerProviderStateMixin {
  static const _styleUrl = 'https://tiles.openfreemap.org/styles/liberty';
  static const _emptyFc = '{"type":"FeatureCollection","features":[]}';

  // FOSSGIS OSRM engines — one per mode so car/bike/foot return real times.
  static const Map<String, String> _osrmHost = {
    'driving': 'https://routing.openstreetmap.de/routed-car',
    'cycling': 'https://routing.openstreetmap.de/routed-bike',
    'foot': 'https://routing.openstreetmap.de/routed-foot',
  };

  MapController? _map;
  StyleController? _style;
  bool _styleReady = false;

  ll.LatLng? _userLoc;
  double? _userHeading;

  List<ll.LatLng> _routePoints = [];
  List<double> _cum = []; // cumulative distance to each point (m)
  double _total = 0;
  double? _distanceKm;
  int? _durationMin;
  String _profile = 'driving';
  bool _loading = true;
  String? _error;

  List<RouteStep> _steps = [];
  int _currentStepIndex = 0;
  double _remainingM = 0;

  bool _navigating = false;
  bool _following = true;
  // Navigation state machine flags (idle/preview -> active -> rerouting ->
  // arrived / gps-lost). Kept as booleans to layer cleanly over _navigating.
  bool _arrived = false;
  bool _rerouting = false;
  bool _gpsLost = false;
  double _distAlong = 0; // metres travelled along the route (from snap)

  StreamSubscription<Position>? _locationSub;
  Timer? _gpsWatchdog; // fires if no GPS fix arrives for a while
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);

  // Animations
  late final AnimationController _drawCtrl;
  late final AnimationController _pulseCtrl;
  DateTime _lastFx = DateTime.fromMillisecondsSinceEpoch(0);

  ll.LatLng get _dest => ll.LatLng(widget.destLat, widget.destLng);

  @override
  void initState() {
    super.initState();
    _drawCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..addListener(_onDrawTick)
      ..addStatusListener(_onDrawStatus);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..addListener(_onFxTick);
    _start();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _gpsWatchdog?.cancel();
    _drawCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    await _initLocation();
    if (_userLoc != null) {
      await _fetchRoute();
    } else if (mounted) {
      // No real fix: never route from a fake origin (that's what produced the
      // bogus 9.9 km / 2h results). Ask the user to enable location instead.
      setState(() {
        _loading = false;
        _error = 'Turn on location to get directions from where you are.';
      });
    }
  }

  // ── Coordinate helpers ──────────────────────────────────────────────────────

  Geographic _g(ll.LatLng p) => Geographic(lon: p.longitude, lat: p.latitude);

  String _lineFc(List<ll.LatLng> pts) => jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                for (final p in pts) [p.longitude, p.latitude]
              ],
            },
          },
        ],
      });

  String _pointFc(ll.LatLng p, Map<String, Object?> props) => jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': props,
            'geometry': {
              'type': 'Point',
              'coordinates': [p.longitude, p.latitude],
            },
          },
        ],
      });

  double _bearingBetween(ll.LatLng a, ll.LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _zoomForSpeed(double mps) {
    if (mps < 1.5) return 18;
    if (mps < 7) return 17;
    if (mps < 14) return 16;
    return 15;
  }

  // ── Map matching (snap GPS to the active route) ─────────────────────────────

  static const double _mPerLat = 110540.0;
  double _mPerLon(double lat) => 111320.0 * math.cos(lat * math.pi / 180);

  /// Project [p] onto segment a→b using a local planar approximation.
  /// Returns the closest point on the segment and the fraction [t] along it.
  ({ll.LatLng pt, double t}) _projectOntoSeg(ll.LatLng p, ll.LatLng a, ll.LatLng b) {
    final mLon = _mPerLon(a.latitude);
    final bx = (b.longitude - a.longitude) * mLon, by = (b.latitude - a.latitude) * _mPerLat;
    final px = (p.longitude - a.longitude) * mLon, py = (p.latitude - a.latitude) * _mPerLat;
    final len2 = bx * bx + by * by;
    var t = len2 <= 0 ? 0.0 : (px * bx + py * by) / len2;
    t = t.clamp(0.0, 1.0);
    return (
      pt: ll.LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t),
      t: t,
    );
  }

  /// Snap a raw GPS fix to the nearest point on the route. Returns the snapped
  /// point, the bearing of that segment (for heading-up), the distance
  /// travelled along the route, and how far off-route the raw fix was (metres).
  ({ll.LatLng point, double bearing, double along, double off}) _snapToRoute(ll.LatLng raw) {
    if (_routePoints.length < 2) {
      return (point: raw, bearing: _userHeading ?? 0, along: _distAlong, off: 0);
    }
    var best = double.infinity;
    var bestPt = raw;
    var bestAlong = 0.0;
    var bestBearing = 0.0;
    for (var i = 0; i < _routePoints.length - 1; i++) {
      final a = _routePoints[i], b = _routePoints[i + 1];
      final pr = _projectOntoSeg(raw, a, b);
      final d = haversineMeters(raw, pr.pt);
      if (d < best) {
        best = d;
        bestPt = pr.pt;
        bestAlong = _cum[i] + (_cum[i + 1] - _cum[i]) * pr.t;
        bestBearing = _bearingBetween(a, b);
      }
    }
    return (point: bestPt, bearing: bestBearing, along: bestAlong, off: best);
  }

  void _updateUserPuck(ll.LatLng p, double bearing) {
    if (!_styleReady) return;
    _style?.updateGeoJsonSource(id: 'user', data: _pointFc(p, {'b': bearing}));
  }

  void _resetGpsWatchdog() {
    _gpsWatchdog?.cancel();
    _gpsWatchdog = Timer(const Duration(seconds: 12), () {
      if (mounted && _navigating && !_arrived) setState(() => _gpsLost = true);
    });
  }

  // ── Location ────────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        debugPrint('[NAV] location permission denied: $perm — not routing.');
        return; // no fake origin; _start surfaces a "turn on location" prompt
      }

      // A REAL, fresh one-shot fix for the route origin.
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
        _userLoc = ll.LatLng(pos.latitude, pos.longitude);
        _userHeading = pos.heading >= 0 ? pos.heading : null;
        debugPrint('[NAV] USER LAT: ${pos.latitude}  LNG: ${pos.longitude}'
            '  ACCURACY: ${pos.accuracy}m  TS: ${pos.timestamp}');
      } catch (e) {
        debugPrint('[NAV] getCurrentPosition failed: $e');
        // Cold/slow GPS (or standing still): fall back to the last-known fix.
        // It's still a REAL position near the user — never a city-centre guess —
        // and the live stream refines it moments later. Not supported on web.
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) {
            _userLoc = ll.LatLng(last.latitude, last.longitude);
            _userHeading = last.heading >= 0 ? last.heading : null;
            debugPrint('[NAV] using LAST-KNOWN: ${last.latitude},${last.longitude}');
          }
        } catch (_) {/* unsupported on web */}
      }

      // Continuous updates. `??=` so retries never stack subscriptions.
      _locationSub ??= Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 4,
        ),
      ).listen(_onPosition);
    } catch (e) {
      debugPrint('[NAV] location error: $e');
    }
  }

  /// Re-acquire location then (re)compute the route. Used by the RETRY button.
  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (_userLoc == null) await _initLocation();
    if (_userLoc != null) {
      await _fetchRoute();
    } else if (mounted) {
      setState(() {
        _loading = false;
        _error = 'Still no location. Check that location is on and permitted for this app.';
      });
    }
  }

  /// Handle each GPS fix. During navigation the raw fix is snapped to the route
  /// (local map matching) so the puck rides the road and drift is corrected.
  void _onPosition(Position pos) {
    if (!mounted) return;
    final raw = ll.LatLng(pos.latitude, pos.longitude);
    if (pos.heading >= 0) _userHeading = pos.heading;
    if (_gpsLost) setState(() => _gpsLost = false);
    if (_navigating) _resetGpsWatchdog();

    if (_navigating && !_arrived && _routePoints.length >= 2) {
      final snap = _snapToRoute(raw);
      _distAlong = snap.along;
      // Heading-up course: follow the road bearing when on-route, otherwise
      // fall back to the device heading.
      final course = snap.off < 40
          ? snap.bearing
          : (pos.heading >= 0 ? pos.heading : snap.bearing);
      _updateUserPuck(snap.point, course);
      setState(() => _userLoc = snap.point);
      if (_following) _followNav(snap.point, course, pos.speed);
      _updateNavProgress();
      _maybeReroute(snap.off);
    } else {
      setState(() => _userLoc = raw);
      _updateUserPuck(raw, _userHeading ?? 0);
      // Recover if the one-shot fix failed: now that we have a real position,
      // compute the route from it (instead of never routing).
      if (_routePoints.isEmpty && !_loading) {
        _error = null;
        _fetchRoute();
      }
    }
  }

  /// Immersive chase camera: tilted, heading-up, zoom adapts to speed. The
  /// camera centres on the snapped point so the world glides under a fixed puck.
  void _followNav(ll.LatLng p, double course, double speed) {
    final spd = speed.isFinite && speed > 0 ? speed : 0.0;
    _map?.animateCamera(
      center: _g(p),
      zoom: _zoomForSpeed(spd),
      bearing: course,
      pitch: 58,
      nativeDuration: const Duration(milliseconds: 1100),
    );
  }

  // ── Routing ─────────────────────────────────────────────────────────────────

  Future<void> _fetchRoute({bool reroute = false}) async {
    if (_userLoc == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No location yet. Enable location and retry.';
        });
      }
      return;
    }
    if (!reroute) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final host = _osrmHost[_profile] ?? _osrmHost['driving']!;
      // OSRM expects coordinates as lon,lat (NOT lat,lon).
      final uri = Uri.parse(
        '$host/route/v1/driving/'
        '${_userLoc!.longitude},${_userLoc!.latitude};'
        '${widget.destLng},${widget.destLat}'
        '?overview=full&geometries=geojson&steps=true',
      );
      debugPrint('[NAV] ORIGIN ${_userLoc!.latitude},${_userLoc!.longitude}'
          '  ->  DEST ${widget.destLat},${widget.destLng}  (profile=$_profile)');
      debugPrint('[NAV] OSRM URL: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw 'Server error ${response.statusCode}';
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) throw 'No route found';

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry']['coordinates'] as List;
      final points = geometry
          .map<ll.LatLng>(
              (c) => ll.LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      final steps = _parseSteps(route);

      if (!mounted) return;
      _setRoutePoints(points);
      setState(() {
        _distanceKm = (route['distance'] as num).toDouble() / 1000.0;
        _durationMin = ((route['duration'] as num).toDouble() / 60).round();
        _steps = steps;
        _currentStepIndex = 0;
        _remainingM = _total;
        _distAlong = 0;
        _rerouting = false;
        _loading = false;
      });

      final straightKm = haversineMeters(_userLoc!, _dest) / 1000;
      debugPrint('[NAV] straight-line=${straightKm.toStringAsFixed(2)}km  '
          'ROUTE=${_distanceKm!.toStringAsFixed(2)}km  ETA(raw)=${_durationMin}min'
          '  profile=$_profile');
      if (straightKm > 3) {
        debugPrint('[NAV] WARNING: origin and destination are '
            '${straightKm.toStringAsFixed(1)}km apart as the crow flies — if that '
            'seems wrong, the destination coordinates are likely off.');
      }

      _onRouteReady(reframe: !reroute && !_navigating);

      if (widget.autoStart && !reroute && !_navigating) {
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (mounted && !_navigating) _startNavigation();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load route. $e';
        _loading = false;
      });
    }
  }

  void _setRoutePoints(List<ll.LatLng> points) {
    _routePoints = points;
    _cum = List<double>.filled(points.length, 0);
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += haversineMeters(points[i - 1], points[i]);
      _cum[i] = sum;
    }
    _total = sum;
  }

  void _switchProfile(String p) {
    if (p == _profile || _loading) return;
    setState(() => _profile = p);
    _fetchRoute();
  }

  // ── Animated route ──────────────────────────────────────────────────────────

  void _onRouteReady({bool reframe = true}) {
    if (!_styleReady || _routePoints.length < 2) return;
    _pulseCtrl.stop();
    _drawCtrl
      ..reset()
      ..forward();
    if (reframe) _fitRoute();
  }

  void _onDrawTick() {
    if (!_styleReady) return;
    final f = Curves.easeOutCubic.transform(_drawCtrl.value);
    _style?.updateGeoJsonSource(id: 'route', data: _lineFc(_sublistToFraction(f)));
  }

  void _onDrawStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && _styleReady) {
      _style?.updateGeoJsonSource(id: 'route', data: _lineFc(_routePoints));
      if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat();
    }
  }

  /// Drives both the flowing comet along the route and the destination pulse.
  void _onFxTick() {
    if (!_styleReady) return;
    final now = DateTime.now();
    if (now.difference(_lastFx).inMilliseconds < 45) return; // ~22fps throttle
    _lastFx = now;
    final t = _pulseCtrl.value;
    final comet = _pointAtDistance(t * _total);
    _style?.updateGeoJsonSource(id: 'route-head', data: _pointFc(comet, const {}));
    final phase = (math.sin(t * 2 * math.pi) * 0.5 + 0.5);
    _style?.updateGeoJsonSource(
      id: 'dest',
      data: _pointFc(_dest, {'r': 10 + phase * 16, 'o': 0.5 * (1 - phase)}),
    );
  }

  List<ll.LatLng> _sublistToFraction(double f) {
    if (_routePoints.length < 2) return _routePoints;
    final target = f * _total;
    final out = <ll.LatLng>[_routePoints.first];
    for (var i = 0; i < _routePoints.length - 1; i++) {
      if (_cum[i + 1] <= target) {
        out.add(_routePoints[i + 1]);
      } else {
        final seg = _cum[i + 1] - _cum[i];
        final t = seg <= 0 ? 0.0 : (target - _cum[i]) / seg;
        final a = _routePoints[i], b = _routePoints[i + 1];
        out.add(ll.LatLng(a.latitude + (b.latitude - a.latitude) * t,
            a.longitude + (b.longitude - a.longitude) * t));
        break;
      }
    }
    if (out.length < 2) out.add(_routePoints[1]);
    return out;
  }

  ll.LatLng _pointAtDistance(double d) {
    if (_routePoints.length < 2) return _dest;
    if (d <= 0) return _routePoints.first;
    if (d >= _total) return _routePoints.last;
    for (var i = 0; i < _routePoints.length - 1; i++) {
      if (d <= _cum[i + 1]) {
        final seg = _cum[i + 1] - _cum[i];
        final t = seg <= 0 ? 0.0 : (d - _cum[i]) / seg;
        final a = _routePoints[i], b = _routePoints[i + 1];
        return ll.LatLng(a.latitude + (b.latitude - a.latitude) * t,
            a.longitude + (b.longitude - a.longitude) * t);
      }
    }
    return _routePoints.last;
  }

  // ── Style setup ─────────────────────────────────────────────────────────────

  Future<void> _onStyleLoaded(StyleController style) async {
    _style = style;
    await style.addSource(const GeoJsonSource(id: 'route', data: _emptyFc));
    await style.addSource(const GeoJsonSource(id: 'route-head', data: _emptyFc));
    await style.addSource(GeoJsonSource(id: 'dest', data: _pointFc(_dest, const {'r': 12, 'o': 0.0})));

    // Route: wide blurred glow, dark border, bright core.
    await style.addLayer(const LineStyleLayer(
      id: 'route-glow',
      sourceId: 'route',
      layout: {'line-cap': 'round', 'line-join': 'round'},
      paint: {'line-color': '#FFCC00', 'line-width': 16.0, 'line-blur': 8.0, 'line-opacity': 0.35},
    ));
    await style.addLayer(const LineStyleLayer(
      id: 'route-border',
      sourceId: 'route',
      layout: {'line-cap': 'round', 'line-join': 'round'},
      paint: {'line-color': '#0D1B2A', 'line-width': 9.0},
    ));
    await style.addLayer(const LineStyleLayer(
      id: 'route-core',
      sourceId: 'route',
      layout: {'line-cap': 'round', 'line-join': 'round'},
      paint: {'line-color': '#FFCC00', 'line-width': 5.0},
    ));
    // Destination pulse + dot.
    await style.addLayer(const CircleStyleLayer(
      id: 'dest-pulse',
      sourceId: 'dest',
      paint: {'circle-radius': ['get', 'r'], 'circle-color': '#E53935', 'circle-opacity': ['get', 'o']},
    ));
    await style.addLayer(const CircleStyleLayer(
      id: 'dest-dot',
      sourceId: 'dest',
      paint: {'circle-radius': 7.0, 'circle-color': '#E53935', 'circle-stroke-color': '#FFFFFF', 'circle-stroke-width': 2.0},
    ));
    // Flowing comet.
    await style.addLayer(const CircleStyleLayer(
      id: 'route-head-glow',
      sourceId: 'route-head',
      paint: {'circle-radius': 12.0, 'circle-color': '#FFFFFF', 'circle-blur': 1.0, 'circle-opacity': 0.45},
    ));
    await style.addLayer(const CircleStyleLayer(
      id: 'route-head',
      sourceId: 'route-head',
      paint: {'circle-radius': 5.0, 'circle-color': '#FFFFFF'},
    ));

    // User location puck — snapped to the route during navigation. A blue dot
    // + soft halo + a heading arrow that rotates to the travel direction.
    await style.addSource(const GeoJsonSource(id: 'user', data: _emptyFc));
    try {
      await style.addImageFromIconData(
        id: 'nav-arrow',
        iconData: Icons.navigation_rounded,
        color: const Color(0xFFFFFFFF),
        size: 120,
      );
    } catch (_) {/* already added */}
    await style.addLayer(const CircleStyleLayer(
      id: 'user-halo',
      sourceId: 'user',
      paint: {'circle-radius': 18.0, 'circle-color': '#1E88E5', 'circle-opacity': 0.18},
    ));
    await style.addLayer(const CircleStyleLayer(
      id: 'user-dot',
      sourceId: 'user',
      paint: {'circle-radius': 9.0, 'circle-color': '#1E88E5', 'circle-stroke-color': '#FFFFFF', 'circle-stroke-width': 3.0},
    ));
    await style.addLayer(const SymbolStyleLayer(
      id: 'user-arrow',
      sourceId: 'user',
      layout: {
        'icon-image': 'nav-arrow',
        'icon-size': 0.13,
        'icon-rotate': ['get', 'b'],
        'icon-rotation-alignment': 'map',
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
      },
    ));

    _styleReady = true;
    if (_userLoc != null) _updateUserPuck(_userLoc!, _userHeading ?? 0);
    if (_routePoints.length >= 2) _onRouteReady();
  }

  // ── Camera ──────────────────────────────────────────────────────────────────

  void _fitRoute({double pitch = 0, double bearing = 0}) {
    if (_routePoints.isEmpty) return;
    final pts = [..._routePoints, if (_userLoc != null) _userLoc!];
    var west = 180.0, east = -180.0, south = 90.0, north = -90.0;
    for (final p in pts) {
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
    }
    _map?.fitBounds(
      bounds: LngLatBounds(
        longitudeWest: west,
        longitudeEast: east,
        latitudeSouth: south,
        latitudeNorth: north,
      ),
      bearing: bearing,
      pitch: pitch,
      padding: const EdgeInsets.fromLTRB(50, 150, 50, 260),
      nativeDuration: const Duration(milliseconds: 900),
    );
  }

  void _startNavigation() {
    if (_routePoints.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _navigating = true;
      _following = true;
      _arrived = false;
      _gpsLost = false;
      _rerouting = false;
      _distAlong = 0;
    });
    _resetGpsWatchdog();
    final u = _userLoc;
    if (u != null) {
      double bearing = _userHeading ?? 0;
      if (_routePoints.length >= 2) bearing = _bearingBetween(u, _routePoints[1]);
      // Cinematic dive into the tilted heading-up chase view.
      _map?.animateCamera(
        center: _g(u),
        zoom: 17.5,
        pitch: 58,
        bearing: bearing,
        nativeDuration: const Duration(milliseconds: 1400),
      );
    }
  }

  void _exitNavigation() {
    HapticFeedback.selectionClick();
    _gpsWatchdog?.cancel();
    setState(() {
      _navigating = false;
      _following = true;
      _arrived = false;
      _gpsLost = false;
      _rerouting = false;
    });
    _fitRoute();
  }

  void _recenter() {
    HapticFeedback.selectionClick();
    setState(() => _following = true);
    final u = _userLoc;
    if (u != null) {
      _map?.animateCamera(
        center: _g(u),
        zoom: 17.5,
        pitch: 58,
        bearing: _userHeading,
        nativeDuration: const Duration(milliseconds: 700),
      );
    }
  }

  void _goToMyLocation() {
    final u = _userLoc;
    if (u == null) return;
    if (_routePoints.isNotEmpty) {
      _fitRoute();
    } else {
      _map?.animateCamera(center: _g(u), zoom: 16);
    }
  }

  // ── Live progress / steps ─────────────────────────────────────────────────

  void _updateNavProgress() {
    if (_steps.isEmpty || _userLoc == null || _total <= 0) return;
    _remainingM = (_total - _distAlong).clamp(0, _total);

    // Arrival — near the end of the route or close to the destination point.
    final toDest = haversineMeters(_userLoc!, _dest);
    if (!_arrived && (_remainingM < 25 || toDest < 30)) {
      HapticFeedback.heavyImpact();
      setState(() {
        _arrived = true;
        _following = false;
        _currentStepIndex = _steps.length - 1;
      });
      return;
    }

    // Advance the active step by distance travelled along the route.
    double cumulative = 0;
    int newStep = _steps.length - 1;
    for (var i = 0; i < _steps.length; i++) {
      cumulative += _steps[i].distanceM;
      if (_distAlong < cumulative) {
        newStep = i;
        break;
      }
    }
    if (newStep != _currentStepIndex) HapticFeedback.lightImpact();
    setState(() => _currentStepIndex = newStep);
  }

  void _maybeReroute(double offRoute) {
    final now = DateTime.now();
    if (offRoute > 50 && now.difference(_lastReroute).inSeconds > 8) {
      _lastReroute = now;
      HapticFeedback.lightImpact();
      setState(() => _rerouting = true);
      _fetchRoute(reroute: true);
    }
  }

  // ── Step parsing ────────────────────────────────────────────────────────────

  List<RouteStep> _parseSteps(Map<String, dynamic> route) {
    final steps = <RouteStep>[];
    final legs = route['legs'] as List? ?? [];
    for (final leg in legs) {
      final legSteps = (leg as Map<String, dynamic>)['steps'] as List? ?? [];
      for (final s in legSteps) {
        final step = s as Map<String, dynamic>;
        final maneuver = step['maneuver'] as Map<String, dynamic>;
        final type = (maneuver['type'] as String?) ?? '';
        final modifier = maneuver['modifier'] as String?;
        final name = ((step['name'] as String?) ?? '').trim();
        final distance = (step['distance'] as num?)?.toDouble() ?? 0;
        if (distance < 1 && type == 'arrive') {
          steps.add(RouteStep(instruction: 'Arrive at ${widget.destName}', distanceM: 0, maneuverType: 'arrive', modifier: modifier));
        } else {
          steps.add(RouteStep(instruction: _buildInstruction(type, modifier, name), distanceM: distance, maneuverType: type, modifier: modifier));
        }
      }
    }
    return steps;
  }

  String _buildInstruction(String type, String? modifier, String name) {
    final street = name.isNotEmpty ? ' onto $name' : '';
    switch (type) {
      case 'depart':
        return name.isNotEmpty ? 'Head towards $name' : 'Start';
      case 'arrive':
        return 'Arrive at ${widget.destName}';
      case 'turn':
        switch (modifier) {
          case 'left': return 'Turn left$street';
          case 'right': return 'Turn right$street';
          case 'slight left': return 'Turn slightly left$street';
          case 'slight right': return 'Turn slightly right$street';
          case 'sharp left': return 'Turn sharp left$street';
          case 'sharp right': return 'Turn sharp right$street';
          case 'uturn': return 'Make a U-turn$street';
          default: return 'Continue$street';
        }
      case 'new name': return 'Continue$street';
      case 'merge': return 'Merge${modifier != null ? " $modifier" : ""}$street';
      case 'fork':
        return modifier == 'left' ? 'Keep left$street' : modifier == 'right' ? 'Keep right$street' : 'Fork$street';
      case 'roundabout': return 'Enter the roundabout$street';
      case 'exit roundabout': return 'Exit the roundabout$street';
      case 'rotary': return 'Enter the rotary$street';
      case 'exit rotary': return 'Exit the rotary$street';
      case 'end of road':
        return modifier == 'left' ? 'Turn left at the end$street' : 'Turn right at the end$street';
      default:
        return name.isNotEmpty ? 'Continue onto $name' : 'Continue';
    }
  }

  IconData _maneuverIcon(String type, String? modifier) {
    switch (type) {
      case 'depart': return Icons.navigation_rounded;
      case 'arrive': return Icons.flag_rounded;
      case 'roundabout':
      case 'rotary':
      case 'exit roundabout':
      case 'exit rotary': return Icons.roundabout_right_rounded;
      case 'fork':
        return modifier == 'left' ? Icons.fork_left_rounded : Icons.fork_right_rounded;
      default:
        switch (modifier) {
          case 'left': return Icons.turn_left_rounded;
          case 'right': return Icons.turn_right_rounded;
          case 'slight left': return Icons.turn_slight_left_rounded;
          case 'slight right': return Icons.turn_slight_right_rounded;
          case 'sharp left': return Icons.turn_left_rounded;
          case 'sharp right': return Icons.turn_right_rounded;
          case 'uturn': return Icons.u_turn_left_rounded;
          default: return Icons.straight_rounded;
        }
    }
  }

  // ── Display helpers ───────────────────────────────────────────────────────

  /// Estimated seconds remaining. Built from the route's average speed scaled
  /// by a per-mode congestion factor (free-flow OSRM times read optimistic, so
  /// driving is padded most). Recomputed every GPS fix from progress along the
  /// route — not a static distance/speed number.
  double get _remainingSec {
    if (_durationMin == null || _total <= 0) return 0;
    final avgMps = _total / (_durationMin! * 60); // route average speed (m/s)
    final factor = _profile == 'driving'
        ? 1.25
        : _profile == 'cycling'
            ? 1.1
            : 1.05;
    final dist = _navigating ? _remainingM : _total;
    return dist / (avgMps > 0 ? avgMps : 5) * factor;
  }

  String get _eta {
    if (_durationMin == null) return '—';
    final mins = (_remainingSec / 60).round();
    if (mins < 1) return '<1 min';
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60}h ${mins % 60}m';
  }

  /// Clock time of arrival, e.g. "14:32".
  String get _arrivalClock {
    final t = DateTime.now().add(Duration(seconds: _remainingSec.round()));
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String get _dist {
    final km = _navigating ? _remainingM / 1000.0 : (_distanceKm ?? 0);
    if (_distanceKm == null) return '—';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  String _estimateCost() {
    if (_distanceKm == null) return '—';
    final cost = _profile == 'driving' ? math.max(20.0, _distanceKm! * 8) : 0.0;
    return cost == 0 ? 'Free' : 'GHS ${cost.round()}';
  }

  static String _stepDist(double meters) {
    if (meters < 50) return 'Now';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final hasSteps = _steps.isNotEmpty && !_loading;
    final currentStep = hasSteps ? _steps[_currentStepIndex] : null;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(children: [
        MapLibreMap(
          options: MapOptions(
            initStyle: _styleUrl,
            initCenter: _g(_userLoc ?? _dest),
            initZoom: 13,
            maxPitch: 60,
          ),
          onMapCreated: (c) => _map = c,
          onStyleLoaded: _onStyleLoaded,
          onEvent: _onEvent,
          children: const [SourceAttribution()],
        ),

        // Navigation turn banner (top) — only while actively navigating.
        if (_navigating && !_arrived && currentStep != null)
          Positioned(
            top: topPad + 10,
            left: 12,
            right: 12,
            child: _NavTurnBanner(
              step: currentStep,
              icon: _maneuverIcon(currentStep.maneuverType, currentStep.modifier),
              stepDist: _stepDist(currentStep.distanceM),
              onExit: _exitNavigation,
            ),
          ),

        // Rerouting / GPS-lost status pill (below the turn banner).
        if (_navigating && !_arrived && (_rerouting || _gpsLost))
          Positioned(
            top: topPad + (currentStep != null ? 96 : 12),
            left: 0,
            right: 0,
            child: Center(
              child: _gpsLost
                  ? _statusPill('Searching for GPS…', Icons.gps_off_rounded)
                  : _statusPill('Rerouting…', Icons.alt_route_rounded),
            ),
          ),

        // Planning header (top) — only while planning.
        if (!_navigating)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                _circleBtn(Icons.arrow_back_rounded, AppColors.white, () => Navigator.pop(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: glass(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('TO', style: TextStyle(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text(widget.destName, style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _circleBtn(Icons.my_location_rounded, AppColors.yellow, _goToMyLocation),
              ]),
            ),
          ),

        // Recenter pill (navigating + user panned away).
        if (_navigating && !_following)
          Positioned(
            bottom: 150,
            left: 0,
            right: 0,
            child: Center(child: _recenterPill()),
          ),

        // Bottom panel: planning vs navigating, with a slide transition.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, anim) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(anim),
            child: child,
          ),
          child: _arrived
              ? const SizedBox.shrink()
              : (_navigating ? _navHud() : _planningPanel()),
        ),

        // Arrival overlay.
        if (_arrived) _arrivalCard(),
      ]),
    );
  }

  Widget _statusPill(String text, IconData icon) => glass(
        radius: 22,
        alpha: 0.85,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppColors.yellow, size: 16),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: AppColors.yellow, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Widget _arrivalCard() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.navyCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.flag_rounded, color: AppColors.green, size: 28),
              ),
              const SizedBox(height: 12),
              Text("You've arrived", style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(widget.destName, textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).maybePop();
                  },
                  child: const Text('DONE'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _onEvent(MapEvent event) {
    // Drop follow when the user drags during navigation.
    if (event is MapEventStartMoveCamera &&
        event.reason == CameraChangeReason.apiGesture &&
        _navigating &&
        _following) {
      setState(() => _following = false);
    }
  }

  Widget _circleBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _recenterPill() {
    return GestureDetector(
      onTap: _recenter,
      child: glass(
        radius: 24,
        alpha: 0.7,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.navigation_rounded, color: AppColors.yellow, size: 16),
            SizedBox(width: 6),
            Text('Re-center', style: TextStyle(color: AppColors.yellow, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  // ── Navigating HUD (minimal, Tesla-style) ─────────────────────────────────

  Widget _navHud() {
    return Align(
      key: const ValueKey('nav'),
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.navyCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_eta, style: TextStyle(color: AppColors.yellow, fontSize: 22, fontWeight: FontWeight.w800)),
                Text('arrive $_arrivalClock', style: TextStyle(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ]),
              const SizedBox(width: 18),
              Container(width: 1, height: 34, color: AppColors.cardBorder),
              const SizedBox(width: 18),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_dist, style: TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text('remaining', style: TextStyle(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: _exitNavigation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.red.withValues(alpha: 0.5))),
                  child: Text('EXIT', style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Planning panel ────────────────────────────────────────────────────────

  Widget _planningPanel() {
    return Align(
      key: const ValueKey('planning'),
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: AppColors.cardBorder),
            left: BorderSide(color: AppColors.cardBorder),
            right: BorderSide(color: AppColors.cardBorder),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                _ModeChip(icon: Icons.directions_car_rounded, label: 'Drive', active: _profile == 'driving', onTap: () => _switchProfile('driving')),
                _ModeChip(icon: Icons.directions_bike_rounded, label: 'Bike', active: _profile == 'cycling', onTap: () => _switchProfile('cycling')),
                _ModeChip(icon: Icons.directions_walk_rounded, label: 'Walk', active: _profile == 'foot', onTap: () => _switchProfile('foot')),
              ]),
              const SizedBox(height: 18),
              if (_loading) ...[
                const CircularProgressIndicator(color: AppColors.yellow),
                const SizedBox(height: 14),
                Text('Calculating route...', style: TextStyle(color: AppColors.grey)),
              ] else if (_error != null) ...[
                const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 32),
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: AppColors.greyLight, fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ElevatedButton(onPressed: _retry, child: const Text('RETRY')),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () async {
                      // Not supported on web (throws) — guard it.
                      try {
                        await Geolocator.openLocationSettings();
                      } catch (_) {
                        try {
                          await Geolocator.openAppSettings();
                        } catch (_) {/* web: no-op */}
                      }
                    },
                    child: Text('LOCATION SETTINGS', style: TextStyle(color: AppColors.yellow, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ]),
              ] else ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _Stat(icon: Icons.timer_outlined, label: 'TIME', value: _eta, color: AppColors.yellow),
                  Container(width: 1, height: 40, color: AppColors.cardBorder),
                  _Stat(icon: Icons.route_outlined, label: 'DISTANCE', value: _dist, color: AppColors.yellow),
                  Container(width: 1, height: 40, color: AppColors.cardBorder),
                  _Stat(icon: Icons.attach_money_rounded, label: 'EST. COST', value: _estimateCost(), color: const Color(0xFF66BB6A)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  if (_steps.isNotEmpty) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: _showStepsSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.list_alt_rounded, color: AppColors.yellow, size: 18),
                            const SizedBox(height: 4),
                            Text('${_steps.length} STEPS', style: const TextStyle(color: AppColors.yellow, fontSize: 10, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: _startNavigation,
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text('START NAVIGATION'),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  // ── Steps sheet ─────────────────────────────────────────────────────────────

  void _showStepsSheet() {
    if (_steps.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              const Icon(Icons.list_alt_rounded, color: AppColors.yellow, size: 20),
              const SizedBox(width: 10),
              Text('Turn-by-Turn Directions', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${_steps.length} steps', style: TextStyle(color: AppColors.grey, fontSize: 12)),
            ]),
          ),
          Divider(color: AppColors.cardBorder, height: 1),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: _steps.length,
              itemBuilder: (_, i) => _StepRow(
                step: _steps[i],
                index: i,
                total: _steps.length,
                isCurrent: i == _currentStepIndex,
                isDone: i < _currentStepIndex,
                icon: _maneuverIcon(_steps[i].maneuverType, _steps[i].modifier),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

/// The big top banner during navigation — the next maneuver, Google-style.
class _NavTurnBanner extends StatelessWidget {
  final RouteStep step;
  final IconData icon;
  final String stepDist;
  final VoidCallback onExit;

  const _NavTurnBanner({required this.step, required this.icon, required this.stepDist, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final isArrive = step.maneuverType == 'arrive';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: Container(
        key: ValueKey(step.instruction),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isArrive ? AppColors.green.withValues(alpha: 0.97) : AppColors.navy.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isArrive ? AppColors.green : AppColors.yellow.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: isArrive ? Colors.white.withValues(alpha: 0.2) : AppColors.yellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: isArrive ? Colors.white : AppColors.yellow, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (!isArrive && step.distanceM > 0)
                Text(stepDist, style: TextStyle(color: isArrive ? Colors.white : AppColors.yellow, fontSize: 13, fontWeight: FontWeight.w800)),
              Text(step.instruction, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, height: 1.25), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final RouteStep step;
  final int index;
  final int total;
  final bool isCurrent;
  final bool isDone;
  final IconData icon;

  const _StepRow({required this.step, required this.index, required this.total, required this.isCurrent, required this.isDone, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return Container(
      color: isCurrent ? AppColors.yellow.withValues(alpha: 0.08) : Colors.transparent,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 56,
          child: Column(children: [
            const SizedBox(height: 16),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCurrent ? AppColors.yellow : isDone ? AppColors.cardBorder : AppColors.navyCard,
                shape: BoxShape.circle,
                border: Border.all(color: isCurrent ? AppColors.yellow : AppColors.cardBorder, width: 1.5),
              ),
              child: Icon(icon, size: 16, color: isCurrent ? AppColors.navy : isDone ? AppColors.grey : AppColors.greyLight),
            ),
            if (!isLast) Container(width: 2, height: 32, color: AppColors.cardBorder),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 18, 16, 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(
                  step.instruction,
                  style: TextStyle(
                    color: isCurrent ? AppColors.white : isDone ? AppColors.grey : AppColors.greyLight,
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                    height: 1.4,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.grey,
                  ),
                ),
              ),
              if (step.distanceM > 0) ...[
                const SizedBox(width: 10),
                Text(_DirectionsScreenState._stepDist(step.distanceM), style: TextStyle(color: isCurrent ? AppColors.yellow : AppColors.grey, fontSize: 12, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeChip({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.yellow : AppColors.navyCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? AppColors.yellow : AppColors.cardBorder),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: active ? AppColors.navy : AppColors.grey, size: 18),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: active ? AppColors.navy : AppColors.grey, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _Stat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
    ]);
  }
}
