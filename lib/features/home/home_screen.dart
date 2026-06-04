import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/models.dart';
import '../../core/supabase_service.dart';
import '../../shared/widgets/app_image.dart';
import '../../shared/widgets/app_logo.dart';
import '../place_details/place_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  final _scrollController = ScrollController();
  String _filter = 'All';
  Timer? _debounce;
  List<Place> _places = [];
  List<Place> _featured = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  Map<String, String> _hero = SupabaseService.defaultHero;

  static const _pageSize = 20;

  final _categories = ['All', 'University', 'Hostel', 'Hotel', 'Restaurant', 'Transport', 'Mall', 'Tourist'];

  @override
  void initState() {
    super.initState();
    _load();
    _loadFeatured();
    _loadHero();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadFeatured() async {
    try {
      // getPlaces() returns highest-rated first → real "top-rated" spots.
      final f = await SupabaseService.instance.getPlaces(limit: 10);
      if (mounted) setState(() => _featured = f);
    } catch (_) {/* non-critical */}
  }

  Future<void> _loadHero() async {
    final h = await SupabaseService.instance.getHeroConfig();
    if (mounted) setState(() => _hero = h);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final places = await SupabaseService.instance.getPlaces(
        category: _filter == 'All' ? null : _filter,
        search: _search.text.isEmpty ? null : _search.text,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _places = places;
        _loading = false;
        _hasMore = places.length == _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final more = await SupabaseService.instance.getPlaces(
        category: _filter == 'All' ? null : _filter,
        search: _search.text.isEmpty ? null : _search.text,
        limit: _pageSize,
        offset: _places.length,
      );
      if (!mounted) return;
      setState(() {
        _places.addAll(more);
        _loadingMore = false;
        _hasMore = more.length == _pageSize;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Widget _quickTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 7),
          Text(label, style: TextStyle(color: AppColors.greyLight, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _showSafetyReport(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'unsafe_area';
    final types = {
      'unsafe_area': 'Unsafe area',
      'scam': 'Scam',
      'traffic': 'Traffic',
      'high_crowd': 'Crowding',
    };
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navyCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setSh) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SAFETY REPORT', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFFEF5350))),
            const SizedBox(height: 8),
            Text('Warn nearby travelers', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: types.entries.map((e) {
              final active = e.key == type;
              return GestureDetector(
                onTap: () => setSh(() => type = e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: active ? const Color(0xFFEF5350) : AppColors.navy, borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? const Color(0xFFEF5350) : AppColors.cardBorder)),
                  child: Text(e.value, style: TextStyle(color: active ? Colors.white : AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              );
            }).toList()),
            const SizedBox(height: 14),
            TextField(controller: titleCtrl, style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'Short title (e.g. Pickpockets at Makola)')),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, maxLines: 3, style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'What happened? Where exactly?')),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF5350), foregroundColor: Colors.white),
              onPressed: saving ? null : () async {
                if (titleCtrl.text.trim().isEmpty) return;
                setSh(() => saving = true);
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final ctxMessenger = ScaffoldMessenger.of(ctx);
                double? lat, lng;
                try {
                  if (await Geolocator.checkPermission() != LocationPermission.denied) {
                    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low).timeout(const Duration(seconds: 4));
                    lat = pos.latitude; lng = pos.longitude;
                  }
                } catch (_) {}
                try {
                  await SupabaseService.instance.reportSafetyIssue(
                    type: type, title: titleCtrl.text.trim(), description: descCtrl.text.trim(), lat: lat, lng: lng,
                  );
                  if (ctx.mounted) nav.pop();
                  if (mounted) messenger.showSnackBar(const SnackBar(content: Text('Safety report submitted. Thank you!'), backgroundColor: AppColors.green));
                } catch (e) {
                  setSh(() => saving = false);
                  if (ctx.mounted) ctxMessenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red));
                }
              },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('SUBMIT REPORT'),
            )),
            const SizedBox(height: 24),
          ]),
        );
      }),
    );
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
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _Header()),
              SliverToBoxAdapter(child: _SearchBar(controller: _search, onChanged: _onSearchChanged)),
              SliverToBoxAdapter(
                child: _HeroCard(
                  title: _hero['title'] ?? '',
                  subtitle: _hero['subtitle'] ?? '',
                  imageUrl: _hero['image_url'] ?? '',
                  ctaText: _hero['cta_text'] ?? 'OPEN THE MAP',
                  onTap: () => context.go(_hero['cta_route'] ?? '/map'),
                ),
              ),
              // Quick actions (replaces the floating + button)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Row(children: [
                    _quickTile(Icons.add_location_alt_rounded, 'Add Place', AppColors.yellow,
                        () => context.push('/add-place').then((_) { if (mounted) { _load(); _loadFeatured(); } })),
                    _quickTile(Icons.attach_money_rounded, 'Fair Price', const Color(0xFF66BB6A),
                        () => context.push('/fair-price')),
                    _quickTile(Icons.auto_awesome_rounded, 'AI Guide', const Color(0xFF7C4DFF),
                        () => context.push('/ai')),
                    _quickTile(Icons.warning_amber_rounded, 'Safety', const Color(0xFFEF5350),
                        () => _showSafetyReport(context)),
                  ]),
                ),
              ),
              // Featured: real top-rated places from the database
              if (_featured.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('FEATURED', style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Text('Top-rated in Accra', style: Theme.of(context).textTheme.headlineMedium),
                    ]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 210,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      itemCount: _featured.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _FeaturedCard(place: _featured[i]),
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PLACES IN ACCRA', style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((c) {
                            final active = c == _filter;
                            return GestureDetector(
                              onTap: () { setState(() => _filter = c); _load(); },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: active ? AppColors.yellow : AppColors.navyCard,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: active ? AppColors.yellow : AppColors.cardBorder),
                                ),
                                child: Text(c, style: TextStyle(color: active ? AppColors.navy : AppColors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(child: PlaceListSkeleton(count: 5))
              else if (_error != null)
                SliverToBoxAdapter(child: _ErrorBanner(error: _error!, onRetry: _load))
              else if (_places.isEmpty)
                SliverToBoxAdapter(child: _EmptyState(onClear: () { _filter = 'All'; _search.clear(); _load(); }))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _PlaceListItem(place: _places[i]),
                    childCount: _places.length,
                  ),
                ),
              if (_loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.yellow))),
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

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          const AppLogoChip(size: 38, glow: true),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WELCOME2GH', style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 1)),
              Text('EXPLORE ACCRA', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.grey, fontSize: 9)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push('/ai'),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.yellow, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: AppColors.white),
        decoration: InputDecoration(
          hintText: 'Search a place or district...',
          prefixIcon: Icon(Icons.search, color: AppColors.grey, size: 20),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title, subtitle, imageUrl, ctaText;
  final VoidCallback onTap;
  const _HeroCard({required this.title, required this.subtitle, required this.imageUrl, required this.ctaText, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        height: 200,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: AppImage(url: imageUrl, fit: BoxFit.cover)),
              Container(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppColors.navy.withValues(alpha: 0.9)])),
              ),
              Positioned(
                bottom: 20, left: 20, right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text(title, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 22)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(10)),
                      child: Text(ctaText, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.navy)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Featured card showing a real place from the database.
class _FeaturedCard extends StatelessWidget {
  final Place place;
  const _FeaturedCard({required this.place});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlaceDetailsScreen(placeId: place.id))),
      child: SizedBox(
        width: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImage(url: place.imageUrl, fit: BoxFit.cover, fallbackIcon: Icons.place),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.navy.withValues(alpha: 0.55), AppColors.navy.withValues(alpha: 0.95)],
                    stops: const [0.25, 0.6, 1.0],
                  ),
                ),
              ),
              Positioned(top: 12, left: 12, child: _CategoryChip(label: place.category)),
              if (place.verified)
                const Positioned(top: 12, right: 12, child: Icon(Icons.verified_rounded, color: AppColors.yellow, size: 18)),
              Positioned(
                left: 12, right: 12, bottom: 12,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15, height: 1.2)),
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.star_rounded, color: AppColors.yellow, size: 14),
                    const SizedBox(width: 3),
                    Text('${place.rating}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Text('(${place.reviewCount})', style: TextStyle(color: AppColors.greyLight, fontSize: 11)),
                    const Spacer(),
                    Text(place.priceLevel, style: const TextStyle(color: AppColors.yellow, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceListItem extends StatelessWidget {
  final Place place;
  const _PlaceListItem({required this.place});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlaceDetailsScreen(placeId: place.id)));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        height: 112,
        decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image fills the full height of the card, flush on the left.
              SizedBox(
                width: 104,
                child: AppImage(url: place.imageUrl, fit: BoxFit.cover, fallbackIcon: Icons.place),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(children: [_CategoryChip(label: place.category), const Spacer(), if (place.verified) const Icon(Icons.verified_rounded, color: AppColors.yellow, size: 14)]),
                      const SizedBox(height: 6),
                      Text(place.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(place.address, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: AppColors.yellow, size: 13),
                          const SizedBox(width: 3),
                          Text('${place.rating}', style: TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          Text('(${place.reviewCount})', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                          const Spacer(),
                          Text(place.priceLevel, style: const TextStyle(color: AppColors.yellow, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.yellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3))),
      child: Text(label.toUpperCase(), style: const TextStyle(color: AppColors.yellow, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.08), border: Border.all(color: AppColors.red.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(Icons.cloud_off_rounded, color: AppColors.red, size: 18), SizedBox(width: 8), Text('Failed to load places', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600))]),
            const SizedBox(height: 6),
            Text(error, style: TextStyle(color: AppColors.greyLight, fontSize: 12)),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: onRetry, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onClear;
  const _EmptyState({required this.onClear});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: AppColors.grey.withValues(alpha: 0.4), size: 56),
          const SizedBox(height: 12),
          Text('No places match your search', style: TextStyle(color: AppColors.grey)),
          const SizedBox(height: 10),
          TextButton(onPressed: onClear, child: const Text('Clear filters', style: TextStyle(color: AppColors.yellow))),
        ],
      ),
    );
  }
}
