import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/models.dart';
import '../../core/supabase_service.dart';
import '../../shared/widgets/app_image.dart';
import '../place_details/place_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Place> _favs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final favs = await SupabaseService.instance.getFavorites();
      if (!mounted) return;
      setState(() {
        _favs = favs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.yellow,
          backgroundColor: AppColors.navyCard,
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SAVED', style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Text('YOUR PLACES.', style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 8),
                      Text('${_favs.length} saved places', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: AppColors.yellow)),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.cloud_off_rounded, color: AppColors.red, size: 56),
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: AppColors.greyLight), textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    ElevatedButton(onPressed: _load, child: const Text('RETRY')),
                  ]))),
                )
              else if (_favs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bookmark_outline_rounded, color: AppColors.grey.withValues(alpha: 0.4), size: 64),
                    const SizedBox(height: 16),
                    Text('No saved places yet', style: TextStyle(color: AppColors.greyLight, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Tap the bookmark on any place to save it here.', style: TextStyle(color: AppColors.grey, fontSize: 13), textAlign: TextAlign.center),
                  ]))),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.68),
                    delegate: SliverChildBuilderDelegate((context, i) => _SavedCard(place: _favs[i], onChanged: _load), childCount: _favs.length),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  final Place place;
  final VoidCallback onChanged;
  const _SavedCard({required this.place, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlaceDetailsScreen(placeId: place.id)));
        onChanged();
      },
      child: Container(
        decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(children: [
              AppImage(url: place.imageUrl, height: 130, width: double.infinity, fallbackIcon: Icons.place),
              Positioned(top: 8, right: 8, child: GestureDetector(
                onTap: () async {
                  await SupabaseService.instance.toggleFavorite(place.id);
                  onChanged();
                },
                child: Container(padding: EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.bookmark_rounded, color: AppColors.yellow, size: 14)),
              )),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(place.name, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(place.address, style: TextStyle(color: AppColors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.star_rounded, color: AppColors.yellow, size: 12),
                const SizedBox(width: 3),
                Text('${place.rating}', style: TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(place.priceLevel, style: const TextStyle(color: AppColors.yellow, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
