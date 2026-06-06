import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
// geobase (re-exported by maplibre) also defines `Position`, which clashes with
// geolocator's `Position`. Hide it — we use `Geographic` for map coordinates.
import 'package:maplibre/maplibre.dart' hide Position;

import '../../shared/theme/app_theme.dart';
import '../../core/models.dart';
import '../../core/supabase_service.dart';
import '../../core/routing_service.dart';
import '../../core/geo/geo_math.dart';
import '../../shared/widgets/app_image.dart';
import '../directions/directions_screen.dart';
// Reuse the existing design helpers so the two map screens stay visually
// identical during the migration.
import 'map_screen.dart' show categoryColor, categoryIcon, glass;

/// ─────────────────────────────────────────────────────────────────────────
/// MapLibre (vector + 3D) version of the map screen.
///
/// Runs in parallel with the legacy flutter_map [MapScreen] during the engine
/// migration. Vector tiles come from OpenFreeMap (free, no API key); the
/// `liberty` style ships 3D building extrusion so tilting the camera makes the
/// city rise. Markers are native vector layers (fast, with built-in collision)
/// and the rich selected-place card stays a Flutter overlay.
/// ─────────────────────────────────────────────────────────────────────────
class Map3DScreen extends StatefulWidget {
  const Map3DScreen({super.key});

  @override
  State<Map3DScreen> createState() => _Map3DScreenState();
}

class _Map3DScreenState extends State<Map3DScreen> {
  // Vector style with 3D buildings, free + keyless.
  static const _styleUrl = 'https://tiles.openfreemap.org/styles/liberty';
  static const _accra = Geographic(lon: -0.1870, lat: 5.6037);

  static const _placesSrc = 'w2g-places';
  static const _placesCircle = 'w2g-places-circle';
  static const _placesIcon = 'w2g-places-icon';
  static const _alertSrc = 'w2g-alerts';
  static const _alertFill = 'w2g-alerts-fill';
  static const _alertCircle = 'w2g-alerts-circle';
  static const _emptyFc = '{"type":"FeatureCollection","features":[]}';

  static const double _minZoom = 3;
  static const double _maxZoom = 19;
  static const double _tiltPitch = 55;

  MapController? _map;
  StyleController? _style;
  bool _styleReady = false;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Place> _places = [];
  List<AlertItem> _alerts = [];
  String _filter = 'All';
  String _search = '';
  String? _selectedId;
  bool _loading = true;
  String? _error;

  ll.LatLng? _userLoc;
  StreamSubscription<Position>? _locSub;
  bool _locating = false;
  bool _pendingRecenter = false;
  bool _follow = false;
  bool _is3D = false;

  Geographic? _loadAnchor;
  bool _showSearchArea = false;
  double _mapWidth = 360;

  // Routed ETA for the selected card.
  String? _etaPlaceId;
  bool _etaLoading = false;
  ({int walkMin, int driveMin})? _eta;

  static const List<({String label, String value})> _categories = [
    (label: 'All', value: 'All'),
    (label: 'University', value: 'university'),
    (label: 'Hostel', value: 'hostel'),
    (label: 'Hotel', value: 'hotel'),
    (label: 'Restaurant', value: 'restaurant'),
    (label: 'Cafe', value: 'cafe'),
    (label: 'Transport', value: 'transport'),
    (label: 'Market', value: 'market'),
    (label: 'Mall', value: 'mall'),
    (label: 'Nightlife', value: 'nightlife'),
    (label: 'Tourist', value: 'tourist'),
    (label: 'Hospital', value: 'hospital'),
    (label: 'Mosque', value: 'mosque'),
    (label: 'Church', value: 'church'),
  ];

  Place? get _selectedPlace {
    for (final p in _places) {
      if (p.id == _selectedId) return p;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _startLocationStream();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _locSub?.cancel();
    super.dispose();
  }

  // ── Geometry helpers ──────────────────────────────────────────────────────

  Geographic _geo(double lat, double lng) => Geographic(lon: lng, lat: lat);

  String _hex(Color c) {
    final v = c.toARGB32() & 0xFFFFFF;
    return '#${v.toRadixString(16).padLeft(6, '0')}';
  }

  /// A closed polygon ring approximating a geodesic circle, so danger zones
  /// scale with real metres instead of screen pixels.
  List<List<double>> _ring(double lat, double lng, double radiusM) {
    const n = 48;
    final latR = lat * math.pi / 180;
    final dLat = radiusM / 111320.0;
    final dLng = radiusM / (111320.0 * math.cos(latR));
    return [
      for (var i = 0; i <= n; i++)
        [
          lng + dLng * math.cos(2 * math.pi * i / n),
          lat + dLat * math.sin(2 * math.pi * i / n),
        ],
    ];
  }

  // ── GeoJSON builders ──────────────────────────────────────────────────────

  String _placesGeoJson() {
    final features = [
      for (final p in _places)
        {
          'type': 'Feature',
          'properties': {
            'id': p.id,
            'kind': 'place',
            'name': p.name,
            'category': p.category,
            'color': _hex(categoryColor(p.category)),
            'icon': 'cat-${p.category.toLowerCase()}',
            'sel': p.id == _selectedId ? 1 : 0,
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [p.lng, p.lat],
          },
        },
    ];
    return jsonEncode({'type': 'FeatureCollection', 'features': features});
  }

  String _alertsGeoJson() {
    final fills = <Map<String, Object?>>[];
    final points = <Map<String, Object?>>[];
    for (final a in _alerts) {
      if (!a.isMappable) continue;
      final color = _hex(_severityColor(a.severity));
      fills.add({
        'type': 'Feature',
        'properties': {'color': color},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [_ring(a.lat!, a.lng!, a.radiusMeters)],
        },
      });
      points.add({
        'type': 'Feature',
        'properties': {'id': a.id, 'kind': 'alert', 'color': color},
        'geometry': {
          'type': 'Point',
          'coordinates': [a.lng!, a.lat!],
        },
      });
    }
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [...fills, ...points],
    });
  }

  // ── Style setup ───────────────────────────────────────────────────────────

  Future<void> _onStyleLoaded(StyleController style) async {
    _style = style;

    // Register a white glyph image per category for the marker icon layer.
    final cats = {for (final p in _places) p.category.toLowerCase()};
    cats.addAll(_categories.map((c) => c.value.toLowerCase()));
    for (final c in cats) {
      if (c == 'all') continue;
      try {
        await style.addImageFromIconData(
          id: 'cat-$c',
          iconData: categoryIcon(c),
          size: 120,
          color: Colors.white,
        );
      } catch (_) {/* ignore individual icon failures */}
    }

    await style.addSource(const GeoJsonSource(id: _placesSrc, data: _emptyFc));
    await style.addSource(const GeoJsonSource(id: _alertSrc, data: _emptyFc));

    // Danger-zone fills (drawn first, beneath everything).
    await style.addLayer(const FillStyleLayer(
      id: _alertFill,
      sourceId: _alertSrc,
      paint: {
        'fill-color': ['get', 'color'],
        'fill-opacity': 0.12,
        'fill-outline-color': ['get', 'color'],
      },
    ));
    // Alert markers. A circle layer only renders Point geometries, so it
    // naturally ignores the danger-zone polygons in the same source.
    await style.addLayer(const CircleStyleLayer(
      id: _alertCircle,
      sourceId: _alertSrc,
      paint: {
        'circle-radius': 7,
        'circle-color': ['get', 'color'],
        'circle-stroke-color': '#FFFFFF',
        'circle-stroke-width': 2,
      },
    ));
    // Place dots (colored circle with white outline).
    await style.addLayer(const CircleStyleLayer(
      id: _placesCircle,
      sourceId: _placesSrc,
      paint: {
        'circle-color': ['get', 'color'],
        'circle-radius': [
          'case',
          ['==', ['get', 'sel'], 1],
          16.0,
          11.0,
        ],
        'circle-stroke-color': '#FFFFFF',
        'circle-stroke-width': [
          'case',
          ['==', ['get', 'sel'], 1],
          3.0,
          2.0,
        ],
      },
    ));
    // White category glyph centered on each dot.
    await style.addLayer(const SymbolStyleLayer(
      id: _placesIcon,
      sourceId: _placesSrc,
      layout: {
        'icon-image': ['get', 'icon'],
        'icon-size': [
          'case',
          ['==', ['get', 'sel'], 1],
          0.24,
          0.16,
        ],
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
      },
    ));

    _styleReady = true;
    // Show the native pulsing GPS dot if permission allows.
    try {
      await _map?.enableLocation();
    } catch (_) {/* optional */}

    await _load();
  }

  Future<void> _pushSources() async {
    if (!_styleReady) return;
    try {
      await _style?.updateGeoJsonSource(id: _placesSrc, data: _placesGeoJson());
      await _style?.updateGeoJsonSource(id: _alertSrc, data: _alertsGeoJson());
    } catch (_) {/* style may be reloading */}
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _load({bool focusNearest = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SupabaseService.instance.getPlaces(
          category: _filter == 'All' ? null : _filter,
          search: _search.trim().isEmpty ? null : _search.trim(),
          limit: 200,
        ),
        SupabaseService.instance.getActiveAlerts(),
      ]);
      if (!mounted) return;
      final places = results[0] as List<Place>;
      final alerts = results[1] as List<AlertItem>;
      setState(() {
        _places = places;
        _alerts = alerts;
        _loading = false;
        _showSearchArea = false;
        if (_selectedId != null && !places.any((p) => p.id == _selectedId)) {
          _selectedId = null;
        }
      });
      _loadAnchor = _map?.camera?.center;
      await _registerMissingIcons(places);
      await _pushSources();

      if (places.isEmpty) return;
      if (_search.trim().isNotEmpty && !_follow) {
        _fitToPlaces(places);
      } else if (focusNearest && _filter != 'All') {
        _focusNearestTo(places);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Categories can arrive that weren't pre-registered (defensive).
  Future<void> _registerMissingIcons(List<Place> places) async {
    final style = _style;
    if (style == null) return;
    for (final c in {for (final p in places) p.category.toLowerCase()}) {
      try {
        await style.addImageFromIconData(
          id: 'cat-$c',
          iconData: categoryIcon(c),
          size: 120,
          color: Colors.white,
        );
      } catch (_) {/* already added or failed — ignore */}
    }
  }

  Future<void> _searchThisArea() async {
    HapticFeedback.selectionClick();
    final cam = _map?.camera;
    if (cam == null) return;
    final center = cam.center;
    final radius = _viewportRadiusMeters(cam.zoom).round().clamp(500, 50000);
    setState(() {
      _loading = true;
      _showSearchArea = false;
    });
    try {
      final results = await Future.wait([
        SupabaseService.instance.getNearbyPlaces(
          lat: center.lat,
          lng: center.lon,
          radiusM: radius,
          category: _filter == 'All' ? null : _filter,
        ),
        SupabaseService.instance.getActiveAlerts(),
      ]);
      if (!mounted) return;
      setState(() {
        _places = results[0] as List<Place>;
        _alerts = results[1] as List<AlertItem>;
        _loading = false;
      });
      _loadAnchor = center;
      await _registerMissingIcons(_places);
      await _pushSources();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search = value;
      _load();
    });
  }

  // ── Camera ──────────────────────────────────────────────────────────────

  void _focusNearestTo(List<Place> places) {
    final ref = _userLoc ??
        (_map?.camera == null
            ? ll.LatLng(_accra.lat, _accra.lon)
            : ll.LatLng(_map!.camera!.center.lat, _map!.camera!.center.lon));
    Place? nearest;
    var best = double.infinity;
    for (final p in places) {
      final d = haversineMeters(ref, ll.LatLng(p.lat, p.lng));
      if (d < best) {
        best = d;
        nearest = p;
      }
    }
    if (nearest == null) {
      _fitToPlaces(places);
      return;
    }
    _follow = false;
    _selectPlace(nearest.id);
    _map?.animateCamera(
      center: _geo(nearest.lat, nearest.lng),
      zoom: 16,
      pitch: _is3D ? _tiltPitch : 0,
      nativeDuration: const Duration(milliseconds: 800),
    );
  }

  void _fitToPlaces(List<Place> places) {
    if (places.isEmpty) return;
    if (places.length == 1) {
      _map?.animateCamera(
        center: _geo(places.first.lat, places.first.lng),
        zoom: 15,
        nativeDuration: const Duration(milliseconds: 800),
      );
      return;
    }
    var west = 180.0, east = -180.0, south = 90.0, north = -90.0;
    for (final p in places) {
      west = math.min(west, p.lng);
      east = math.max(east, p.lng);
      south = math.min(south, p.lat);
      north = math.max(north, p.lat);
    }
    _map?.fitBounds(
      bounds: LngLatBounds(
        longitudeWest: west,
        longitudeEast: east,
        latitudeSouth: south,
        latitudeNorth: north,
      ),
      padding: const EdgeInsets.all(80),
      nativeDuration: const Duration(milliseconds: 800),
    );
  }

  void _zoomBy(double delta) {
    final cam = _map?.camera;
    if (cam == null) return;
    _map?.animateCamera(
      zoom: (cam.zoom + delta).clamp(_minZoom, _maxZoom),
      nativeDuration: const Duration(milliseconds: 250),
    );
  }

  void _toggle3D() {
    HapticFeedback.selectionClick();
    setState(() => _is3D = !_is3D);
    _map?.animateCamera(
      pitch: _is3D ? _tiltPitch : 0,
      bearing: _is3D ? _map?.camera?.bearing ?? 0 : 0,
      nativeDuration: const Duration(milliseconds: 700),
    );
  }

  double _viewportRadiusMeters(double zoom) {
    final mpp = _map?.getMetersPerPixelAtLatitude(
          _map?.camera?.center.lat ?? _accra.lat,
        ) ??
        50;
    return mpp * (_mapWidth / 2);
  }

  // ── Selection + ETA ───────────────────────────────────────────────────────

  void _selectPlace(String id) {
    HapticFeedback.selectionClick();
    setState(() => _selectedId = id);
    _pushSources();
    final place = _selectedPlace;
    if (place != null) _fetchEta(place);
  }

  void _clearSelection() {
    if (_selectedId == null) return;
    setState(() {
      _selectedId = null;
      _etaPlaceId = null;
      _eta = null;
      _etaLoading = false;
    });
    _pushSources();
  }

  Future<void> _fetchEta(Place p) async {
    final ref = _userLoc;
    if (ref == null) {
      setState(() {
        _etaPlaceId = p.id;
        _eta = null;
        _etaLoading = false;
      });
      return;
    }
    setState(() {
      _etaPlaceId = p.id;
      _eta = null;
      _etaLoading = true;
    });
    final to = ll.LatLng(p.lat, p.lng);
    final results = await Future.wait([
      RoutingService.summary(from: ref, to: to, profile: 'foot'),
      RoutingService.summary(from: ref, to: to, profile: 'driving'),
    ]);
    if (!mounted || _selectedId != p.id) return;
    final walk = results[0];
    final drive = results[1];
    setState(() {
      _etaLoading = false;
      _eta = (walk != null && drive != null)
          ? (walkMin: walk.minutes, driveMin: drive.minutes)
          : null;
    });
  }

  String _fmtMin(int m) => m < 60 ? '$m min' : '${m ~/ 60}h ${m % 60}m';

  String _formatDistance(double meters) =>
      meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _startLocationStream() async {
    if (_locSub != null || _locating) return;
    _locating = true;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      try {
        final cur = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) {
          setState(() {
            _userLoc = ll.LatLng(cur.latitude, cur.longitude);
          });
          if (_pendingRecenter) {
            _pendingRecenter = false;
            _follow = true;
            _map?.animateCamera(
              center: _geo(cur.latitude, cur.longitude),
              zoom: 16,
              nativeDuration: const Duration(milliseconds: 800),
            );
          }
        }
      } catch (_) {/* fall through to stream */}

      _locSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() {
          _userLoc = ll.LatLng(pos.latitude, pos.longitude);
        });
        if (_pendingRecenter) {
          _pendingRecenter = false;
          _follow = true;
          _map?.animateCamera(
            center: _geo(pos.latitude, pos.longitude),
            zoom: 16,
            nativeDuration: const Duration(milliseconds: 800),
          );
        } else if (_follow) {
          _map?.animateCamera(
            center: _geo(pos.latitude, pos.longitude),
            nativeDuration: const Duration(milliseconds: 700),
          );
        }
      });
    } catch (_) {
      // Location optional.
    } finally {
      _locating = false;
    }
  }

  void _onLocatePressed() {
    HapticFeedback.selectionClick();
    if (_userLoc != null) {
      setState(() => _follow = true);
      _map?.animateCamera(
        center: _geo(_userLoc!.latitude, _userLoc!.longitude),
        zoom: 16,
        nativeDuration: const Duration(milliseconds: 700),
      );
    } else {
      _pendingRecenter = true;
      _startLocationStream();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Finding your location…'),
        duration: Duration(seconds: 2),
      ));
    }
  }

  // ── Map events ─────────────────────────────────────────────────────────────

  void _onEvent(MapEvent event) {
    switch (event) {
      case MapEventStartMoveCamera(:final reason):
        if (_follow && reason == CameraChangeReason.apiGesture) {
          setState(() => _follow = false);
        }
      case MapEventMoveCamera(:final camera):
        _maybeShowSearchArea(camera);
      case MapEventClick(:final screenPoint):
        _handleTap(screenPoint);
      default:
        break;
    }
  }

  void _maybeShowSearchArea(MapCamera camera) {
    final anchor = _loadAnchor;
    if (anchor == null || _loading) return;
    final moved = haversineMeters(
          ll.LatLng(anchor.lat, anchor.lon),
          ll.LatLng(camera.center.lat, camera.center.lon),
        ) >
        _viewportRadiusMeters(camera.zoom) * 0.6;
    if (moved != _showSearchArea) {
      setState(() => _showSearchArea = moved);
    }
  }

  void _handleTap(Offset screenPoint) {
    final feats = _map?.featuresAtPoint(
          screenPoint,
          layerIds: [_placesCircle, _placesIcon, _alertCircle],
        ) ??
        const <RenderedFeature>[];
    if (feats.isEmpty) {
      _clearSelection();
      return;
    }
    final props = feats.first.properties;
    if (props['kind'] == 'alert') {
      final id = props['id'];
      final alert = _alerts.where((a) => a.id == id).firstOrNull;
      if (alert != null) _showAlertDetails(alert);
      return;
    }
    final id = props['id'];
    if (id is String) _selectPlace(id);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: LayoutBuilder(builder: (context, constraints) {
        _mapWidth = constraints.maxWidth;
        final selected = _selectedPlace;
        return Stack(children: [
          MapLibreMap(
            options: const MapOptions(
              initStyle: _styleUrl,
              initCenter: _accra,
              initZoom: 13,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              maxPitch: 60,
            ),
            onMapCreated: (c) => _map = c,
            onStyleLoaded: _onStyleLoaded,
            onEvent: _onEvent,
            children: const [
              SourceAttribution(),
            ],
          ),
          _topScrim(),
          if (selected != null) _bottomScrim(),
          _buildTopControls(),
          _buildSideControls(selected != null),
          if (selected != null) _buildPlaceCard(selected),
        ]);
      }),
    );
  }

  Widget _buildTopControls() {
    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(
              child: glass(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: AppColors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search a place or district...',
                    hintStyle: TextStyle(color: AppColors.grey, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: AppColors.grey, size: 18),
                    suffixIcon: _search.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              _search = '';
                              _load();
                            },
                            child: Icon(Icons.close, color: AppColors.grey, size: 18),
                          )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _onLocatePressed,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _follow ? AppColors.yellow : AppColors.navy.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _follow ? AppColors.yellow : AppColors.cardBorder),
                  boxShadow: _follow
                      ? [BoxShadow(color: AppColors.yellow.withValues(alpha: 0.4), blurRadius: 12)]
                      : const [],
                ),
                child: Icon(
                  _follow ? Icons.my_location_rounded : Icons.location_searching_rounded,
                  color: _follow ? AppColors.navy : AppColors.yellow,
                  size: 20,
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _categories.map((c) {
              final active = c.value == _filter;
              return GestureDetector(
                onTap: () {
                  setState(() => _filter = c.value);
                  _load(focusNearest: c.value != 'All');
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.yellow : AppColors.navy.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: active ? AppColors.yellow : AppColors.cardBorder),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(categoryIcon(c.value), size: 14, color: active ? AppColors.navy : AppColors.grey),
                    const SizedBox(width: 5),
                    Text(c.label, style: TextStyle(color: active ? AppColors.navy : AppColors.grey, fontWeight: FontWeight.w600, fontSize: 12)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _statusPill(),
            if (_error != null) ...[
              const SizedBox(height: 8),
              _errorBanner(),
            ],
            if (_showSearchArea && !_loading) ...[
              const SizedBox(height: 10),
              Center(child: _searchAreaPill()),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _statusPill() {
    final alertCount = _alerts.where((a) => a.isMappable).length;
    return glass(
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_loading)
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.yellow))
          else
            Icon(Icons.threed_rotation_rounded, color: AppColors.yellow, size: 14),
          const SizedBox(width: 6),
          Text(_loading ? 'Loading…' : '${_places.length} place(s) · 3D map',
              style: TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          if (alertCount > 0) ...[
            const SizedBox(width: 8),
            Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.grey, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350), size: 12),
            const SizedBox(width: 4),
            Text('$alertCount alert(s)', style: const TextStyle(color: Color(0xFFEF5350), fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ]),
      ),
    );
  }

  Widget _searchAreaPill() {
    return GestureDetector(
      onTap: _searchThisArea,
      child: glass(
        radius: 22,
        alpha: 0.7,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.refresh_rounded, color: AppColors.yellow, size: 16),
            SizedBox(width: 6),
            Text('Search this area', style: TextStyle(color: AppColors.yellow, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Material(
      color: AppColors.red.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _load(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            const Text('RETRY', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  /// Right-side vertical stack: 3D toggle + zoom in/out.
  Widget _buildSideControls(bool hasCard) {
    return Positioned(
      right: 16,
      bottom: hasCard ? 230 : 110,
      child: Column(children: [
        GestureDetector(
          onTap: _toggle3D,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _is3D ? AppColors.yellow : AppColors.navy.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _is3D ? AppColors.yellow : AppColors.cardBorder),
              boxShadow: _is3D ? [BoxShadow(color: AppColors.yellow.withValues(alpha: 0.4), blurRadius: 12)] : const [],
            ),
            child: Icon(Icons.threed_rotation_rounded, color: _is3D ? AppColors.navy : AppColors.yellow, size: 22),
          ),
        ),
        const SizedBox(height: 10),
        _SquareButton(icon: Icons.add, onTap: () => _zoomBy(1)),
        const SizedBox(height: 8),
        _SquareButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
      ]),
    );
  }

  void _openDirections(Place p) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DirectionsScreen(destLat: p.lat, destLng: p.lng, destName: p.name),
    ));
  }

  Widget _buildPlaceCard(Place place) {
    final color = categoryColor(place.category);
    final meters = _userLoc == null ? null : haversineMeters(_userLoc!, ll.LatLng(place.lat, place.lng));
    final distance = meters == null ? null : _formatDistance(meters);
    final showEta = _etaPlaceId == place.id;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: () => context.push('/place/${place.id}'),
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.navyCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 5, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      AppImage(url: place.imageUrl, width: 60, height: 60, borderRadius: BorderRadius.circular(10), fallbackIcon: Icons.place),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Row(children: [
                            Icon(categoryIcon(place.category), color: color, size: 12),
                            const SizedBox(width: 4),
                            Text(place.category.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          ]),
                          const SizedBox(height: 4),
                          Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.star_rounded, color: AppColors.yellow, size: 14),
                            const SizedBox(width: 3),
                            Text(place.rating.toStringAsFixed(1), style: TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            if (place.reviewCount > 0)
                              Text(' (${place.reviewCount})', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                            if (distance != null) ...[
                              const SizedBox(width: 8),
                              Container(width: 3, height: 3, decoration: BoxDecoration(color: AppColors.grey, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Icon(Icons.near_me_rounded, color: AppColors.grey, size: 12),
                              const SizedBox(width: 3),
                              Text(distance, style: TextStyle(color: AppColors.grey, fontSize: 12)),
                            ],
                          ]),
                          if (showEta && _etaLoading) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              const SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.yellow)),
                              const SizedBox(width: 6),
                              Text('Calculating route…', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                            ]),
                          ] else if (showEta && _eta != null) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.directions_walk_rounded, color: AppColors.grey, size: 13),
                              const SizedBox(width: 3),
                              Text(_fmtMin(_eta!.walkMin), style: TextStyle(color: AppColors.greyLight, fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 12),
                              Icon(Icons.directions_car_rounded, color: AppColors.grey, size: 13),
                              const SizedBox(width: 3),
                              Text(_fmtMin(_eta!.driveMin), style: TextStyle(color: AppColors.greyLight, fontSize: 11, fontWeight: FontWeight.w600)),
                            ]),
                          ],
                          const SizedBox(height: 3),
                          Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.grey, fontSize: 11)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        GestureDetector(
                          onTap: _clearSelection,
                          child: Container(width: 26, height: 26, decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.close_rounded, color: AppColors.grey, size: 15)),
                        ),
                        GestureDetector(
                          onTap: () => _openDirections(place),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.yellow,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: AppColors.yellow.withValues(alpha: 0.4), blurRadius: 8)],
                            ),
                            child: Icon(Icons.directions_rounded, color: AppColors.navy, size: 22),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showAlertDetails(AlertItem a) {
    final color = _severityColor(a.severity);
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.warning_amber_rounded, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.severity.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 2),
                Text(a.title, style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ])),
            ]),
            const SizedBox(height: 16),
            Text(a.description, style: TextStyle(color: AppColors.greyLight, fontSize: 14, height: 1.6)),
          ]),
        ),
      ),
    );
  }

  Widget _topScrim() => Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 210,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.navy.withValues(alpha: 0.85), AppColors.navy.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ),
      );

  Widget _bottomScrim() => Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: 180,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [AppColors.navy.withValues(alpha: 0.75), AppColors.navy.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ),
      );

  Color _severityColor(String s) {
    switch (s) {
      case 'critical': return const Color(0xFFD32F2F);
      case 'high': return const Color(0xFFEF5350);
      case 'medium': return const Color(0xFFFF7043);
      default: return const Color(0xFFFFB74D);
    }
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SquareButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: glass(
        radius: 12,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, color: AppColors.white, size: 20)),
      ),
    );
  }
}
