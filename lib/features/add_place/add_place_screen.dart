import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/supabase_service.dart';
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
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  String _category = 'Restaurant';
  String _priceLevel = '\$\$';
  bool _saving = false;
  String? _photoUrl;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  final _categories = ['Restaurant', 'Hostel', 'Hotel', 'University', 'Cafe', 'Mall', 'Transport', 'Tourist', 'Hospital', 'Other'];

  Future<void> _useCurrentLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied'), backgroundColor: AppColors.red));
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _lat.text = pos.latitude.toStringAsFixed(6);
      _lng.text = pos.longitude.toStringAsFixed(6);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get location: $e'), backgroundColor: AppColors.red));
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _lat.text.trim().isEmpty || _lng.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and coordinates are required'), backgroundColor: AppColors.red));
      return;
    }
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid coordinates — enter decimal numbers'), backgroundColor: AppColors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.instance.addPlace(
        name: _name.text.trim(),
        category: _category,
        description: _description.text.trim(),
        address: _address.text.trim(),
        lat: lat,
        lng: lng,
        priceLevel: _priceLevel,
        imageUrl: _photoUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Place added! Awaiting verification.'), backgroundColor: AppColors.green));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red));
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
                      SizedBox(height: 8),
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
          Text('COORDINATES', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _lat, keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true), style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'Latitude'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _lng, keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true), style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'Longitude'))),
          ]),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: _useCurrentLocation, icon: const Icon(Icons.my_location_rounded, color: AppColors.yellow, size: 16), label: const Text('Use my current location', style: TextStyle(color: AppColors.yellow))),
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
