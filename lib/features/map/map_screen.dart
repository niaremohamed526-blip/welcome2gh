import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/models.dart';
import '../../core/supabase_service.dart';
import '../../shared/widgets/app_image.dart';
import '../../shared/widgets/user_location_dot.dart';
import '../place_details/place_details_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  Place? _selected;
  String _filter = 'All';
  String _search = '';
  Timer? _debounce;
  AnimationController? _moveCtrl;
  final _categories = ['All', 'University', 'Hostel', 'Hotel', 'Restaurant', 'Transport'];

  List<Place> _places = [];
  List<AlertItem> _alerts = [];
  bool _loading = true;
  String? _error;

  // â”€â”€ Live location state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  LatLng? _userLocation;
  double? _userHeading;   // degrees from north, null = unknown
  bool _followUser = false; // camera tracks user like Google Maps
  StreamSubscription<Position>? _locationSub;

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
    super.dispose();
  }

  // â”€â”€ Location stream â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _startLocationStream() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) { return; }

      // Show last known immediately so dot appears at once
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() {
          _userLocation = LatLng(last.latitude, last.longitude);
          _userHeading = last.heading >= 0 ? last.heading : null;
        });
      }

      // Live stream â€” update every 5 m of movement
      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (!mounted) return;
        final newLoc = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _userLocation = newLoc;
          _userHeading = pos.heading >= 0 ? pos.heading : null;
        });
        // If follow mode is on, keep camera centred on user
        if (_followUser) {
          _animatedMove(newLoc, _mapController.camera.zoom);
        }
      });
    } catch (_) {/* location is optional */}
  }

  // â”€â”€ Camera animation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _animatedMove(LatLng dest, double destZoom) {
    _moveCtrl?.dispose();
    final cam = _mapController.camera;
    final latTween = Tween<double>(begin: cam.center.latitude, end: dest.latitude);
    final lngTween = Tween<double>(begin: cam.center.longitude, end: dest.longitude);
    final zoomTween = Tween<double>(begin: cam.zoom, end: destZoom);
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeInOutCubic);
    ctrl.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(anim), lngTween.evaluate(anim)),
        zoomTween.evaluate(anim),
      );
    });
    ctrl.forward().whenComplete(ctrl.dispose);
    _moveCtrl = ctrl;
  }

  // â”€â”€ Search / filter / load â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _search = value);
      _load();
    });
  }

  Future<void> _load() async {
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
      setState(() {
        _places = results[0] as List<Place>;
        _alerts = results[1] as List<AlertItem>;
        _loading = false;
      });
      if (_search.trim().isNotEmpty && _places.isNotEmpty) {
        final pts = _places.map((p) => LatLng(p.lat, p.lng)).toList();
        if (pts.length == 1) {
          _mapController.move(pts.first, 15);
        } else {
          _mapController.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(pts),
            padding: const EdgeInsets.all(80),
          ));
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // â”€â”€ UI helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  /// Shows a bottom sheet when the user taps their own location dot.
  void _showUserLocationSheet() {
    if (_userLocation == null) return;
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
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location_rounded, color: AppColors.yellow, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('YOUR LOCATION', style: TextStyle(color: AppColors.yellow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  const SizedBox(height: 5),
                  Text(
                    '${_userLocation!.latitude.toStringAsFixed(6)},  ${_userLocation!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(color: AppColors.greyLight, fontSize: 13),
                  ),
                  if (_userHeading != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Heading ${_userHeading!.toStringAsFixed(0)}Â°',
                      style: TextStyle(color: AppColors.grey, fontSize: 11),
                    ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(5.6037, -0.1870),
              initialZoom: 12.5,
              // Disable follow mode the moment the user manually pans the map
              onMapEvent: (event) {
                if (_followUser &&
                    event is MapEventMoveStart &&
                    event.source != MapEventSource.mapController) {
                  setState(() => _followUser = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.welcome2gh',
              ),
              // Alert danger zones
              CircleLayer(
                circles: _alerts.where((a) => a.lat != null && a.lng != null).map((a) {
                  final color = _severityColor(a.severity);
                  return CircleMarker(
                    point: LatLng(a.lat!, a.lng!),
                    radius: 60,
                    color: color.withValues(alpha: 0.15),
                    borderColor: color.withValues(alpha: 0.6),
                    borderStrokeWidth: 1.5,
                    useRadiusInMeter: false,
                  );
                }).toList(),
              ),
              // Clustered place markers
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 60,
                  size: const Size(44, 44),
                  padding: const EdgeInsets.all(50),
                  markers: _places.map((p) {
                    final isSelected = _selected?.id == p.id;
                    return Marker(
                      point: LatLng(p.lat, p.lng),
                      width: isSelected ? 100 : 80,
                      height: isSelected ? 44 : 36,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selected = p);
                        },
                        child: _MapMarker(place: p, selected: isSelected),
                      ),
                    );
                  }).toList(),
                  builder: (context, markers) => Container(
                    decoration: BoxDecoration(
                      color: AppColors.yellow,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.navy, width: 2),
                      boxShadow: [BoxShadow(color: AppColors.yellow.withValues(alpha: 0.4), blurRadius: 10)],
                    ),
                    child: Center(
                      child: Text(
                        '${markers.length}',
                        style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ),
              // Alert icons + user location (never clustered)
              MarkerLayer(
                markers: [
                  ..._alerts.where((a) => a.lat != null && a.lng != null).map((a) {
                    final color = _severityColor(a.severity);
                    return Marker(
                      point: LatLng(a.lat!, a.lng!),
                      width: 32,
                      height: 32,
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
                  }),
                  // Live user location dot â€” tappable
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 80,
                      height: 80,
                      child: GestureDetector(
                        onTap: _showUserLocationSheet,
                        child: UserLocationDot(heading: _userHeading),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // â”€â”€ Top controls â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SafeArea(
            child: Column(
              children: [
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
                            suffixIcon: _search.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchCtrl.clear();
                                      setState(() => _search = '');
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
                    // Location / follow-mode button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (_userLocation != null) {
                          setState(() => _followUser = true);
                          _animatedMove(_userLocation!, 16);
                        } else {
                          _startLocationStream();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _followUser
                              ? AppColors.yellow
                              : AppColors.navy.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _followUser ? AppColors.yellow : AppColors.cardBorder,
                          ),
                          boxShadow: _followUser
                              ? [BoxShadow(color: AppColors.yellow.withValues(alpha: 0.4), blurRadius: 12)]
                              : [],
                        ),
                        child: Icon(
                          _followUser
                              ? Icons.my_location_rounded
                              : Icons.location_searching_rounded,
                          color: _followUser ? AppColors.navy : AppColors.yellow,
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
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _categories.map((c) {
                      final active = c == _filter;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _filter = c);
                          _load();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: active ? AppColors.yellow : AppColors.navy.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? AppColors.yellow : AppColors.cardBorder)),
                          child: Text(c, style: TextStyle(color: active ? AppColors.navy : AppColors.grey, fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Status pill
          Positioned(
            top: 120,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.cardBorder)),
              child: Row(children: [
                if (_loading) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.yellow))
                else const Icon(Icons.location_on_rounded, color: AppColors.red, size: 14),
                const SizedBox(width: 6),
                Text(_loading ? 'Loading...' : '${_places.length} place(s) on the map', style: TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                if (_alerts.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.grey, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350), size: 12),
                  const SizedBox(width: 4),
                  Text('${_alerts.length} alert(s)', style: const TextStyle(color: Color(0xFFEF5350), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
          ),

          // Follow-mode indicator banner
          if (_followUser)
            Positioned(
              top: 156,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.yellow.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.navigation_rounded, color: AppColors.yellow, size: 12),
                  const SizedBox(width: 5),
                  const Text('Following your location', style: TextStyle(color: AppColors.yellow, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),

          if (!_loading && _error == null && _places.isEmpty)
            Positioned(
              top: 160, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                child: Row(children: [
                  Icon(Icons.search_off_rounded, color: AppColors.grey, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    _search.isNotEmpty ? 'No places match "$_search"' : 'No places in this category',
                    style: TextStyle(color: AppColors.greyLight, fontSize: 13),
                  )),
                  if (_search.isNotEmpty || _filter != 'All')
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() { _search = ''; _filter = 'All'; });
                        _load();
                      },
                      child: const Text('CLEAR', style: TextStyle(color: AppColors.yellow, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                ]),
              ),
            ),
          if (_error != null)
            Positioned(top: 160, left: 16, right: 16, child: Material(
              color: AppColors.red.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: _load,
                child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18), const SizedBox(width: 10), Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 12))), const Text('TAP TO RETRY', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))])),
              ),
            )),

          // Zoom controls â€” move up when place card is visible
          Positioned(
            right: 16,
            bottom: _selected != null ? 230 : 110,
            child: Column(children: [
              _ZoomButton(icon: Icons.add, onTap: () {
                final c = _mapController.camera;
                _mapController.move(c.center, c.zoom + 1);
              }),
              const SizedBox(height: 8),
              _ZoomButton(icon: Icons.remove, onTap: () {
                final c = _mapController.camera;
                _mapController.move(c.center, c.zoom - 1);
              }),
            ]),
          ),

          // Selected place card
          if (_selected != null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlaceDetailsScreen(placeId: _selected!.id)));
                },
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      AppImage(url: _selected!.imageUrl, width: 64, height: 64, borderRadius: BorderRadius.circular(10), fallbackIcon: Icons.place),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_selected!.category.toUpperCase(), style: const TextStyle(color: AppColors.yellow, fontSize: 9, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(_selected!.name, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(_selected!.address, style: TextStyle(color: AppColors.grey, fontSize: 11)),
                      ])),
                      Icon(Icons.arrow_forward_ios_rounded, color: AppColors.grey, size: 14),
                      GestureDetector(
                        onTap: () => setState(() => _selected = null),
                        child: Padding(padding: EdgeInsets.only(left: 8), child: Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.close, color: AppColors.white, size: 14))),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ],
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
      case 'restaurant':  return const Color(0xFFFF7043);
      case 'hostel':
      case 'hotel':
      case 'stay':        return const Color(0xFF66BB6A);
      default:            return AppColors.yellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? _categoryColor : AppColors.navy.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _categoryColor, width: selected ? 0 : 1.5),
        boxShadow: [BoxShadow(color: _categoryColor.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Text(place.category, style: TextStyle(color: selected ? AppColors.navy : _categoryColor, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
