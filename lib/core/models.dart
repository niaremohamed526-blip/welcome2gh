// Domain models for Welcome2GH.
// All models include `fromJson` factories that parse Supabase row data.

class Place {
  final String id;
  final String name;
  final String category;
  final String address;
  final String description;
  final double lat;
  final double lng;
  final double rating;
  final int reviewCount;
  final double safetyScore;
  final double crowdLevel;
  final double airQuality;
  final double noiseLevel;
  final String priceLevel;
  final bool verified;
  final String imageUrl;
  final List<String> tags;
  final String? contactPhone;
  final String? website;
  final String? openingHours;

  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.description,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.reviewCount,
    required this.safetyScore,
    required this.crowdLevel,
    required this.airQuality,
    required this.noiseLevel,
    required this.priceLevel,
    required this.verified,
    required this.imageUrl,
    required this.tags,
    this.contactPhone,
    this.website,
    this.openingHours,
  });

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        id: j['id'].toString(),
        name: j['name'] ?? '',
        category: _capitalize((j['category'] ?? 'other').toString()),
        address: j['address'] ?? '',
        description: j['description'] ?? '',
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
        safetyScore: (j['safety_score'] as num?)?.toDouble() ?? 0,
        crowdLevel: (j['crowd_level'] as num?)?.toDouble() ?? 0,
        airQuality: (j['air_quality'] as num?)?.toDouble() ?? 0,
        noiseLevel: (j['noise_level'] as num?)?.toDouble() ?? 0,
        priceLevel: j['price_level'] ?? '\$\$',
        verified: j['verified'] ?? false,
        imageUrl: j['image_url'] ?? '',
        tags: ((j['tags'] as List?) ?? []).map((e) => e.toString()).toList(),
        contactPhone: j['contact_phone'] as String?,
        website: j['website'] as String?,
        openingHours: _parseHours(j['opening_hours']),
      );

  static String? _parseHours(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw.isEmpty ? null : raw;
    if (raw is Map) {
      // opening_hours stored as jsonb e.g. {"mon":"9-17",...} → join readable
      return raw.entries.map((e) => '${e.key}: ${e.value}').join('  ·  ');
    }
    return raw.toString();
  }
}

class CommunityPost {
  final String id;
  final String authorName;
  final String authorAvatar;
  final String category;
  final String content;
  final String? imageUrl;
  final int likes;
  final int comments;
  final DateTime createdAt;
  final String? authorId;

  const CommunityPost({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.category,
    required this.content,
    this.imageUrl,
    required this.likes,
    required this.comments,
    required this.createdAt,
    this.authorId,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> j) {
    final profile = j['profiles'] as Map<String, dynamic>?;
    return CommunityPost(
      id: j['id'].toString(),
      authorId: j['author_id']?.toString(),
      authorName: profile?['name'] ?? 'Anonymous',
      authorAvatar:
          profile?['profile_image'] ?? 'https://i.pravatar.cc/100?u=${j['author_id']}',
      category: _capitalize((j['category'] ?? 'general').toString().replaceAll('_', ' ')),
      content: j['content'] ?? '',
      imageUrl: j['image_url'],
      likes: (j['likes_count'] as num?)?.toInt() ?? 0,
      comments: (j['comments_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class Review {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> j) {
    final profile = j['profiles'] as Map<String, dynamic>?;
    return Review(
      id: j['id'].toString(),
      userId: j['user_id'].toString(),
      userName: profile?['name'] ?? 'Anonymous',
      userAvatar:
          profile?['profile_image'] ?? 'https://i.pravatar.cc/100?u=${j['user_id']}',
      rating: (j['rating'] as num?)?.toDouble() ?? 0,
      comment: j['comment'] ?? '',
      createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class AlertItem {
  final String id;
  final String type;
  final String severity;
  final String title;
  final String description;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  const AlertItem({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.lat,
    this.lng,
    required this.createdAt,
  });

  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
        id: j['id'].toString(),
        type: (j['alert_type'] ?? 'unsafe_area').toString(),
        severity: (j['severity'] ?? 'medium').toString(),
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      );
}

class FairPrice {
  final String id;
  final String serviceType;
  final String? itemName;
  final String? routeFrom;
  final String? routeTo;
  final double amountGhs;
  final bool verified;

  const FairPrice({
    required this.id,
    required this.serviceType,
    this.itemName,
    this.routeFrom,
    this.routeTo,
    required this.amountGhs,
    required this.verified,
  });

  factory FairPrice.fromJson(Map<String, dynamic> j) => FairPrice(
        id: j['id'].toString(),
        serviceType: j['service_type'] ?? 'other',
        itemName: j['item_name'],
        routeFrom: j['route_from'],
        routeTo: j['route_to'],
        amountGhs: (j['amount_ghs'] as num?)?.toDouble() ?? 0,
        verified: j['verified'] ?? false,
      );
}

class UserProfile {
  final String id;
  final String name;
  final String? email;
  final String role;
  final String? nationality;
  final String? profileImage;

  const UserProfile({
    required this.id,
    required this.name,
    this.email,
    required this.role,
    this.nationality,
    this.profileImage,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'].toString(),
        name: j['name'] ?? 'User',
        email: j['email'],
        role: j['role'] ?? 'tourist',
        nationality: j['nationality'],
        profileImage: j['profile_image'],
      );
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
