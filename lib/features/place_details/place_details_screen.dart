import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/time_utils.dart';
import '../../core/models.dart';
import '../../core/supabase_service.dart';
import '../../core/image_upload.dart';
import '../../shared/widgets/app_image.dart';
import '../directions/directions_screen.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final String placeId;
  const PlaceDetailsScreen({super.key, required this.placeId});

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  Place? _place;
  List<Review> _reviews = [];
  bool _saved = false;
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
      final results = await Future.wait([
        SupabaseService.instance.getPlace(widget.placeId),
        SupabaseService.instance.getReviews(widget.placeId),
        SupabaseService.instance.getFavoriteIds(),
      ]);
      if (!mounted) return;
      setState(() {
        _place = results[0] as Place?;
        _reviews = results[1] as List<Review>;
        final favIds = results[2] as Set<String>;
        _saved = favIds.contains(widget.placeId);
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

  Future<void> _toggleSave() async {
    setState(() => _saved = !_saved);
    try {
      await SupabaseService.instance.toggleFavorite(widget.placeId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saved = !_saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red),
      );
    }
  }

  Future<void> _dial(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openDirections() async {
    final p = _place;
    if (p == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DirectionsScreen(
        destLat: p.lat,
        destLng: p.lng,
        destName: p.name,
      ),
    ));
  }

  void _openReviewSheet() {
    final ctrl = TextEditingController();
    double rating = 5;
    String? reviewPhoto;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setSh) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NEW REVIEW', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Text(_place?.name ?? '', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Row(
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setSh(() => rating = (i + 1).toDouble()),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.star_rounded, color: i < rating ? AppColors.yellow : AppColors.grey.withValues(alpha: 0.4), size: 32),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                maxLines: 4,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(hintText: 'Share your experience...'),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final url = await ImageUploadHelper.pickAndUpload(ctx, bucket: 'reviews');
                  if (url != null) setSh(() => reviewPhoto = url);
                },
                child: Container(
                  height: reviewPhoto != null ? 120 : 48,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                    image: reviewPhoto != null ? DecorationImage(image: NetworkImage(reviewPhoto!), fit: BoxFit.cover) : null,
                  ),
                  child: reviewPhoto == null
                      ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_a_photo_rounded, color: AppColors.grey, size: 18),
                          SizedBox(width: 8),
                          Text('Add a photo (optional)', style: TextStyle(color: AppColors.grey, fontSize: 13)),
                        ])
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await SupabaseService.instance.postReview(
                        placeId: widget.placeId,
                        rating: rating,
                        comment: ctrl.text.trim(),
                        images: reviewPhoto != null ? [reviewPhoto!] : null,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Review posted!'), backgroundColor: AppColors.green),
                      );
                      _load();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red),
                      );
                    }
                  },
                  child: const Text('SUBMIT REVIEW'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(backgroundColor: AppColors.navy, body: Center(child: CircularProgressIndicator(color: AppColors.yellow)));
    }
    if (_error != null || _place == null) {
      return Scaffold(
        backgroundColor: AppColors.navy,
        appBar: AppBar(),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.red, size: 56),
              const SizedBox(height: 12),
              Text(_error ?? 'Place not found', style: TextStyle(color: AppColors.greyLight), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('RETRY')),
            ],
          ),
        )),
      );
    }

    final place = _place!;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.navy,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.arrow_back_rounded, color: AppColors.white),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () => Share.share('Check out ${place.name} in Accra on Welcome2GH!\n${place.address}'),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.share_rounded, color: AppColors.white, size: 20),
                ),
              ),
              GestureDetector(
                onTap: _toggleSave,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded, color: _saved ? AppColors.yellow : AppColors.white),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(url: place.imageUrl, fit: BoxFit.cover, fallbackIcon: Icons.place),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppColors.navy]))),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.yellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3))), child: Text(place.category.toUpperCase(), style: const TextStyle(color: AppColors.yellow, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1))),
                    const SizedBox(width: 8),
                    if (place.verified) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.green.withValues(alpha: 0.3))), child: Row(children: [Icon(Icons.verified_rounded, color: AppColors.green, size: 10), SizedBox(width: 4), Text('VERIFIED', style: TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1))])),
                  ]),
                  const SizedBox(height: 12),
                  Text(place.name, style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 6),
                  Row(children: [const Icon(Icons.location_on_rounded, color: AppColors.yellow, size: 14), const SizedBox(width: 4), Expanded(child: Text(place.address, style: Theme.of(context).textTheme.bodyMedium))]),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.star_rounded, color: AppColors.yellow, size: 16),
                    const SizedBox(width: 4),
                    Text('${place.rating}', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(width: 4),
                    Text('(${place.reviewCount} reviews)', style: Theme.of(context).textTheme.bodyMedium),
                    const Spacer(),
                    Text(place.priceLevel, style: const TextStyle(color: AppColors.yellow, fontWeight: FontWeight.w700, fontSize: 15)),
                  ]),
                  const SizedBox(height: 24),
                  Text('ENVIRONMENTAL INTELLIGENCE', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _ScoreCard(label: 'Safety', value: place.safetyScore, icon: Icons.shield_rounded, color: AppColors.green)),
                    const SizedBox(width: 10),
                    Expanded(child: _ScoreCard(label: 'Crowd', value: place.crowdLevel, icon: Icons.people_rounded, color: AppColors.yellow)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _ScoreCard(label: 'Air Quality', value: place.airQuality, icon: Icons.air_rounded, color: const Color(0xFF00BCD4))),
                    const SizedBox(width: 10),
                    Expanded(child: _ScoreCard(label: 'Noise', value: place.noiseLevel, icon: Icons.volume_up_rounded, color: const Color(0xFFFF7043))),
                  ]),
                  const SizedBox(height: 24),
                  Text('ABOUT', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 10),
                  Text(place.description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7)),
                  const SizedBox(height: 24),
                  Wrap(spacing: 8, runSpacing: 8, children: place.tags.map((t) => Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder)), child: Text(t, style: TextStyle(color: AppColors.greyLight, fontSize: 12)))).toList()),
                  if (place.openingHours != null || place.contactPhone != null || place.website != null) ...[
                    const SizedBox(height: 24),
                    Text('INFORMATION', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 10),
                    if (place.openingHours != null)
                      _InfoRow(icon: Icons.schedule_rounded, label: place.openingHours!),
                    if (place.contactPhone != null)
                      _InfoRow(icon: Icons.phone_rounded, label: place.contactPhone!, onTap: () => _dial(place.contactPhone!)),
                    if (place.website != null)
                      _InfoRow(icon: Icons.public_rounded, label: place.website!),
                  ],
                  const SizedBox(height: 28),
                  Text('DIRECTIONS', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  Text('See the route, distance, ETA and estimated fare — all inside the app.', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _openDirections, icon: const Icon(Icons.navigation_rounded, size: 16), label: const Text('GET DIRECTIONS'))),
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('WHAT PEOPLE SAY', style: Theme.of(context).textTheme.labelSmall),
                    TextButton(onPressed: _openReviewSheet, child: const Text('WRITE A REVIEW →', style: TextStyle(color: AppColors.yellow, fontSize: 11))),
                  ]),
                  const SizedBox(height: 12),
                  if (_reviews.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
                      child: Column(children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: AppColors.grey, size: 32),
                        SizedBox(height: 8),
                        Text('No reviews yet — be the first!', style: TextStyle(color: AppColors.grey, fontSize: 13)),
                      ]),
                    )
                  else
                    ..._reviews.map((r) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _ReviewCard(review: r))),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  const _ScoreCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: color, size: 16), const Spacer(), Text(value.toStringAsFixed(1), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18))]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: value / 10, backgroundColor: color.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(color), minHeight: 4)),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  const _ReviewCard({required this.review});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AppImage(url: review.userAvatar, width: 32, height: 32, borderRadius: BorderRadius.circular(16), fallbackIcon: Icons.person),
          const SizedBox(width: 10),
          Text(review.userName, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, color: i < review.rating.round() ? AppColors.yellow : AppColors.grey.withValues(alpha: 0.3), size: 12))),
        ]),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(review.comment, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        Text(timeAgo(review.createdAt), style: TextStyle(color: AppColors.grey, fontSize: 10)),
      ]),
    );
  }

}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _InfoRow({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
        child: Row(children: [
          Icon(icon, color: AppColors.yellow, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: AppColors.greyLight, fontSize: 13))),
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: AppColors.grey, size: 16),
        ]),
      ),
    );
  }
}
