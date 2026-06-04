import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../core/geo/geo_math.dart';
import '../../core/models.dart';

/// Permission status for device location, surfaced to the UI so it can give
/// the user real feedback instead of silently doing nothing.
enum LocationStatus { unknown, granted, denied, deniedForever }

/// Sentinel used by [MapViewState.copyWith] to distinguish "leave unchanged"
/// from "set to null".
const Object _unset = Object();

/// ─────────────────────────────────────────────────────────────────────────
/// Immutable snapshot of everything the Map screen needs to render.
///
/// The map's position, heading and viewport (centre + zoom) live here and
/// nowhere else — this is the single source of truth. The UI wrapper reads
/// from it to build widgets, and the camera/routing logic reads the *same*
/// object to decide where to move. State only ever changes by emitting a new
/// snapshot through [MapStateController]; widgets never mutate it directly.
/// ─────────────────────────────────────────────────────────────────────────
@immutable
class MapViewState {
  /// Default camera target — central Accra.
  static const LatLng accra = LatLng(5.6037, -0.1870);

  final LatLng? userLocation;
  final double? userHeading;

  /// Camera viewport — the authoritative centre + zoom.
  final LatLng center;
  final double zoom;

  /// Whether the camera is locked to the user (Google-Maps style follow).
  final bool followUser;

  final String filter;
  final String search;

  final String? selectedPlaceId;

  final List<Place> places;
  final List<AlertItem> alerts;

  final bool loading;
  final String? error;
  final LocationStatus locationStatus;

  const MapViewState({
    this.userLocation,
    this.userHeading,
    this.center = accra,
    this.zoom = 12.5,
    this.followUser = false,
    this.filter = 'All',
    this.search = '',
    this.selectedPlaceId,
    this.places = const [],
    this.alerts = const [],
    this.loading = true,
    this.error,
    this.locationStatus = LocationStatus.unknown,
  });

  /// The currently selected place, or null if none / no longer in results.
  Place? get selectedPlace {
    for (final p in places) {
      if (p.id == selectedPlaceId) return p;
    }
    return null;
  }

  /// Alerts that have a coordinate and can actually be drawn — the count the
  /// UI should report so the badge matches the pins.
  List<AlertItem> get mappableAlerts =>
      alerts.where((a) => a.isMappable).toList();

  /// Build a transform viewport for the given widget size from the current
  /// camera state. All world↔screen math flows through this.
  MapViewport viewport(double width, double height) => MapViewport(
        center: center,
        zoom: zoom,
        width: width,
        height: height,
      );

  MapViewState copyWith({
    Object? userLocation = _unset,
    Object? userHeading = _unset,
    LatLng? center,
    double? zoom,
    bool? followUser,
    String? filter,
    String? search,
    Object? selectedPlaceId = _unset,
    List<Place>? places,
    List<AlertItem>? alerts,
    bool? loading,
    Object? error = _unset,
    LocationStatus? locationStatus,
  }) {
    return MapViewState(
      userLocation: identical(userLocation, _unset)
          ? this.userLocation
          : userLocation as LatLng?,
      userHeading: identical(userHeading, _unset)
          ? this.userHeading
          : userHeading as double?,
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      followUser: followUser ?? this.followUser,
      filter: filter ?? this.filter,
      search: search ?? this.search,
      selectedPlaceId: identical(selectedPlaceId, _unset)
          ? this.selectedPlaceId
          : selectedPlaceId as String?,
      places: places ?? this.places,
      alerts: alerts ?? this.alerts,
      loading: loading ?? this.loading,
      error: identical(error, _unset) ? this.error : error as String?,
      locationStatus: locationStatus ?? this.locationStatus,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// The single store for the Map screen. Every state change is an explicit,
/// named action that produces a new [MapViewState] and notifies listeners —
/// a predictable, unidirectional data flow (action → new state → UI).
/// ─────────────────────────────────────────────────────────────────────────
class MapStateController extends ChangeNotifier {
  MapViewState _state = const MapViewState();
  MapViewState get state => _state;

  void _emit(MapViewState next) {
    if (identical(next, _state)) return;
    _state = next;
    notifyListeners();
  }

  // ── Data loading ────────────────────────────────────────────────────────

  void startLoading() => _emit(_state.copyWith(loading: true, error: null));

  void setError(String message) =>
      _emit(_state.copyWith(loading: false, error: message));

  /// Apply freshly-loaded data. Also reconciles the current selection: if the
  /// selected place is no longer in the results, the selection is cleared so
  /// the bottom card can't show a place with no marker.
  void setData({required List<Place> places, required List<AlertItem> alerts}) {
    final stillThere =
        _state.selectedPlaceId != null && places.any((p) => p.id == _state.selectedPlaceId);
    _emit(_state.copyWith(
      places: places,
      alerts: alerts,
      loading: false,
      error: null,
      selectedPlaceId: stillThere ? _state.selectedPlaceId : null,
    ));
  }

  // ── Filters & search ──────────────────────────────────────────────────────

  void setFilter(String filter) => _emit(_state.copyWith(filter: filter));

  void setSearch(String search) => _emit(_state.copyWith(search: search));

  void clearFilters() =>
      _emit(_state.copyWith(filter: 'All', search: '', selectedPlaceId: null));

  // ── Selection ─────────────────────────────────────────────────────────────

  void select(String placeId) =>
      _emit(_state.copyWith(selectedPlaceId: placeId));

  void clearSelection() => _emit(_state.copyWith(selectedPlaceId: null));

  // ── Camera / viewport ──────────────────────────────────────────────────────

  /// Sync the authoritative centre/zoom from the rendered map (e.g. after the
  /// user pans). Does NOT command the map — it only records reality.
  void syncCamera(LatLng center, double zoom) =>
      _emit(_state.copyWith(center: center, zoom: zoom));

  void setFollow(bool follow) => _emit(_state.copyWith(followUser: follow));

  // ── Location ──────────────────────────────────────────────────────────────

  void setLocationStatus(LocationStatus status) =>
      _emit(_state.copyWith(locationStatus: status));

  /// Record a new GPS fix. [heading] may be null when unknown.
  void setUserLocation(LatLng location, double? heading) {
    _emit(_state.copyWith(
      userLocation: location,
      userHeading: heading,
      locationStatus: LocationStatus.granted,
    ));
  }
}
