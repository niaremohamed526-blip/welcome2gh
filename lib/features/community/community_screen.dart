import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/time_utils.dart';
import '../../core/models.dart';
import '../../core/supabase_service.dart';
import '../../core/image_upload.dart';
import '../../shared/widgets/app_image.dart';

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
                    return const Center(child: CircularProgressIndicator(color: AppColors.yellow));
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
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: posts.length,
                    itemBuilder: (_, i) => _PostCard(post: posts[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewPost(BuildContext context) {
    final ctrl = TextEditingController();
    String category = 'General';
    String? postPhoto;
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
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(hintText: 'What\'s happening in Accra?'),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final url = await ImageUploadHelper.pickAndUpload(ctx, bucket: 'posts');
                  if (url != null) setSh(() => postPhoto = url);
                },
                child: Container(
                  height: postPhoto != null ? 140 : 48,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                    image: postPhoto != null ? DecorationImage(image: NetworkImage(postPhoto!), fit: BoxFit.cover) : null,
                  ),
                  child: postPhoto == null
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
                    final text = ctrl.text.trim();
                    if (text.isEmpty) return;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    try {
                      await SupabaseService.instance.createPost(content: text, category: category, imageUrl: postPhoto);
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
  const _PostCard({required this.post});
  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _liked = false;
  late int _likeCount;
  late int _commentCount;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likes;
    _commentCount = widget.post.comments;
    _checkLiked();
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
    switch (widget.post.category) {
      case 'Safety': return const Color(0xFFEF5350);
      case 'Food': return const Color(0xFF66BB6A);
      case 'Transport': return const Color(0xFF00BCD4);
      case 'Scam alert':
      case 'Scam Alert':
        return const Color(0xFFFF7043);
      default: return AppColors.yellow;
    }
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
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: Text(p.content, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6, fontSize: 14))),
        if (p.imageUrl != null) AppImage(url: p.imageUrl!, height: 180, width: double.infinity),
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
              onTap: () => Share.share('${p.authorName} on Welcome2GH:\n\n${p.content}'),
              child: Icon(Icons.share_outlined, color: AppColors.grey, size: 18),
            ),
          ]),
        ),
      ]),
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
