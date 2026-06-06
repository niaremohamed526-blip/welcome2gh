import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

/// Shared map presentation helpers used across the map and directions screens.

/// Wraps [child] in a frosted-glass panel (blur + translucent tint + border),
/// matching the app's glassmorphism design system.
Widget glass({
  required Widget child,
  double radius = 14,
  double sigma = 12,
  double alpha = 0.55,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: child,
      ),
    ),
  );
}

/// Brand colour for a place category.
Color categoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'transport': return const Color(0xFF00BCD4);
    case 'university':
    case 'study_spot': return const Color(0xFF7C4DFF);
    case 'restaurant':
    case 'cafe': return const Color(0xFFFF7043);
    case 'hostel': return const Color(0xFF66BB6A);
    case 'hotel': return const Color(0xFF26A69A);
    case 'market':
    case 'mall': return const Color(0xFFAB47BC);
    case 'hospital': return const Color(0xFFEF5350);
    case 'nightlife':
    case 'event': return const Color(0xFFEC407A);
    case 'tourist': return const Color(0xFF42A5F5);
    case 'mosque':
    case 'church': return const Color(0xFF5C6BC0);
    default: return AppColors.yellow;
  }
}

/// Icon for a place category (also used by the filter chips; 'All' maps to a
/// globe).
IconData categoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'all': return Icons.travel_explore_rounded;
    case 'university': return Icons.school_rounded;
    case 'study_spot': return Icons.menu_book_rounded;
    case 'hostel': return Icons.bed_rounded;
    case 'hotel': return Icons.hotel_rounded;
    case 'restaurant': return Icons.restaurant_rounded;
    case 'cafe': return Icons.local_cafe_rounded;
    case 'transport': return Icons.directions_bus_rounded;
    case 'market': return Icons.storefront_rounded;
    case 'mall': return Icons.local_mall_rounded;
    case 'nightlife': return Icons.nightlife_rounded;
    case 'event': return Icons.celebration_rounded;
    case 'hospital': return Icons.local_hospital_rounded;
    case 'tourist': return Icons.photo_camera_rounded;
    case 'mosque': return Icons.mosque_rounded;
    case 'church': return Icons.church_rounded;
    default: return Icons.place_rounded;
  }
}
