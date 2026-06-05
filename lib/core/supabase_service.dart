import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

/// Single point of contact with Supabase backend.
/// All screens go through this — no direct SDK calls elsewhere.
class SupabaseService {
  SupabaseService._();
  static final instance = SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;
  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;

  // ─── AUTH ──────────────────────────────────────────────────────────────

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'tourist',
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'role': role},
    );
    // Defensive: ensure profile row exists even if trigger lags
    if (response.user != null) {
      try {
        await _client.from('profiles').upsert({
          'id': response.user!.id,
          'name': name,
          'email': email,
          'role': role,
        }, onConflict: 'id');
      } catch (_) {/* trigger may have already run */}
    }
    return response;
  }

  Future<AuthResponse> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(email: email, password: password);
    // Defensive: if for any reason profile is missing, create it
    if (response.user != null) {
      final existing = await _client.from('profiles').select('id').eq('id', response.user!.id).maybeSingle();
      if (existing == null) {
        await _client.from('profiles').insert({
          'id': response.user!.id,
          'name': response.user!.userMetadata?['name'] ?? email.split('@').first,
          'email': email,
          'role': response.user!.userMetadata?['role'] ?? 'tourist',
        });
      }
    }
    return response;
  }

  Future<void> signOut() => _client.auth.signOut(scope: SignOutScope.local);

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Signs in with Google via Supabase OAuth.
  /// On web: opens Google consent screen in the same tab/popup.
  /// On mobile: opens a browser and handles the redirect automatically.
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.welcome2gh://login-callback/',
    );
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ─── PROFILE ───────────────────────────────────────────────────────────

  Future<UserProfile?> getMyProfile() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      var row = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      // Self-heal: profile missing → create it from auth metadata
      if (row == null) {
        await _client.from('profiles').insert({
          'id': user.id,
          'name': user.userMetadata?['name'] ?? user.email?.split('@').first ?? 'New User',
          'email': user.email,
          'role': user.userMetadata?['role'] ?? 'tourist',
        });
        row = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
      }
      return row == null ? null : UserProfile.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile({String? name, String? nationality, String? profileImage}) async {
    final id = currentUser?.id;
    if (id == null) return;
    final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (name != null) updates['name'] = name;
    if (nationality != null) updates['nationality'] = nationality;
    if (profileImage != null) updates['profile_image'] = profileImage;
    await _client.from('profiles').update(updates).eq('id', id);
  }

  // ─── PLACES ────────────────────────────────────────────────────────────

  Future<List<Place>> getPlaces({
    String? category,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client.from('places').select().eq('active', true);
    if (category != null && category.toLowerCase() != 'all') {
      query = query.eq('category', category.toLowerCase());
    }
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('name', '%${search.trim()}%');
    }
    final rows = await query
        .order('rating', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List).map((r) => Place.fromJson(r)).toList();
  }

  Future<Place?> getPlace(String id) async {
    final row = await _client.from('places').select().eq('id', id).eq('active', true).maybeSingle();
    return row == null ? null : Place.fromJson(row);
  }

  Future<List<Place>> getNearbyPlaces({
    required double lat,
    required double lng,
    int radiusM = 5000,
    String? category,
  }) async {
    final params = {
      'user_lat': lat,
      'user_lng': lng,
      'radius_m': radiusM,
      'category_filter': category?.toLowerCase(),
    };
    final rows = await _client.rpc('nearby_places', params: params);
    return (rows as List).map((r) => Place.fromJson(r)).toList();
  }

  // ─── REVIEWS ───────────────────────────────────────────────────────────

  Future<List<Review>> getReviews(String placeId) async {
    final rows = await _client
        .from('reviews')
        .select('*, profiles:user_id(name, profile_image)')
        .eq('place_id', placeId)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List).map((r) => Review.fromJson(r)).toList();
  }

  Future<void> postReview({
    required String placeId,
    required double rating,
    required String comment,
    List<String>? images,
  }) async {
    final id = currentUser?.id;
    if (id == null) throw Exception('Sign in to leave a review');
    await _client.from('reviews').upsert({
      'place_id': placeId,
      'user_id': id,
      'rating': rating,
      'comment': comment,
      if (images != null) 'images': images,
    });
  }

  // ─── FAVORITES ─────────────────────────────────────────────────────────

  Future<List<Place>> getFavorites() async {
    final id = currentUser?.id;
    if (id == null) return [];
    final rows = await _client
        .from('favorites')
        .select('place_id, places(*)')
        .eq('user_id', id)
        .order('created_at', ascending: false);
    // Skip favourites whose place was removed/deactivated — RLS returns a null
    // embed for those, which would otherwise crash the Saved screen.
    return (rows as List)
        .where((r) => r['places'] != null)
        .map((r) => Place.fromJson(r['places'] as Map<String, dynamic>))
        .toList();
  }

  /// Returns counts of the current user's content: posts, reviews, favorites.
  Future<Map<String, int>> getMyStats() async {
    final id = currentUser?.id;
    if (id == null) return {'posts': 0, 'reviews': 0, 'favorites': 0};
    try {
      final results = await Future.wait([
        _client.from('posts').select('id').eq('author_id', id).eq('active', true),
        _client.from('reviews').select('id').eq('user_id', id),
        _client.from('favorites').select('place_id').eq('user_id', id),
      ]);
      return {
        'posts': (results[0] as List).length,
        'reviews': (results[1] as List).length,
        'favorites': (results[2] as List).length,
      };
    } catch (_) {
      return {'posts': 0, 'reviews': 0, 'favorites': 0};
    }
  }

  Future<Set<String>> getFavoriteIds() async {
    final id = currentUser?.id;
    if (id == null) return {};
    final rows = await _client.from('favorites').select('place_id').eq('user_id', id);
    return (rows as List).map<String>((r) => r['place_id'].toString()).toSet();
  }

  Future<void> toggleFavorite(String placeId) async {
    final id = currentUser?.id;
    if (id == null) throw Exception('Sign in to save places');
    final existing = await _client
        .from('favorites')
        .select()
        .eq('user_id', id)
        .eq('place_id', placeId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('favorites').insert({'user_id': id, 'place_id': placeId});
    } else {
      await _client.from('favorites').delete().eq('user_id', id).eq('place_id', placeId);
    }
  }

  // ─── COMMUNITY POSTS ───────────────────────────────────────────────────

  Future<List<CommunityPost>> getPosts({String? category}) async {
    var q = _client
        .from('posts')
        .select('*, profiles:author_id(name, profile_image)')
        .eq('active', true);
    if (category != null && category.toLowerCase() != 'all') {
      q = q.eq('category', category.toLowerCase().replaceAll(' ', '_'));
    }
    final rows = await q.order('created_at', ascending: false).limit(50);
    return (rows as List).map((r) => CommunityPost.fromJson(r)).toList();
  }

  Stream<List<CommunityPost>> watchPosts() {
    return _client
        .from('posts')
        .stream(primaryKey: ['id'])
        .eq('active', true)
        .order('created_at', ascending: false)
        .limit(50)
        .asyncMap((rows) async {
      // hydrate author info
      final authorIds = rows
          .map((r) => r['author_id']?.toString())
          .where((id) => id != null)
          .toSet()
          .toList();
      if (authorIds.isEmpty) {
        return rows.map((r) => CommunityPost.fromJson(r)).toList();
      }
      final profiles = await _client
          .from('profiles')
          .select('id, name, profile_image')
          .inFilter('id', authorIds);
      final map = {for (final p in (profiles as List)) p['id'].toString(): p};
      return rows.map((r) {
        final merged = Map<String, dynamic>.from(r);
        merged['profiles'] = map[r['author_id']?.toString()];
        return CommunityPost.fromJson(merged);
      }).toList();
    });
  }

  Future<void> createPost({
    required String content,
    String category = 'general',
    String? imageUrl,
    String? videoUrl,
  }) async {
    final id = currentUser?.id;
    if (id == null) throw Exception('Sign in to post');
    await _client.from('posts').insert({
      'author_id': id,
      'content': content,
      'category': category.toLowerCase().replaceAll(' ', '_'),
      'image_url': imageUrl,
      'video_url': videoUrl,
      'media_type': videoUrl != null ? 'video' : 'image',
    });
  }

  /// Soft-delete the current user's own post (RLS allows the author).
  Future<void> deleteMyPost(String postId) async {
    await _client.from('posts').update({'active': false}).eq('id', postId);
  }

  Future<void> reportPost(String postId, {String? reason}) async {
    final id = currentUser?.id;
    if (id == null) throw Exception('Sign in to report');
    await _client.from('post_reports').insert({
      'post_id': postId,
      'reporter_id': id,
      'reason': reason,
    });
  }

  // ─── POST FAVORITES ─────────────────────────────────────────────────────

  Future<bool> isPostFavorited(String postId) async {
    final id = currentUser?.id;
    if (id == null) return false;
    final row = await _client
        .from('post_favorites')
        .select()
        .eq('post_id', postId)
        .eq('user_id', id)
        .maybeSingle();
    return row != null;
  }

  /// Toggles favourite; returns the new state (true = now favourited).
  Future<bool> togglePostFavorite(String postId) async {
    final id = currentUser?.id;
    if (id == null) throw Exception('Sign in to save posts');
    final existing = await _client
        .from('post_favorites')
        .select()
        .eq('post_id', postId)
        .eq('user_id', id)
        .maybeSingle();
    if (existing == null) {
      await _client.from('post_favorites').insert({'post_id': postId, 'user_id': id});
      return true;
    }
    await _client.from('post_favorites').delete().eq('post_id', postId).eq('user_id', id);
    return false;
  }

  Future<List<CommunityPost>> getFavoritePosts() async {
    final id = currentUser?.id;
    if (id == null) return [];
    final rows = await _client
        .from('post_favorites')
        .select('post:post_id(*, profiles:author_id(name, profile_image))')
        .eq('user_id', id)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => r['post'])
        .where((p) => p != null && p['active'] == true)
        .map((p) => CommunityPost.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<bool> isPostLiked(String postId) async {
    final id = currentUser?.id;
    if (id == null) return false;
    final row = await _client
        .from('post_likes')
        .select()
        .eq('post_id', postId)
        .eq('user_id', id)
        .maybeSingle();
    return row != null;
  }

  Future<void> togglePostLike(String postId) async {
    final id = currentUser?.id;
    if (id == null) throw Exception('Sign in to like posts');
    final existing = await _client
        .from('post_likes')
        .select()
        .eq('post_id', postId)
        .eq('user_id', id)
        .maybeSingle();
    if (existing == null) {
      await _client.from('post_likes').insert({'post_id': postId, 'user_id': id});
    } else {
      await _client.from('post_likes').delete().eq('post_id', postId).eq('user_id', id);
    }
  }

  // ─── ALERTS ────────────────────────────────────────────────────────────

  Future<List<AlertItem>> getActiveAlerts() async {
    final rows = await _client
        .from('alerts')
        .select()
        .eq('active', true)
        .order('created_at', ascending: false)
        .limit(20);
    // Drop alerts whose expiry has passed — matches the DB's nearby_alerts()
    // function, which also excludes expired alerts.
    return (rows as List)
        .map((r) => AlertItem.fromJson(r))
        .where((a) => !a.isExpired)
        .toList();
  }

  Stream<List<AlertItem>> watchAlerts() {
    return _client
        .from('alerts')
        .stream(primaryKey: ['id'])
        .eq('active', true)
        .order('created_at', ascending: false)
        .limit(20)
        .map((rows) => rows.map((r) => AlertItem.fromJson(r)).toList());
  }

  // ─── FAIR PRICES ───────────────────────────────────────────────────────

  Future<List<FairPrice>> getFairPrices({String? serviceType}) async {
    var q = _client.from('fair_prices').select();
    if (serviceType != null) q = q.eq('service_type', serviceType);
    final rows = await q.order('verified', ascending: false).limit(50);
    return (rows as List).map((r) => FairPrice.fromJson(r)).toList();
  }

  /// Lets any signed-in user report a safety issue (creates an alert,
  /// pending admin verification). RLS allows authenticated inserts.
  Future<void> reportSafetyIssue({
    required String type,
    required String title,
    required String description,
    double? lat,
    double? lng,
  }) async {
    final id = currentUser?.id;
    if (id == null) throw Exception('Sign in to report a safety issue');
    await _client.from('alerts').insert({
      'alert_type': type,
      'severity': 'medium',
      'title': title,
      'description': description,
      'lat': lat,
      'lng': lng,
      'radius_meters': 800,
      'created_by': id,
    });
  }

  Future<void> reportFairPrice({
    required String serviceType,
    String? itemName,
    String? routeFrom,
    String? routeTo,
    required double amountGhs,
    String? notes,
  }) async {
    final id = currentUser?.id;
    if (id == null) throw Exception('Sign in to report prices');
    await _client.from('fair_prices').insert({
      'service_type': serviceType,
      'item_name': itemName,
      'route_from': routeFrom,
      'route_to': routeTo,
      'amount_ghs': amountGhs,
      'notes': notes,
      'reported_by': id,
    });
  }

  // ─── POST COMMENTS ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPostComments(String postId) async {
    final rows = await _client
        .from('post_comments')
        .select('*, profiles:user_id(name, profile_image)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> addPostComment({required String postId, required String content}) async {
    final id = currentUser?.id;
    if (id == null) throw Exception('Sign in to comment');
    await _client.from('post_comments').insert({
      'post_id': postId,
      'user_id': id,
      'content': content,
    });
  }

  // ─── ADD A PLACE ───────────────────────────────────────────────────────

  Future<String> addPlace({
    required String name,
    required String category,
    required String description,
    required String address,
    required double lat,
    required double lng,
    String priceLevel = '\$\$',
    String? imageUrl,
    List<String>? tags,
  }) async {
    final id = currentUser?.id;
    if (id == null) throw Exception('Sign in to add a place');
    final row = await _client.from('places').insert({
      'name': name,
      'category': category.toLowerCase(),
      'description': description,
      'address': address,
      'lat': lat,
      'lng': lng,
      'price_level': priceLevel,
      'image_url': imageUrl,
      'tags': tags ?? [],
      'created_by': id,
    }).select().single();
    return row['id'].toString();
  }

  // ─── NOTIFICATIONS ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final id = currentUser?.id;
    if (id == null) return [];
    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', id)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> markNotificationRead(String id) async {
    await _client.from('notifications').update({'read': true}).eq('id', id);
  }

  Future<void> markAllNotificationsRead() async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _client.from('notifications').update({'read': true}).eq('user_id', uid).eq('read', false);
  }

  /// Live stream of the current user's notifications (realtime).
  Stream<List<Map<String, dynamic>>> watchNotifications() {
    final uid = currentUser?.id;
    if (uid == null) return Stream.value(const []);
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  Future<int> getUnreadNotificationCount() async {
    final uid = currentUser?.id;
    if (uid == null) return 0;
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', uid)
        .eq('read', false);
    return (rows as List).length;
  }

  // ─── APP SETTINGS (admin-managed hero) ──────────────────────────────────

  /// Default hero used if the DB row is missing or unreachable.
  static const defaultHero = {
    'title': 'YOUR NEW\nPLAYGROUND.',
    'subtitle': 'ACCRA, A CITY ALIVE',
    'image_url': 'https://images.unsplash.com/photo-1535320485706-44d43b919500?w=900&q=80',
    'cta_text': 'OPEN THE MAP',
    'cta_route': '/map',
  };

  Future<Map<String, String>> getHeroConfig() async {
    try {
      final row = await _client.from('app_settings').select('value').eq('key', 'hero').maybeSingle();
      final v = row?['value'] as Map<String, dynamic>?;
      if (v == null) return Map<String, String>.from(defaultHero);
      return {
        'title':     (v['title']     ?? defaultHero['title']).toString(),
        'subtitle':  (v['subtitle']  ?? defaultHero['subtitle']).toString(),
        'image_url': (v['image_url'] ?? defaultHero['image_url']).toString(),
        'cta_text':  (v['cta_text']  ?? defaultHero['cta_text']).toString(),
        'cta_route': (v['cta_route'] ?? defaultHero['cta_route']).toString(),
      };
    } catch (_) {
      return Map<String, String>.from(defaultHero);
    }
  }

  Future<void> updateHeroConfig({
    required String title,
    required String subtitle,
    required String imageUrl,
    required String ctaText,
    required String ctaRoute,
  }) async {
    await _client.from('app_settings').upsert({
      'key': 'hero',
      'value': {
        'title': title,
        'subtitle': subtitle,
        'image_url': imageUrl,
        'cta_text': ctaText,
        'cta_route': ctaRoute,
      },
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ─── AI GUIDE ──────────────────────────────────────────────────────────

  /// Calls the `ai-guide` edge function which proxies to Claude.
  /// [history] is the full conversation as {role, content} maps.
  Future<String> askAiGuide({
    required List<Map<String, String>> history,
    String? role,
    String? nationality,
    double? lat,
    double? lng,
    List<String>? nearbyPlaces,
  }) async {
    final res = await _client.functions.invoke('ai-guide', body: {
      'messages': history,
      if (role != null) 'role': role,
      if (nationality != null) 'nationality': nationality,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (nearbyPlaces != null) 'nearbyPlaces': nearbyPlaces,
    });
    final data = res.data;
    if (data is Map && data['reply'] != null) {
      return data['reply'].toString();
    }
    if (data is Map && data['error'] != null) {
      throw data['error'].toString();
    }
    throw Exception('The AI guide is unavailable right now.');
  }

  // ─── ADMIN ─────────────────────────────────────────────────────────────

  Future<bool> isCurrentUserAdmin() async {
    final p = await getMyProfile();
    return p?.role == 'admin';
  }

  Future<Map<String, dynamic>?> getAdminStats() async {
    try {
      final row = await _client.from('admin_stats').select().maybeSingle();
      return row;
    } catch (_) {
      return null;
    }
  }

  Future<List<UserProfile>> getAllUsers() async {
    final rows = await _client.from('profiles').select().order('created_at', ascending: false).limit(200);
    return (rows as List).map((r) => UserProfile.fromJson(r)).toList();
  }

  Future<void> setUserRole(String userId, String role) async {
    await _client.from('profiles').update({'role': role}).eq('id', userId);
  }

  Future<List<Place>> getAllPlacesForAdmin() async {
    // Only show active places — soft-deleted ones (active = false) should
    // disappear from the admin list just like they do for the public.
    final rows = await _client
        .from('places')
        .select()
        .eq('active', true)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List).map((r) => Place.fromJson(r)).toList();
  }

  Future<void> verifyPlace(String placeId, bool verified) async {
    await _client.from('places').update({'verified': verified}).eq('id', placeId);
  }

  Future<void> deletePlace(String placeId) async {
    await _client.from('places').update({'active': false}).eq('id', placeId);
  }

  /// Admin/owner edit of a place (RLS: places_update_owner_or_admin).
  Future<void> updatePlace(
    String id, {
    required String name,
    required String category,
    required String description,
    required String address,
    required double lat,
    required double lng,
    String priceLevel = '\$\$',
    String? imageUrl,
  }) async {
    await _client.from('places').update({
      'name': name,
      'category': category.toLowerCase(),
      'description': description,
      'address': address,
      'lat': lat,
      'lng': lng,
      'price_level': priceLevel,
      'image_url': imageUrl,
    }).eq('id', id);
  }

  Future<List<Review>> getAllReviews() async {
    final rows = await _client
        .from('reviews')
        .select('*, profiles:user_id(name, profile_image)')
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List).map((r) => Review.fromJson(r)).toList();
  }

  Future<void> deleteReview(String id) async {
    await _client.from('reviews').delete().eq('id', id);
  }

  Future<List<CommunityPost>> getAllPostsForAdmin() async {
    // Only show active posts — soft-deleted ones (active = false) should
    // disappear from the admin list just like they do for the public feed.
    final rows = await _client
        .from('posts')
        .select('*, profiles:author_id(name, profile_image)')
        .eq('active', true)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List).map((r) => CommunityPost.fromJson(r)).toList();
  }

  Future<void> deletePost(String id) async {
    await _client.from('posts').update({'active': false}).eq('id', id);
  }

  /// Admin edit of a post's text/category (needs admin update policy).
  Future<void> updatePost(String id, {required String content, required String category}) async {
    await _client.from('posts').update({
      'content': content,
      'category': category.toLowerCase().replaceAll(' ', '_'),
    }).eq('id', id);
  }

  Future<List<FairPrice>> getAllFairPricesForAdmin() async {
    final rows = await _client.from('fair_prices').select().order('created_at', ascending: false).limit(200);
    return (rows as List).map((r) => FairPrice.fromJson(r)).toList();
  }

  Future<void> verifyFairPrice(String id, bool verified) async {
    await _client.from('fair_prices').update({'verified': verified, 'flagged': false}).eq('id', id);
  }

  Future<void> flagFairPrice(String id) async {
    await _client.from('fair_prices').update({'flagged': true, 'verified': false}).eq('id', id);
  }

  Future<void> deleteFairPrice(String id) async {
    await _client.from('fair_prices').delete().eq('id', id);
  }

  Future<void> updateFairPriceAmount(String id, double amount) async {
    await _client.from('fair_prices').update({'amount_ghs': amount}).eq('id', id);
  }

  Future<List<AlertItem>> getAllAlertsForAdmin() async {
    // Only show active alerts — soft-deleted ones (active = false) should
    // disappear from the admin list just like they do for the public.
    final rows = await _client
        .from('alerts')
        .select()
        .eq('active', true)
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List).map((r) => AlertItem.fromJson(r)).toList();
  }

  Future<void> createAlert({
    required String type,
    required String severity,
    required String title,
    required String description,
    double? lat,
    double? lng,
    int radiusMeters = 1000,
  }) async {
    await _client.from('alerts').insert({
      'alert_type': type,
      'severity': severity,
      'title': title,
      'description': description,
      'lat': lat,
      'lng': lng,
      'radius_meters': radiusMeters,
      'created_by': currentUser?.id,
    });
  }

  Future<void> deactivateAlert(String id) async {
    await _client.from('alerts').update({'active': false}).eq('id', id);
  }

  Future<void> updateAlert(
    String id, {
    required String type,
    required String severity,
    required String title,
    required String description,
    double? lat,
    double? lng,
  }) async {
    await _client.from('alerts').update({
      'alert_type': type,
      'severity': severity,
      'title': title,
      'description': description,
      'lat': lat,
      'lng': lng,
    }).eq('id', id);
  }

  // ─── STORAGE ───────────────────────────────────────────────────────────

  /// Cross-platform image upload (works on web + mobile).
  /// Takes raw bytes so it never depends on dart:io File.
  Future<String> uploadImageBytes({
    required String bucket,
    required Uint8List bytes,
    required String extension,
    String? folder,
  }) async {
    final uid = currentUser?.id ?? 'anon';
    final ext = extension.replaceAll('.', '').toLowerCase();
    final path =
        '${folder == null ? '' : '$folder/'}${uid}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}',
          ),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Upload a video's bytes to [bucket] and return the public URL.
  Future<String> uploadVideoBytes({
    required String bucket,
    required Uint8List bytes,
    String extension = 'mp4',
    String? folder,
  }) async {
    final uid = currentUser?.id ?? 'anon';
    final ext = extension.replaceAll('.', '').toLowerCase();
    final path =
        '${folder == null ? '' : '$folder/'}${uid}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'video/${ext == 'mov' ? 'quicktime' : ext}',
          ),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }
}
