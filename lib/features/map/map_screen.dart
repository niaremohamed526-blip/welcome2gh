import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/models.dart';
import '../../core/supabase_service.dart';
import '../../core/geo/geo_math.dart';
import '../../core/geo/marker_layout.dart';
import '../../shared/widgets/app_image.dart';
import '../../shared/widgets/user_location_dot.dart';
import 'map_state.dart';

/// Union of things that can appear as a collision-managed marker on the map.
sealed class _MapEntity {}

class _PlaceEntity extends _MapEntity {
  final Place place;
  _PlaceEntity(this.place);
}

class _AlertEntity extends _MapEntity {
  final AlertItem alert;
  _AlertEntity(this.alert);
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // Single source of truth for position, heading, viewport, data & selection.
  final _controller = MapStateController();
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  final _resolver = const MarkerCollisionResolver(padding: 4);

  Timer? _debounce;
  AnimationController? _moveCtrl; // one reusable controller — never re-created
  VoidCallback? _moveListener; // current per-animation tick callback
  StreamSubscription<Position>? _locationSub;
  bool _locating = false; // a location request is in flight
  bool _pendingRecenter = false; // user tapped "locate" before we had a fix

  static const double _minZoom = 3;
  static const double _maxZoom = 19;

  // (label shown, db enum value sent to the query). Covers the full
  // place_category set so every category is reachable from the map.
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

  @override
  void initState() {
    super.initState();
    _load();
    _startLocationStream();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _moveCtrl?.dispose();
    _locationSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────

  Future<void> _load({bool focusNearest = false}) async {
    _controller.startLoading();
    final st = _controller.state;
    try {
      final results = await Future.wait([
        SupabaseService.instance.getPlaces(
          category: st.filter == 'All' ? null : st.filter,
          search: st.search.trim().isEmpty ? null : st.search.trim(),
          limit: 200,
        ),
        SupabaseService.instance.getActiveAlerts(),
      ]);
      if (!mounted) return;
      final places = results[0] as List<Place>;
      final alerts = results[1] as List<AlertItem>;
      _controller.setData(places: places, alerts: alerts);

      if (places.isEmpty) return;
      if (st.search.trim().isNotEmpty && !_controller.state.followUser) {
        // Auto-frame search results.
        _fitToPlaces(places);
      } else if (focusNearest && st.filter != 'All') {
        // Category tapped — fly to the nearest one to the user.
        _focusNearestTo(places);
      }
    } catch (e) {
      if (!mounted) return;
      _controller.setError(e.toString());
    }
  }

  /// Fly the camera to the place closest to the user's live location (falling
  /// back to the current map centre, then to framing everything). The nearest
  /// place is also selected so its card pops up.
  void _focusNearestTo(List<Place> places) {
    final ref = _controller.state.userLocation ?? _mapController.camera.center;
    Place? nearest;
    var best = double.infinity;
    for (final p in places) {
      final d = haversineMeters(ref, LatLng(p.lat, p.lng));
      if (d < best) {
        best = d;
        nearest = p;
      }
    }
    if (nearest == null) {
      _fitToPlaces(places);
      return;
    }
    // Stop following so the GPS stream doesn't immediately pull the camera back.
    _controller.setFollow(false);
    _controller.select(nearest.id);
    _animatedMove(LatLng(nearest.lat, nearest.lng), 16);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _controller.setSearch(value);
      _load();
    });
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  /// Smoothly animate the camera. A single [AnimationController] is reused and
  /// only disposed in [dispose] — this avoids the double-dispose crash that
  /// happened when each move created and self-disposed its own controller.
  void _animatedMove(LatLng dest, double destZoom) {
    final ctrl = _moveCtrl ??=
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    final cam = _mapController.camera;
    final latT = Tween<double>(begin: cam.center.latitude, end: dest.latitude);
    final lngT = Tween<double>(begin: cam.center.longitude, end: dest.longitude);
    final zoomT = Tween<double>(
        begin: cam.zoom, end: destZoom.clamp(_minZoom, _maxZoom));

    ctrl.stop();
    if (_moveListener != null) ctrl.removeListener(_moveListener!);
    ctrl.reset();
    _moveListener = () {
      final t = Curves.easeInOutCubic.transform(ctrl.value);
      _mapController.move(
        LatLng(latT.transform(t), lngT.transform(t)),
        zoomT.transform(t),
      );
    };
    ctrl.addListener(_moveListener!);
    ctrl.forward();
  }

  void _fitToPlaces(List<Place> places) {
    final pts = places.map((p) => LatLng(p.lat, p.lng)).toList();
    if (pts.length == 1) {
      _animatedMove(pts.first, 15);
    } else {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.all(80),
      ));
    }
  }

  void _zoomBy(double delta) {
    final c = _mapController.camera;
    _mapController.move(c.center, (c.zoom + delta).clamp(_minZoom, _maxZoom));
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _startLocationStream() async {
    // Never stack subscriptions / concurrent permission requests.
    if (_locationSub != null || _locating) return;
    _locating = true;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        _controller.setLocationStatus(LocationStatus.denied);
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        _controller.setLocationStatus(LocationStatus.deniedForever);
        return;
      }

      // Last-known position is NOT supported on web and throws — guard it on
      // its own so a failure here can't abort the live stream setup below.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && mounted) {
          _controller.setUserLocation(
            LatLng(last.latitude, last.longitude),
            last.heading >= 0 ? last.heading : null,
          );
        }
      } catch (_) {/* unsupported on web — ignore */}

      // One-shot current fix: gives an immediate position and, on web, this is
      // what actually triggers the browser's location permission prompt.
      try {
        final cur = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) {
          final loc = LatLng(cur.latitude, cur.longitude);
          _controller.setUserLocation(loc, cur.heading >= 0 ? cur.heading : null);
          if (_pendingRecenter) {
            _pendingRecenter = false;
            _controller.setFollow(true);
            _animatedMove(loc, 16);
          }
        }
      } catch (_) {/* fall back to the position stream below */}

      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (!mounted) return;
        final loc = LatLng(pos.latitude, pos.longitude);
        _controller.setUserLocation(loc, pos.heading >= 0 ? pos.heading : null);

        if (_pendingRecenter) {
          // Honour the earlier "locate" tap now that we have a fix.
          _pendingRecenter = false;
          _controller.setFollow(true);
          _animatedMove(loc, 16);
        } else if (_controller.state.followUser) {
          _animatedMove(loc, _mapController.camera.zoom);
        }
      });
    } catch (_) {
      // Location is optional; ignore failures.
    } finally {
      _locating = false;
    }
  }

  void _onLocatePressed() {
    HapticFeedback.selectionClick();
    final st = _controller.state;
    if (st.userLocation != null) {
      _controller.setFollow(true);
      _animatedMove(st.userLocation!, 16);
    } else if (st.locationStatus == LocationStatus.denied ||
        st.locationStatus == LocationStatus.deniedForever) {
      _showPermissionMessage();
    } else {
      // No fix yet — remember the intent and recenter as soon as one arrives.
      _pendingRecenter = true;
      _startLocationStream();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Finding your location…'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.navyCard,
      ));
    }
  }

  void _showPermissionMessage() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Location is off. Enable it to see your position on the map.'),
      backgroundColor: AppColors.navyCard,
      action: SnackBarAction(
        label: 'SETTINGS',
        textColor: AppColors.yellow,
        onPressed: Geolocator.openAppSettings,
      ),
    ));
  }

  // ── Map events ──────────────────────────────────────────────────────────

  void _onMapEvent(MapEvent event) {
    final st = _controller.state;
    // Drop follow mode the instant the user manually drives the camera.
    if (st.followUser &&
        event.source != MapEventSource.mapController &&
        (event is MapEventMoveStart ||
            event is MapEventDoubleTapZoomStart ||
            event is MapEventScrollWheelZoom ||
            event is MapEventFlingAnimationStart)) {
      _controller.setFollow(false);
    }
    // Keep the authoritative viewport in sync with the rendered camera so the
    // marker collision layout tracks the live map.
    final cam = _mapController.camera;
    if ((cam.zoom - st.zoom).abs() > 0.001 ||
        cam.center.latitude != st.center.latitude ||
        cam.center.longitude != st.center.longitude) {
      _controller.syncCamera(cam.center, cam.zoom);
    }
  }

  // ── Marker building (uses the projection + collision resolver) ─────────────

  int _severityRank(String s) => switch (s) {
        'critical' => 4,
        'high' => 3,
        'medium' => 2,
        _ => 1,
      };

  List<Marker> _buildMarkers(MapViewState st, Size size) {
    final viewport = st.viewport(size.width, size.height);

    final specs = <MarkerSpec<_MapEntity>>[
      for (final a in st.mappableAlerts)
        MarkerSpec(
          id: 'a_${a.id}',
          point: LatLng(a.lat!, a.lng!),
          width: 34,
          height: 34,
          priority: 600 + _severityRank(a.severity),
          data: _AlertEntity(a),
        ),
      for (final p in st.places)
        MarkerSpec(
          id: 'p_${p.id}',
          point: LatLng(p.lat, p.lng),
          width: p.id == st.selectedPlaceId ? 110 : 86,
          height: p.id == st.selectedPlaceId ? 46 : 38,
          // Selected place always wins; otherwise rank by rating.
          priority: p.id == st.selectedPlaceId ? 1000 : (p.rating * 10).round(),
          data: _PlaceEntity(p),
        ),
    ];

    final kept = _resolver.resolve(specs, viewport);

    return [
      for (final spec in kept)
        switch (spec.data) {
          _AlertEntity(:final alert) => _alertMarker(alert),
          _PlaceEntity(:final place) =>
            _placeMarker(place, place.id == st.selectedPlaceId),
        },
      if (st.userLocation != null)
        Marker(
          point: st.userLocation!,
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () => _showUserLocationSheet(st),
            child: UserLocationDot(heading: st.userHeading),
          ),
        ),
    ];
  }

  Marker _alertMarker(AlertItem a) {
    final color = _severityColor(a.severity);
    return Marker(
      point: LatLng(a.lat!, a.lng!),
      width: 34,
      height: 34,
      child: GestureDetector(
        onTap: () => _showAlertDetails(a),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 2),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)],
          ),
          child: Icon(Icons.warning_amber_rounded, color: AppColors.white, size: 16),
        ),
      ),
    );
  }

  Marker _placeMarker(Place p, bool selected) {
    return Marker(
      point: LatLng(p.lat, p.lng),
      width: selected ? 110 : 86,
      height: selected ? 46 : 38,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _controller.select(p.id);
        },
        child: _MapMarker(place: p, selected: selected),
      ),
    );
  }

  // ── Bottom sheets ──────────────────────────────────────────────────────────

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
            const SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(8)),
                child: Text(a.type.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(8)),
                child: Text('~${a.radiusMeters.round()} m zone', style: TextStyle(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _showUserLocationSheet(MapViewState st) {
    if (st.userLocation == null) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.yellow.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.my_location_rounded, color: AppColors.yellow, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('YOUR LOCATION', style: TextStyle(color: AppColors.yellow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  const SizedBox(height: 5),
                  Text(
                    '${st.userLocation!.latitude.toStringAsFixed(6)},  ${st.userLocation!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(color: AppColors.greyLight, fontSize: 13),
                  ),
                  if (st.userHeading != null) ...[
                    const SizedBox(height: 4),
                    Text('Heading ${st.userHeading!.toStringAsFixed(0)}°', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                  ],
                ]),
              ),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final st = _controller.state;
              return Stack(
                children: [
                  _buildMap(st, size),
                  _buildTopControls(st),
                  _buildZoomControls(st),
                  if (st.selectedPlace != null) _buildPlaceCard(st.selectedPlace!),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMap(MapViewState st, Size size) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: st.center,
        initialZoom: st.zoom,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        onMapEvent: _onMapEvent,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.welcome2gh',
          maxNativeZoom: 19,
        ),
        // Danger zones — drawn with the real radius in metres so they scale
        // correctly with zoom.
        CircleLayer(
          circles: [
            for (final a in st.mappableAlerts)
              CircleMarker(
                point: LatLng(a.lat!, a.lng!),
                radius: a.radiusMeters,
                useRadiusInMeter: true,
                color: _severityColor(a.severity).withValues(alpha: 0.12),
                borderColor: _severityColor(a.severity).withValues(alpha: 0.55),
                borderStrokeWidth: 1.5,
              ),
          ],
        ),
        MarkerLayer(markers: _buildMarkers(st, size)),
      ],
    );
  }

  Widget _buildTopControls(MapViewState st) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search + locate + refresh
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    style: TextStyle(color: AppColors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search a place or district...',
                      hintStyle: TextStyle(color: AppColors.grey, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: AppColors.grey, size: 18),
                      suffixIcon: st.search.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                _controller.setSearch('');
                                _load();
                              },
                              child: Icon(Icons.close, color: AppColors.grey, size: 18),
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
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
                    color: st.followUser ? AppColors.yellow : AppColors.navy.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: st.followUser ? AppColors.yellow : AppColors.cardBorder),
                    boxShadow: st.followUser
                        ? [BoxShadow(color: AppColors.yellow.withValues(alpha: 0.4), blurRadius: 12)]
                        : [],
                  ),
                  child: Icon(
                    st.followUser ? Icons.my_location_rounded : Icons.location_searching_rounded,
                    color: st.followUser ? AppColors.navy : AppColors.yellow,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); _load(); },
                child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)), child: Icon(Icons.refresh_rounded, color: AppColors.grey, size: 20)),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          // Category chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _categories.map((c) {
                final active = c.value == st.filter;
                return GestureDetector(
                  onTap: () {
                    _controller.setFilter(c.value);
                    // Tapping a category flies to the nearest match; 'All' just
                    // reloads without moving the camera.
                    _load(focusNearest: c.value != 'All');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: active ? AppColors.yellow : AppColors.navy.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? AppColors.yellow : AppColors.cardBorder)),
                    child: Text(c.label, style: TextStyle(color: active ? AppColors.navy : AppColors.grey, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          // Status + follow + empty/error banners stacked vertically so they
          // never overlap each other.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statusPill(st),
                if (st.followUser) ...[
                  const SizedBox(height: 8),
                  _followBanner(),
                ],
                if (!st.loading && st.error == null && st.places.isEmpty) ...[
                  const SizedBox(height: 8),
                  _emptyBanner(st),
                ],
                if (st.error != null) ...[
                  const SizedBox(height: 8),
                  _errorBanner(st),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(MapViewState st) {
    final alertCount = st.mappableAlerts.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (st.loading)
          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.yellow))
        else
          const Icon(Icons.location_on_rounded, color: AppColors.red, size: 14),
        const SizedBox(width: 6),
        Text(st.loading ? 'Loading...' : '${st.places.length} place(s) on the map', style: TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        if (alertCount > 0) ...[
          const SizedBox(width: 8),
          Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.grey, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350), size: 12),
          const SizedBox(width: 4),
          Text('$alertCount alert(s)', style: const TextStyle(color: Color(0xFFEF5350), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }

  Widget _followBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.yellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.yellow.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.navigation_rounded, color: AppColors.yellow, size: 12),
        SizedBox(width: 5),
        Text('Following your location', style: TextStyle(color: AppColors.yellow, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _emptyBanner(MapViewState st) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        Icon(Icons.search_off_rounded, color: AppColors.grey, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(
          st.search.isNotEmpty ? 'No places match "${st.search}"' : 'No places in this category',
          style: TextStyle(color: AppColors.greyLight, fontSize: 13),
        )),
        if (st.search.isNotEmpty || st.filter != 'All')
          GestureDetector(
            onTap: () {
              _searchCtrl.clear();
              _controller.clearFilters();
              _load();
            },
            child: const Text('CLEAR', style: TextStyle(color: AppColors.yellow, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  Widget _errorBanner(MapViewState st) {
    return Material(
      color: AppColors.red.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _load,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(st.error!, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            const Text('TAP TO RETRY', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _buildZoomControls(MapViewState st) {
    return Positioned(
      right: 16,
      bottom: st.selectedPlace != null ? 230 : 110,
      child: Column(children: [
        _ZoomButton(icon: Icons.add, onTap: () => _zoomBy(1)),
        const SizedBox(height: 8),
        _ZoomButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
      ]),
    );
  }

  Widget _buildPlaceCard(Place place) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: () => context.push('/place/${place.id}'),
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              AppImage(url: place.imageUrl, width: 64, height: 64, borderRadius: BorderRadius.circular(10), fallbackIcon: Icons.place),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(place.category.toUpperCase(), style: const TextStyle(color: AppColors.yellow, fontSize: 9, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(place.name, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(place.address, style: TextStyle(color: AppColors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, color: AppColors.grey, size: 14),
              GestureDetector(
                onTap: _controller.clearSelection,
                child: Padding(padding: const EdgeInsets.only(left: 8), child: Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.close, color: AppColors.white, size: 14))),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'critical': return const Color(0xFFD32F2F);
      case 'high':     return const Color(0xFFEF5350);
      case 'medium':   return const Color(0xFFFF7043);
      default:          return const Color(0xFFFFB74D);
    }
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(icon, color: AppColors.white, size: 20),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final Place place;
  final bool selected;
  const _MapMarker({required this.place, required this.selected});

  Color get _categoryColor {
    switch (place.category.toLowerCase()) {
      case 'transport':   return const Color(0xFF00BCD4);
      case 'university':  return const Color(0xFF7C4DFF);
      case 'restaurant':
      case 'cafe':        return const Color(0xFFFF7043);
      case 'hostel':      return const Color(0xFF66BB6A);
      case 'hotel':       return const Color(0xFF26A69A);
      case 'market':
      case 'mall':        return const Color(0xFFAB47BC);
      case 'hospital':    return const Color(0xFFEF5350);
      case 'nightlife':   return const Color(0xFFEC407A);
      default:            return AppColors.yellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? color : AppColors.navy.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: selected ? 0 : 1.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Text(place.category, style: TextStyle(color: selected ? AppColors.navy : color, fontSize: 11, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
