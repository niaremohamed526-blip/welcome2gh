import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'supabase_service.dart';
import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';
import '../features/map/map_screen.dart';
import '../features/map/map3d_screen.dart';
import '../features/directions/directions_screen.dart';
import '../features/place_details/place_details_screen.dart';
import '../features/community/community_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/ai_assistant/ai_assistant_screen.dart';
import '../features/add_place/add_place_screen.dart';
import '../features/edit_profile/edit_profile_screen.dart';
import '../features/fair_price/fair_price_screen.dart';
import '../features/admin/admin_dashboard.dart';
import '../features/settings/settings_screen.dart';
import '../features/support/help_support_screen.dart';
import '../features/about/about_screen.dart';
import '../features/legal/privacy_screen.dart';
import '../features/legal/terms_screen.dart';

/// Routes that require an authenticated user. A signed-out user landing on
/// any of these (e.g. after signing out) is sent to /login automatically.
const _protectedPrefixes = ['/profile', '/favorites', '/add-place', '/edit-profile', '/admin'];

/// Bridges Supabase auth events to GoRouter so the redirect below re-runs the
/// moment the user signs in or out — this is what kicks a signed-out user off
/// the profile screen instead of leaving a blank screen behind.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final router = GoRouter(
  initialLocation: '/splash',
  refreshListenable: _AuthRefresh(SupabaseService.instance.authStateChanges),
  redirect: (context, state) {
    final signedIn = SupabaseService.instance.isSignedIn;
    final location = state.uri.path;
    final isProtected = _protectedPrefixes.any((p) => location.startsWith(p));
    if (!signedIn && isProtected) return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
        // Dev/preview route for the MapLibre 3D engine migration. The live
        // /map stays on flutter_map until the new engine is verified.
        GoRoute(path: '/map3d', builder: (_, __) => const Map3DScreen()),
        // TEMP (maplibre-migration): preview the MapLibre Directions/navigation
        // screen with a fixed destination. Remove during the final swap.
        GoRoute(
          path: '/nav-demo',
          builder: (_, __) => const DirectionsScreen(
            destLat: 5.6510,
            destLng: -0.1870,
            destName: 'University of Ghana, Legon',
            autoStart: true,
          ),
        ),
        GoRoute(path: '/community', builder: (_, __) => const CommunityScreen()),
        GoRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),
    GoRoute(
      path: '/place/:id',
      redirect: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null || id.trim().isEmpty) return '/home';
        return null;
      },
      builder: (context, state) => PlaceDetailsScreen(placeId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/ai', builder: (_, __) => const AiAssistantScreen()),
    GoRoute(path: '/add-place', builder: (_, __) => const AddPlaceScreen()),
    GoRoute(path: '/edit-profile', builder: (_, __) => const EditProfileScreen()),
    GoRoute(path: '/fair-price', builder: (_, __) => const FairPriceScreen()),
    GoRoute(
      path: '/admin',
      redirect: (context, state) => SupabaseService.instance.isSignedIn ? null : '/login',
      builder: (_, __) => const AdminDashboard(),
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/help', builder: (_, __) => const HelpSupportScreen()),
    GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
    GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
    GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
  ],
);

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _tabs = ['/home', '/map', '/community', '/favorites', '/profile'];

  int _indexForLocation(String location) {
    final i = _tabs.indexWhere((t) => location.startsWith(t));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    // Derive selected index from the actual current route so the highlight
    // is always correct, even after deep links or programmatic navigation.
    final location = GoRouterState.of(context).uri.path;
    final index = _indexForLocation(location);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: _BottomNav(
        index: index,
        onTap: (i) {
          HapticFeedback.selectionClick();
          // Tapping the already-active tab is a no-op rather than a reload.
          if (i != index) context.go(_tabs[i]);
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        border: Border(top: BorderSide(color: const Color(0xFF243044), width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Home', selected: index == 0, onTap: () => onTap(0)),
              _NavItem(icon: Icons.map_rounded, label: 'Map', selected: index == 1, onTap: () => onTap(1)),
              _NavItem(icon: Icons.people_rounded, label: 'Community', selected: index == 2, onTap: () => onTap(2)),
              _NavItem(icon: Icons.bookmark_rounded, label: 'Saved', selected: index == 3, onTap: () => onTap(3)),
              _NavItem(icon: Icons.person_rounded, label: 'Profile', selected: index == 4, onTap: () => onTap(4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFFFCC00) : const Color(0xFF8B9AAB);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
