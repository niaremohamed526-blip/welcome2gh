import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Cached network image with a shimmer placeholder and a graceful error fallback.
/// Use this instead of Image.network everywhere — it caches to disk/memory,
/// fades in, and never flashes a broken-image icon.
class AppImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.image_outlined,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, __) => Skeleton(width: width, height: height),
      errorWidget: (_, __, ___) => Container(
        width: width,
        height: height,
        color: AppColors.navyCard,
        child: Icon(fallbackIcon, color: AppColors.grey.withValues(alpha: 0.5), size: 28),
      ),
    );
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

/// A shimmering placeholder block. Use for any "loading" rectangle.
class Skeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const Skeleton({super.key, this.width, this.height, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Shimmer builds a gradient shader that throws
    // "Unsupported operation: Infinity/NaN" if given an infinite or null
    // dimension. Sanitize: infinite/null → let the parent's constraints size it.
    final w = (width != null && width!.isFinite) ? width : null;
    final h = (height != null && height!.isFinite) ? height : null;
    return Shimmer.fromColors(
      baseColor: AppColors.navyCard,
      highlightColor: AppColors.cardBorder,
      child: Container(
        width: w,
        height: h,
        constraints: (w == null || h == null) ? const BoxConstraints.expand() : null,
        decoration: BoxDecoration(
          color: AppColors.navyCard,
          borderRadius: borderRadius ?? BorderRadius.zero,
        ),
      ),
    );
  }
}

/// A skeleton placeholder shaped like a place list-item row.
class PlaceCardSkeleton extends StatelessWidget {
  const PlaceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(children: [
        const Skeleton(width: 90, height: 90, borderRadius: BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16))),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Skeleton(width: 80, height: 12, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 10),
              Skeleton(width: 160, height: 14, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 8),
              Skeleton(width: 110, height: 11, borderRadius: BorderRadius.circular(4)),
            ]),
          ),
        ),
        const SizedBox(width: 16),
      ]),
    );
  }
}

/// A column of place-card skeletons for initial loads.
class PlaceListSkeleton extends StatelessWidget {
  final int count;
  const PlaceListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return Column(children: List.generate(count, (_) => const PlaceCardSkeleton()));
  }
}
