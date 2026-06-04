import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/user_location_dot.dart';
import '../../core/geo/geo_math.dart';

// â”€â”€ Data model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€ Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class DirectionsScreen extends StatefulWidget {
  final double destLat;
  final double destLng;
  final String destName;

  const DirectionsScreen({
    super.key,
    required this.destLat,
    required this.destLng,
    required this.destName,
  });

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  final _mapController = MapController();

  // The public router.project-osrm.org demo only has the car network loaded,
  // so it returns identical (driving) times for every profile. FOSSGIS runs
  // three separate OSRM engines — car / bike / foot — that each route on the
  // correct network, giving trustworthy per-mode distances and durations.
  // (The profile segment after /v1/ is ignored by OSRM — each engine has its
  // own profile compiled in — so 'driving' is fine for all three.)
  static const Map<String, String> _osrmHost = {
    'driving': 'https://routing.openstreetmap.de/routed-car',
    'cycling': 'https://routing.openstreetmap.de/routed-bike',
    'foot': 'https://routing.openstreetmap.de/routed-foot',
  };

  LatLng? _userLocation;
  double? _userHeading;
  List<LatLng> _routePoints = [];
  double? _distanceKm;
  int? _durationMin;
  String _profile = 'driving';
  bool _loading = true;
  String? _error;

  // Turn-by-turn
  List<RouteStep> _steps = [];
  int _currentStepIndex = 0;

  StreamSubscription<Position>? _locationSub;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  // â”€â”€ Location â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _start() async {
    await _initLocation();
    await _fetchRoute();
  }

  Future<void> _initLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _userLocation = const LatLng(5.6037, -0.1870));
        return;
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() {
          _userLocation = LatLng(last.latitude, last.longitude);
          _userHeading = last.heading >= 0 ? last.heading : null;
        });
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _userHeading = pos.heading >= 0 ? pos.heading : null;
        });
      }

      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (!mounted) { return; }
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _userHeading = pos.heading >= 0 ? pos.heading : null;
        });
        _updateCurrentStep();
      });
    } catch (_) {
      if (mounted) setState(() => _userLocation = const LatLng(5.6037, -0.1870));
    }
  }

  // â”€â”€ Routing â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _fetchRoute() async {
    if (_userLocation == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final host = _osrmHost[_profile] ?? _osrmHost['driving']!;
      final uri = Uri.parse(
        '$host/route/v1/driving/'
        '${_userLocation!.longitude},${_userLocation!.latitude};'
        '${widget.destLng},${widget.destLat}'
        '?overview=full&geometries=geojson&steps=true',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw 'Server error ${response.statusCode}';
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) throw 'No route found';

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry']['coordinates'] as List;
      final points = geometry
          .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      final steps = _parseSteps(route);

      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _distanceKm = (route['distance'] as num).toDouble() / 1000.0;
        _durationMin = ((route['duration'] as num).toDouble() / 60).round();
        _steps = steps;
        _currentStepIndex = 0;
        _loading = false;
      });

      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted && points.isNotEmpty) {
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(40, 160, 40, 300),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Could not load route. ${e.toString()}'; _loading = false; });
    }
  }

  void _switchProfile(String p) {
    if (p == _profile || _loading) return;
    setState(() => _profile = p);
    _fetchRoute();
  }

  // â”€â”€ Step parsing â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
          case 'left':        return 'Turn left$street';
          case 'right':       return 'Turn right$street';
          case 'slight left': return 'Turn slightly left$street';
          case 'slight right':return 'Turn slightly right$street';
          case 'sharp left':  return 'Turn sharp left$street';
          case 'sharp right': return 'Turn sharp right$street';
          case 'uturn':       return 'Make a U-turn$street';
          default:            return 'Continue$street';
        }
      case 'new name':  return 'Continue$street';
      case 'merge':     return 'Merge${modifier != null ? " $modifier" : ""}$street';
      case 'fork':
        return modifier == 'left'
            ? 'Keep left$street'
            : modifier == 'right'
                ? 'Keep right$street'
                : 'Fork$street';
      case 'roundabout':       return 'Enter the roundabout$street';
      case 'exit roundabout':  return 'Exit the roundabout$street';
      case 'rotary':           return 'Enter the rotary$street';
      case 'exit rotary':      return 'Exit the rotary$street';
      case 'end of road':
        return modifier == 'left' ? 'Turn left at the end$street' : 'Turn right at the end$street';
      default:
        return name.isNotEmpty ? 'Continue onto $name' : 'Continue';
    }
  }

  IconData _maneuverIcon(String type, String? modifier) {
    switch (type) {
      case 'depart':          return Icons.navigation_rounded;
      case 'arrive':          return Icons.flag_rounded;
      case 'roundabout':
      case 'rotary':
      case 'exit roundabout':
      case 'exit rotary':     return Icons.roundabout_right_rounded;
      case 'fork':
        return modifier == 'left'
            ? Icons.fork_left_rounded
            : Icons.fork_right_rounded;
      default:
        switch (modifier) {
          case 'left':         return Icons.turn_left_rounded;
          case 'right':        return Icons.turn_right_rounded;
          case 'slight left':  return Icons.turn_slight_left_rounded;
          case 'slight right': return Icons.turn_slight_right_rounded;
          case 'sharp left':   return Icons.turn_left_rounded;
          case 'sharp right':  return Icons.turn_right_rounded;
          case 'uturn':        return Icons.u_turn_left_rounded;
          default:             return Icons.straight_rounded;
        }
    }
  }

  // â”€â”€ Live step tracking â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Called on every location update â€” finds which step the user is currently on.
  void _updateCurrentStep() {
    if (_steps.isEmpty || _userLocation == null || _routePoints.isEmpty) return;

    // Find closest route point to user (distance via the central geo utility)
    double minD = double.infinity;
    int closestIdx = 0;
    for (int i = 0; i < _routePoints.length; i++) {
      final d = haversineMeters(_userLocation!, _routePoints[i]);
      if (d < minD) { minD = d; closestIdx = i; }
    }

    // Sum segment lengths from route start to closest point = approx distance traveled
    double traveled = 0;
    for (int i = 0; i < closestIdx; i++) {
      traveled += haversineMeters(_routePoints[i], _routePoints[i + 1]);
    }

    // Find which step the user is currently in by cumulative step distances
    double cumulative = 0;
    int newStep = _steps.length - 1;
    for (int i = 0; i < _steps.length; i++) {
      cumulative += _steps[i].distanceM;
      if (traveled < cumulative) { newStep = i; break; }
    }

    if (newStep != _currentStepIndex && mounted) {
      HapticFeedback.lightImpact(); // subtle tick on step change
      setState(() => _currentStepIndex = newStep);
    }
  }

  // â”€â”€ Camera â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _goToMyLocation() {
    if (_userLocation == null) return;
    if (_routePoints.isNotEmpty) {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([_userLocation!, ..._routePoints]),
        padding: const EdgeInsets.fromLTRB(40, 160, 40, 300),
      ));
    } else {
      _mapController.move(_userLocation!, 16);
    }
  }

  // â”€â”€ Display helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String get _eta {
    if (_durationMin == null) return 'â€”';
    if (_durationMin! < 60) return '$_durationMin min';
    final h = _durationMin! ~/ 60;
    final m = _durationMin! % 60;
    return '${h}h ${m}m';
  }

  String get _dist {
    if (_distanceKm == null) return 'â€”';
    if (_distanceKm! < 1) return '${(_distanceKm! * 1000).round()} m';
    return '${_distanceKm!.toStringAsFixed(1)} km';
  }

  String _estimateCost() {
    if (_distanceKm == null) return 'â€”';
    final km = _distanceKm!;
    final cost = switch (_profile) {
      'driving' => math.max(20.0, km * 8),
      _ => 0.0,
    };
    if (cost == 0) return 'Free';
    return 'GHS ${cost.round()}';
  }

  static String _stepDist(double meters) {
    if (meters < 50) return 'Now';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // â”€â”€ Steps sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
          ),
          // Header
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
          // Steps list
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: _steps.length,
              itemBuilder: (_, i) {
                final step = _steps[i];
                final isCurrent = i == _currentStepIndex;
                final isDone = i < _currentStepIndex;
                return _StepRow(
                  step: step,
                  index: i,
                  total: _steps.length,
                  isCurrent: isCurrent,
                  isDone: isDone,
                  icon: _maneuverIcon(step.maneuverType, step.modifier),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final dest = LatLng(widget.destLat, widget.destLng);
    final topPad = MediaQuery.of(context).padding.top;
    final hasSteps = _steps.isNotEmpty && !_loading;
    final currentStep = hasSteps ? _steps[_currentStepIndex] : null;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          // â”€â”€ Map â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _userLocation ?? dest, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.welcome2gh',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 6,
                    color: AppColors.yellow,
                    borderColor: AppColors.navy,
                    borderStrokeWidth: 2,
                  ),
                ]),
              MarkerLayer(markers: [
                if (_userLocation != null)
                  Marker(
                    point: _userLocation!,
                    width: 80,
                    height: 80,
                    child: UserLocationDot(heading: _userHeading),
                  ),
                Marker(
                  point: dest,
                  width: 50,
                  height: 56,
                  alignment: Alignment.topCenter,
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(6)),
                      child: Text('DEST', style: TextStyle(color: AppColors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                    ),
                    const Icon(Icons.location_on_rounded, color: AppColors.red, size: 36),
                  ]),
                ),
              ]),
            ],
          ),

          // â”€â”€ Top header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                    child: Icon(Icons.arrow_back_rounded, color: AppColors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('TO', style: TextStyle(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      const SizedBox(height: 2),
                      Text(widget.destName, style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _goToMyLocation,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                    child: const Icon(Icons.my_location_rounded, color: AppColors.yellow, size: 20),
                  ),
                ),
              ]),
            ),
          ),

          // â”€â”€ Next-turn card (Google Maps style) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (currentStep != null)
            Positioned(
              top: topPad + 68,
              left: 12,
              right: 12,
              child: _NextTurnCard(
                step: currentStep,
                icon: _maneuverIcon(currentStep.maneuverType, currentStep.modifier),
                stepDist: _stepDist(currentStep.distanceM),
              ),
            ),

          // â”€â”€ Bottom panel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 32),
                          const SizedBox(height: 8),
                          Text(_error!, style: TextStyle(color: AppColors.greyLight, fontSize: 12), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _fetchRoute, child: const Text('RETRY')),
                        ]),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Stat(icon: Icons.timer_outlined, label: 'TIME', value: _eta, color: AppColors.yellow),
                          Container(width: 1, height: 40, color: AppColors.cardBorder),
                          _Stat(icon: Icons.route_outlined, label: 'DISTANCE', value: _dist, color: AppColors.yellow),
                          Container(width: 1, height: 40, color: AppColors.cardBorder),
                          _Stat(icon: Icons.attach_money_rounded, label: 'EST. COST', value: _estimateCost(), color: const Color(0xFF66BB6A)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Action buttons row
                      Row(children: [
                        // Steps button
                        if (_steps.isNotEmpty)
                          Expanded(
                            flex: 1,
                            child: GestureDetector(
                              onTap: _showStepsSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                decoration: BoxDecoration(
                                  color: AppColors.navyCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.list_alt_rounded, color: AppColors.yellow, size: 18),
                                  const SizedBox(height: 4),
                                  Text('${_steps.length} STEPS', style: const TextStyle(color: AppColors.yellow, fontSize: 10, fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ),
                          ),
                        if (_steps.isNotEmpty) const SizedBox(width: 10),
                        // Start navigation button
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Navigation started â€” follow the yellow route.'),
                                  backgroundColor: AppColors.green,
                                ),
                              );
                            },
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
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// The floating card at the top of the map showing the next maneuver â€” identical
/// in concept to Google Maps' blue navigation banner.
class _NextTurnCard extends StatelessWidget {
  final RouteStep step;
  final IconData icon;
  final String stepDist;

  const _NextTurnCard({required this.step, required this.icon, required this.stepDist});

  @override
  Widget build(BuildContext context) {
    final isArrive = step.maneuverType == 'arrive';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOut),
        ),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: Container(
        key: ValueKey(step.instruction),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isArrive ? AppColors.green.withValues(alpha: 0.95) : AppColors.navy.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isArrive ? AppColors.green : AppColors.yellow.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          // Maneuver icon bubble
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isArrive ? Colors.white.withValues(alpha: 0.2) : AppColors.yellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isArrive ? Colors.white : AppColors.yellow, size: 24),
          ),
          const SizedBox(width: 14),
          // Instruction text
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(
                step.instruction,
                style: TextStyle(
                  color: isArrive ? Colors.white : AppColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isArrive && step.distanceM > 0) ...[
                const SizedBox(height: 3),
                Text('in $stepDist', style: TextStyle(color: isArrive ? Colors.white70 : AppColors.grey, fontSize: 12)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One row in the steps sheet â€” mirrors the Google Maps directions list style.
class _StepRow extends StatelessWidget {
  final RouteStep step;
  final int index;
  final int total;
  final bool isCurrent;
  final bool isDone;
  final IconData icon;

  const _StepRow({
    required this.step,
    required this.index,
    required this.total,
    required this.isCurrent,
    required this.isDone,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return Container(
      color: isCurrent ? AppColors.yellow.withValues(alpha: 0.08) : Colors.transparent,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Timeline column
        SizedBox(
          width: 56,
          child: Column(children: [
            const SizedBox(height: 16),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppColors.yellow
                    : isDone
                        ? AppColors.cardBorder
                        : AppColors.navyCard,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrent ? AppColors.yellow : AppColors.cardBorder,
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isCurrent
                    ? AppColors.navy
                    : isDone
                        ? AppColors.grey
                        : AppColors.greyLight,
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 32, color: AppColors.cardBorder),
          ]),
        ),
        // Text column
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 18, 16, 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(
                  step.instruction,
                  style: TextStyle(
                    color: isCurrent
                        ? AppColors.white
                        : isDone
                            ? AppColors.grey
                            : AppColors.greyLight,
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
                Text(
                  _DirectionsScreenState._stepDist(step.distanceM),
                  style: TextStyle(
                    color: isCurrent ? AppColors.yellow : AppColors.grey,
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
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
