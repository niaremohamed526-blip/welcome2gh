import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/supabase_service.dart';
import '../../core/geocoding_service.dart';
import '../../core/image_upload.dart';

class AddPlaceScreen extends StatefulWidget {
  const AddPlaceScreen({super.key});

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _locSearch = TextEditingController();
  final _mapController = MapController();

  LatLng? _location; // the chosen pin
  List<GeoResult> _results = [];
  bool _searching = false;
  Timer? _searchDebounce;

  String _category = 'Restaurant';
  String _priceLevel = '\$\$';
  bool _saving = false;
  String? _photoUrl;

  static const _accra = LatLng(5.6037, -0.1870);

  final _categories = ['Restaurant', 'Hostel', 'Hotel', 'University', 'Cafe', 'Mall', 'Transport', 'Tourist', 'Hospital', 'Other'];

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    _locSearch.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _setLocation(LatLng loc, {bool moveCamera = true}) {
    setState(() => _location = loc);
    if (moveCamera) _mapController.move(loc, 16);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    final results = await GeocodingService.search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _pickResult(GeoResult r) {
    FocusScope.of(context).unfocus();
    _locSearch.text = r.label.split(',').first;
    setState(() => _results = []);
    if (_address.text.trim().isEmpty) _address.text = r.label;
    _setLocation(r.location);
  }

  Future<void> _useCurrentLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied'), backgroundColor: AppColors.red));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      _setLocation(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get location: $e'), backgroundColor: AppColors.red));
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_name.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('A name is required'), backgroundColor: AppColors.red));
      return;
    }
    if (_location == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Set the location — search, tap the map, or use your GPS'), backgroundColor: AppColors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.instance.addPlace(
        name: _name.text.trim(),
        category: _category,
        description: _description.text.trim(),
        address: _address.text.trim(),
        lat: _location!.latitude,
        lng: _location!.longitude,
        priceLevel: _priceLevel,
        imageUrl: _photoUrl,
      );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Place added! Awaiting verification.'), backgroundColor: AppColors.green));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(title: const Text('ADD A PLACE'), leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PHOTO', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final url = await ImageUploadHelper.pickAndUpload(context, bucket: 'places');
              if (url != null && mounted) setState(() => _photoUrl = url);
            },
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.navyCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
                image: _photoUrl != null ? DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover) : null,
              ),
              child: _photoUrl == null
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo_rounded, color: AppColors.grey, size: 32),
                      const SizedBox(height: 8),
                      Text('Add a photo', style: TextStyle(color: AppColors.grey, fontSize: 13)),
                    ])
                  : Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.edit_rounded, color: AppColors.yellow, size: 16),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Text('NAME', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          TextField(controller: _name, style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'e.g. Buka Restaurant')),
          const SizedBox(height: 20),
          Text('CATEGORY', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) {
            final active = c == _category;
            return GestureDetector(
              onTap: () => setState(() => _category = c),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: active ? AppColors.yellow : AppColors.navyCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? AppColors.yellow : AppColors.cardBorder)),
                child: Text(c, style: TextStyle(color: active ? AppColors.navy : AppColors.grey, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            );
          }).toList()),
          const SizedBox(height: 20),
          Text('PRICE LEVEL', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Row(children: ['\$', '\$\$', '\$\$\$', '\$\$\$\$'].map((p) {
            final active = p == _priceLevel;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _priceLevel = p),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: active ? AppColors.yellow : AppColors.navyCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? AppColors.yellow : AppColors.cardBorder)),
                child: Center(child: Text(p, style: TextStyle(color: active ? AppColors.navy : AppColors.grey, fontWeight: FontWeight.w700))),
              ),
            ));
          }).toList()),
          const SizedBox(height: 20),
          Text('ADDRESS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          TextField(controller: _address, style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'e.g. Osu, Accra')),
          const SizedBox(height: 20),

          // ── LOCATION PICKER ──────────────────────────────────────────────
          Text('LOCATION', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Text('Search a place, tap the map, or use your GPS — no need to type coordinates.',
              style: TextStyle(color: AppColors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: _locSearch,
            onChanged: _onSearchChanged,
            style: TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: 'Search e.g. "Accra Mall", "Osu Oxford Street"',
              prefixIcon: Icon(Icons.search, color: AppColors.grey, size: 20),
              suffixIcon: _searching
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.yellow)))
                  : null,
            ),
          ),
          if (_results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
              child: Column(
                children: _results.take(5).map((r) => ListTile(
                  dense: true,
                  leading: Icon(Icons.place_rounded, color: AppColors.yellow, size: 18),
                  title: Text(r.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.white, fontSize: 13)),
                  onTap: () => _pickResult(r),
                )).toList(),
              ),
            ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 240,
              child: Stack(children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _location ?? _accra,
                    initialZoom: 12.5,
                    onTap: (_, latlng) => _setLocation(latlng, moveCamera: false),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.welcome2gh',
                    ),
                    if (_location != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: _location!,
                          width: 44, height: 44,
                          alignment: Alignment.topCenter,
                          child: const Icon(Icons.location_on_rounded, color: AppColors.red, size: 40),
                        ),
                      ]),
                  ],
                ),
                if (_location == null)
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(20)),
                        child: Text('Tap the map to drop a pin', style: TextStyle(color: AppColors.white, fontSize: 12)),
                      ),
                    ),
                  ),
                Positioned(
                  right: 10, bottom: 10,
                  child: GestureDetector(
                    onTap: _useCurrentLocation,
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppColors.yellow.withValues(alpha: 0.4), blurRadius: 8)]),
                      child: Icon(Icons.my_location_rounded, color: AppColors.navy, size: 20),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.place_outlined, color: _location == null ? AppColors.grey : AppColors.green, size: 16),
            const SizedBox(width: 6),
            Text(
              _location == null
                  ? 'No location set yet'
                  : 'Pinned: ${_location!.latitude.toStringAsFixed(5)}, ${_location!.longitude.toStringAsFixed(5)}',
              style: TextStyle(color: _location == null ? AppColors.grey : AppColors.greyLight, fontSize: 12),
            ),
          ]),
          const SizedBox(height: 20),
          Text('DESCRIPTION', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          TextField(controller: _description, maxLines: 4, style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'Tell people what makes this place special...')),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                : const Text('SUBMIT PLACE'),
          )),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}
