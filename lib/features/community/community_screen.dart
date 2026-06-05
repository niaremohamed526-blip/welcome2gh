import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/time_utils.dart';
import '../../core/models.dart';
import '../../core/supabase_service.dart';
import '../../core/image_upload.dart';
import '../../shared/widgets/app_image.dart';
import '../notifications/notifications_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Safety', 'Food', 'Transport', 'Accommodation', 'Events', 'Scam Alert', 'Student Life'];

  Stream<List<CommunityPost>>? _stream;

  @override
  void initState() {
    super.initState();
    _stream = SupabaseService.instance.watchPosts();
  }

  List<CommunityPost> _applyFilter(List<CommunityPost> posts) {
    if (_filter == 'All') return posts;
    final filterKey = _filter.toLowerCase().replaceAll(' ', '_');
    return posts.where((p) => p.category.toLowerCase() == filterKey).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('COMMUNITY', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text('THE FEED.', style: Theme.of(context).textTheme.displaySmall),
                  ]),
                  const Spacer(),
                  const _NotificationBell(),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _stream = SupabaseService.instance.watchPosts()),
                    child: Container(
                      width: 36, height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
                      child: Icon(Icons.refresh_rounded, color: AppColors.grey, size: 18),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showNewPost(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('POST'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _filters.map((f) {
                  final active = f == _filter;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: active ? AppColors.yellow : AppColors.navyCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? AppColors.yellow : AppColors.cardBorder)),
                      child: Text(f, style: TextStyle(color: active ? AppColors.navy : AppColors.grey, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<CommunityPost>>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: const [_PostSkeleton(), _PostSkeleton(), _PostSkeleton()],
                    );
                  }
                  if (snap.hasError) {
                    return Center(child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Could not load posts: ${snap.error}', style: const TextStyle(color: AppColors.red), textAlign: TextAlign.center),
                    ));
                  }
                  final posts = _applyFilter(snap.data ?? []);
                  if (posts.isEmpty) {
                    return Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: AppColors.grey.withValues(alpha: 0.4), size: 56),
                        const SizedBox(height: 12),
                        Text('No posts yet. Be the first!', style: TextStyle(color: AppColors.grey)),
                      ],
                    ));
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() => _stream = SupabaseService.instance.watchPosts());
                      await Future.delayed(const Duration(milliseconds: 400));
                    },
                    color: AppColors.yellow,
                    backgroundColor: AppColors.navyCard,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: posts.length,
                      itemBuilder: (_, i) => _PostCard(key: ValueKey(posts[i].id), post: posts[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaPickBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppColors.grey, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: AppColors.grey, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _removeMediaBtn(VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: const Icon(Icons.close, color: Colors.white, size: 16),
        ),
      );

  void _showNewPost(BuildContext context) {
    final ctrl = TextEditingController();
    String category = 'General';
    String? postPhoto;
    String? postVideo;
    final cats = ['General', 'Safety', 'Food', 'Transport', 'Accommodation', 'Events', 'Scam Alert', 'Student Life'];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setSh) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NEW POST', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Text('Share with the community', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: cats.map((c) {
                    final active = c == category;
                    return GestureDetector(
                      onTap: () => setSh(() => category = c),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: active ? AppColors.yellow : AppColors.navy, borderRadius: BorderRadius.circular(8), border: Border.all(color: active ? AppColors.yellow : AppColors.cardBorder)),
                        child: Text(c, style: TextStyle(color: active ? AppColors.navy : AppColors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                maxLines: 5,
                maxLength: 500,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(hintText: 'What\'s happening in Accra?'),
              ),
              const SizedBox(height: 12),
              if (postPhoto != null)
                Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(postPhoto!, height: 140, width: double.infinity, fit: BoxFit.cover)),
                  Positioned(top: 6, right: 6, child: _removeMediaBtn(() => setSh(() => postPhoto = null))),
                ])
              else if (postVideo != null)
                Stack(children: [
                  Container(
                    height: 90, width: double.infinity,
                    decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.videocam_rounded, color: AppColors.yellow, size: 20),
                      const SizedBox(width: 8),
                      Text('Video attached', style: TextStyle(color: AppColors.greyLight, fontSize: 13)),
                    ]),
                  ),
                  Positioned(top: 6, right: 6, child: _removeMediaBtn(() => setSh(() => postVideo = null))),
                ])
              else
                Row(children: [
                  Expanded(child: _mediaPickBtn(icon: Icons.add_a_photo_rounded, label: 'Photo', onTap: () async {
                    final url = await ImageUploadHelper.pickAndUpload(ctx, bucket: 'posts');
                    if (url != null) setSh(() { postPhoto = url; postVideo = null; });
                  })),
                  const SizedBox(width: 10),
                  Expanded(child: _mediaPickBtn(icon: Icons.videocam_rounded, label: 'Video', onTap: () async {
                    final url = await ImageUploadHelper.pickAndUploadVideo(ctx, bucket: 'posts');
                    if (url != null) setSh(() { postVideo = url; postPhoto = null; });
                  })),
                ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) return;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    try {
                      await SupabaseService.instance.createPost(content: text, category: category, imageUrl: postPhoto, videoUrl: postVideo);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Post shared!'), backgroundColor: AppColors.green),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red),
                      );
                    }
                  },
                  child: const Text('SHARE POST'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }
}

class _PostCard extends StatefulWidget {
  final CommunityPost post;
  const _PostCard({super.key, required this.post});
  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _liked = false;
  bool _favorited = false;
  bool _showHeartBurst = false;
  late int _likeCount;
  late int _commentCount;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likes;
    _commentCount = widget.post.comments;
    _checkLiked();
    _checkFavorited();
  }

  Future<void> _checkFavorited() async {
    final fav = await SupabaseService.instance.isPostFavorited(widget.post.id);
    if (mounted && fav != _favorited) setState(() => _favorited = fav);
  }

  bool get _isMine => widget.post.authorId != null && widget.post.authorId == SupabaseService.instance.currentUser?.id;

  Future<void> _toggleFavorite() async {
    setState(() => _favorited = !_favorited); // optimistic
    try {
      final now = await SupabaseService.instance.togglePostFavorite(widget.post.id);
      if (mounted && now != _favorited) setState(() => _favorited = now);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_favorited ? 'Saved to your posts' : 'Removed from saved'),
          backgroundColor: AppColors.navyCard,
          duration: const Duration(seconds: 1),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _favorited = !_favorited);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red));
    }
  }

  Future<void> _confirmDelete() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.navyCard,
        title: Text('Delete post?', style: TextStyle(color: AppColors.white)),
        content: Text('This removes your post from the feed.', style: TextStyle(color: AppColors.greyLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('CANCEL', style: TextStyle(color: AppColors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.instance.deleteMyPost(widget.post.id);
      messenger.showSnackBar(const SnackBar(content: Text('Post deleted'), backgroundColor: AppColors.green));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red));
    }
  }

  Future<void> _reportPost() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.navyCard,
        title: Text('Report this post?', style: TextStyle(color: AppColors.white)),
        content: Text('Our team will review it for violating community guidelines.', style: TextStyle(color: AppColors.greyLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('CANCEL', style: TextStyle(color: AppColors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('REPORT')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.instance.reportPost(widget.post.id);
      messenger.showSnackBar(const SnackBar(content: Text('Thanks — post reported'), backgroundColor: AppColors.green));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red));
    }
  }

  @override
  void didUpdateWidget(covariant _PostCard old) {
    super.didUpdateWidget(old);
    // Keep counts in sync with realtime updates, but never below our optimistic value.
    if (widget.post.likes > _likeCount) _likeCount = widget.post.likes;
    if (widget.post.comments > _commentCount) _commentCount = widget.post.comments;
  }

  Future<void> _checkLiked() async {
    final liked = await SupabaseService.instance.isPostLiked(widget.post.id);
    if (mounted && liked != _liked) setState(() => _liked = liked);
  }

  Color get _categoryColor {
    switch (widget.post.category.toLowerCase()) {
      case 'safety': return const Color(0xFFEF5350);
      case 'food': return const Color(0xFF66BB6A);
      case 'transport': return const Color(0xFF00BCD4);
      case 'scam alert': return const Color(0xFFFF7043);
      case 'accommodation': return const Color(0xFF26A69A);
      case 'events': return const Color(0xFFAB47BC);
      case 'student life': return const Color(0xFF7C4DFF);
      default: return AppColors.yellow;
    }
  }

  void _onDoubleTapLike() {
    if (!_liked) _toggleLike(); // double-tap only ever likes, never unlikes
    setState(() => _showHeartBurst = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeartBurst = false);
    });
  }

  Future<void> _toggleLike() async {
    // Optimistic: flip heart AND count instantly.
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });
    try {
      await SupabaseService.instance.togglePostLike(widget.post.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = !_liked;
        _likeCount += _liked ? 1 : -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            AppImage(url: p.authorAvatar, width: 36, height: 36, borderRadius: BorderRadius.circular(18), fallbackIcon: Icons.person),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.authorName, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              Text(timeAgo(p.createdAt), style: TextStyle(color: AppColors.grey, fontSize: 11)),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _categoryColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: _categoryColor.withValues(alpha: 0.3))),
              child: Text(p.category.toUpperCase(), style: TextStyle(color: _categoryColor, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
            _postMenu(),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: Text(p.content, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6, fontSize: 14))),
        if (p.hasVideo)
          _PostVideo(url: p.videoUrl!)
        else if (p.imageUrl != null)
          GestureDetector(
            onTap: () => _openImageViewer(context, p.imageUrl!),
            onDoubleTap: _onDoubleTapLike,
            child: Stack(alignment: Alignment.center, children: [
              Stack(alignment: Alignment.bottomRight, children: [
                AppImage(url: p.imageUrl!, height: 180, width: double.infinity),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ]),
              // Instagram-style heart pop on double-tap
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _showHeartBurst ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: AnimatedScale(
                    scale: _showHeartBurst ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    child: Icon(Icons.favorite_rounded, color: Colors.white.withValues(alpha: 0.92), size: 96),
                  ),
                ),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            GestureDetector(
              onTap: _toggleLike,
              child: Row(children: [
                AnimatedScale(
                  scale: _liked ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutBack,
                  child: Icon(_liked ? Icons.favorite_rounded : Icons.favorite_outline_rounded, color: _liked ? Color(0xFFEF5350) : AppColors.grey, size: 18),
                ),
                const SizedBox(width: 5),
                Text('$_likeCount', style: TextStyle(color: AppColors.grey, fontSize: 13)),
              ]),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () => _openComments(context),
              child: Row(children: [Icon(Icons.chat_bubble_outline_rounded, color: AppColors.grey, size: 18), SizedBox(width: 5), Text('$_commentCount', style: TextStyle(color: AppColors.grey, fontSize: 13))]),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _toggleFavorite,
              child: Icon(_favorited ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded, color: _favorited ? AppColors.yellow : AppColors.grey, size: 18),
            ),
            const SizedBox(width: 18),
            GestureDetector(
              onTap: () => Share.share('${p.authorName} on Welcome2GH:\n\n${p.content}'),
              child: Icon(Icons.share_outlined, color: AppColors.grey, size: 18),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _postMenu() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: AppColors.grey, size: 18),
      color: AppColors.navyCard,
      padding: EdgeInsets.zero,
      onSelected: (v) {
        if (v == 'delete') _confirmDelete();
        if (v == 'report') _reportPost();
      },
      itemBuilder: (_) => [
        if (_isMine)
          PopupMenuItem(value: 'delete', child: Row(children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 18),
            const SizedBox(width: 10),
            Text('Delete post', style: TextStyle(color: AppColors.white)),
          ]))
        else
          PopupMenuItem(value: 'report', child: Row(children: [
            Icon(Icons.flag_outlined, color: AppColors.grey, size: 18),
            const SizedBox(width: 10),
            Text('Report post', style: TextStyle(color: AppColors.white)),
          ])),
      ],
    );
  }


  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CommentsSheet(
        postId: widget.post.id,
        onCommentAdded: () { if (mounted) setState(() => _commentCount++); },
      ),
    );
  }
}

/// Opens a tappable image full-screen with pinch-to-zoom.
void _openImageViewer(BuildContext context, String url) {
  Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.black,
    pageBuilder: (_, __, ___) => _ImageViewer(url: url),
    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
  ));
}

class _ImageViewer extends StatelessWidget {
  final String url;
  const _ImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (c, w, prog) => prog == null
                      ? w
                      : const Center(child: CircularProgressIndicator(color: AppColors.yellow)),
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 56),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Placeholder card shown while the feed loads.
class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  Widget _bar(double w, double h) => Container(
        width: w, height: h,
        decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(6)),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.navy, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bar(110, 11),
            const SizedBox(height: 6),
            _bar(60, 9),
          ]),
        ]),
        const SizedBox(height: 14),
        _bar(double.infinity, 11),
        const SizedBox(height: 8),
        _bar(220, 11),
        const SizedBox(height: 14),
        Container(height: 120, decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(10))),
      ]),
    );
  }
}

/// Inline video player for a post — tap to play/pause, scrubbable progress.
class _PostVideo extends StatefulWidget {
  final String url;
  const _PostVideo({required this.url});

  @override
  State<_PostVideo> createState() => _PostVideoState();
}

class _PostVideoState extends State<_PostVideo> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _ctrl = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    if (_failed) {
      // Inline playback can fail on web for some formats (e.g. iPhone .mov /
      // HEVC). Offer to open the video directly in the browser as a fallback.
      return Container(
        height: 180, color: AppColors.navy,
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.smart_display_outlined, color: AppColors.grey, size: 30),
          const SizedBox(height: 8),
          Text("Can't preview this video here", style: TextStyle(color: AppColors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(10)),
              child: Text('OPEN VIDEO', style: TextStyle(color: AppColors.navy, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ])),
      );
    }
    if (!_ready || c == null || !c.value.isInitialized) {
      return Container(height: 200, color: AppColors.navy, child: const Center(child: CircularProgressIndicator(color: AppColors.yellow)));
    }
    final ar = c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio;
    return GestureDetector(
      onTap: _toggle,
      child: Stack(alignment: Alignment.center, children: [
        AspectRatio(aspectRatio: ar, child: VideoPlayer(c)),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: c,
          builder: (_, value, __) => value.isPlaying
              ? const SizedBox.shrink()
              : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                ),
        ),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: VideoProgressIndicator(c, allowScrubbing: true,
              colors: VideoProgressColors(playedColor: AppColors.yellow, bufferedColor: Colors.white24, backgroundColor: Colors.white10)),
        ),
      ]),
    );
  }
}

/// Bell icon with a live unread badge; opens the Notifications screen.
class _NotificationBell extends StatefulWidget {
  const _NotificationBell();

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  // Cache the stream so we don't open a new realtime channel on every rebuild.
  late final Stream<List<Map<String, dynamic>>> _stream =
      SupabaseService.instance.watchNotifications();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final unread = (snap.data ?? []).where((n) => n['read'] != true).length;
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
            child: Stack(alignment: Alignment.center, children: [
              Icon(Icons.notifications_none_rounded, color: AppColors.grey, size: 18),
              if (unread > 0)
                Positioned(
                  top: 5, right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    decoration: const BoxDecoration(color: Color(0xFFEF5350), shape: BoxShape.circle),
                    child: Text(unread > 9 ? '9+' : '$unread', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final String postId;
  final VoidCallback? onCommentAdded;
  const _CommentsSheet({required this.postId, this.onCommentAdded});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await SupabaseService.instance.getPostComments(widget.postId);
      if (mounted) setState(() { _comments = list; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load comments: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      await SupabaseService.instance.addPostComment(postId: widget.postId, content: text);
      _ctrl.clear();
      widget.onCommentAdded?.call();
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('COMMENTS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
                : _comments.isEmpty
                    ? Center(child: Text('No comments yet. Be the first!', style: TextStyle(color: AppColors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _comments.length,
                        itemBuilder: (_, i) {
                          final c = _comments[i];
                          final prof = c['profiles'] as Map<String, dynamic>?;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              AppImage(
                                url: prof?['profile_image'] ?? 'https://i.pravatar.cc/100?u=${c['user_id']}',
                                width: 32, height: 32,
                                borderRadius: BorderRadius.circular(16),
                                fallbackIcon: Icons.person,
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(prof?['name'] ?? 'Anonymous', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 3),
                                Text(c['content'] ?? '', style: TextStyle(color: AppColors.greyLight, fontSize: 13)),
                              ])),
                            ]),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.cardBorder))),
            child: SafeArea(
              top: false,
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _ctrl,
                  style: TextStyle(color: AppColors.white),
                  decoration: InputDecoration(hintText: 'Add a comment...', contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _posting ? null : _post,
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(12)),
                    child: _posting
                        ? Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                        : Icon(Icons.send_rounded, color: AppColors.navy, size: 18),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
