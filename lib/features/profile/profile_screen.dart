import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/models.dart';
import '../../core/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  int _favoritesCount = 0;
  int _postsCount = 0;
  int _reviewsCount = 0;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _load();
    // React to auth state changes — clear stale state on signout
    _authSub = SupabaseService.instance.authStateChanges.listen((state) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.signedOut) {
        setState(() {
          _profile = null;
          _favoritesCount = 0;
          _postsCount = 0;
          _reviewsCount = 0;
        });
      } else if (state.event == AuthChangeEvent.signedIn || state.event == AuthChangeEvent.userUpdated) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      // CRITICAL: always re-fetch from auth.users.id, never use cached state
      if (!SupabaseService.instance.isSignedIn) {
        if (mounted) {
          setState(() {
            _profile = null;
            _favoritesCount = 0;
            _postsCount = 0;
            _reviewsCount = 0;
            _loading = false;
          });
        }
        return;
      }
      final results = await Future.wait([
        SupabaseService.instance.getMyProfile(),
        SupabaseService.instance.getMyStats(),
      ]);
      if (!mounted) return;
      final stats = results[1] as Map<String, int>;
      setState(() {
        _profile = results[0] as UserProfile?;
        _favoritesCount = stats['favorites'] ?? 0;
        _postsCount = stats['posts'] ?? 0;
        _reviewsCount = stats['reviews'] ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load profile: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign out?', style: TextStyle(color: AppColors.white)),
        content: Text('You will need to sign in again to access your account.', style: TextStyle(color: AppColors.greyLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('CANCEL', style: TextStyle(color: AppColors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: AppColors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _profile = null;
      _favoritesCount = 0;
      _postsCount = 0;
      _reviewsCount = 0;
    });
    await SupabaseService.instance.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
            : SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              await context.push('/edit-profile');
                              _load();
                            },
                            child: Stack(
                              children: [
                                ClipOval(
                                  child: _profile?.profileImage != null
                                      ? Image.network(_profile!.profileImage!, width: 90, height: 90, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarPlaceholder())
                                      : _avatarPlaceholder(),
                                ),
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle, border: Border.all(color: AppColors.navy, width: 2)),
                                    child: Icon(Icons.edit_rounded, color: AppColors.navy, size: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _profile?.name ?? SupabaseService.instance.currentUser?.email?.split('@').first ?? 'User',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _profile?.email ?? SupabaseService.instance.currentUser?.email ?? '',
                            style: TextStyle(color: AppColors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.yellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3))),
                            child: Text(_roleLabel(_profile?.role ?? 'tourist'), style: const TextStyle(color: AppColors.yellow, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _StatItem(value: _favoritesCount.toString(), label: 'Saved'),
                              Container(width: 1, height: 32, color: AppColors.cardBorder),
                              _StatItem(value: _postsCount.toString(), label: 'Posts'),
                              Container(width: 1, height: 32, color: AppColors.cardBorder),
                              _StatItem(value: _reviewsCount.toString(), label: 'Reviews'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(color: AppColors.cardBorder, height: 1),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (_profile?.role == 'admin') ...[
                          Text('ADMIN', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.red)),
                          const SizedBox(height: 16),
                          _SettingItem(
                            icon: Icons.shield_rounded,
                            label: 'Admin Dashboard',
                            accent: AppColors.red,
                            onTap: () => context.push('/admin'),
                          ),
                          const SizedBox(height: 24),
                        ],
                        Text('SETTINGS', style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 16),
                        _SettingItem(icon: Icons.person_outline_rounded, label: 'Edit Profile', onTap: () async {
                          await context.push('/edit-profile');
                          _load();
                        }),
                        _SettingItem(icon: Icons.add_location_alt_outlined, label: 'Add a Place', onTap: () => context.push('/add-place')),
                        _SettingItem(icon: Icons.attach_money_rounded, label: 'Fair Prices', onTap: () => context.push('/fair-price')),
                        _SettingItem(icon: Icons.settings_outlined, label: 'Settings', onTap: () => context.push('/settings')),
                        _SettingItem(icon: Icons.auto_awesome_rounded, label: 'Ask the AI Guide', onTap: () => context.push('/ai')),
                        const SizedBox(height: 24),
                        Text('SAFETY', style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 16),
                        _SettingItem(icon: Icons.emergency_rounded, label: 'Emergency Contacts', accent: AppColors.red, onTap: () => _showEmergency(context)),
                        _SettingItem(icon: Icons.shield_outlined, label: 'Safety Settings', onTap: () {}),
                        const SizedBox(height: 24),
                        Text('ACCOUNT', style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 16),
                        _SettingItem(icon: Icons.help_outline_rounded, label: 'Help & Support', onTap: () => context.push('/help')),
                        _SettingItem(icon: Icons.info_outline_rounded, label: 'About Welcome2GH', onTap: () => context.push('/about')),
                        _SettingItem(icon: Icons.logout_rounded, label: 'Sign Out', accent: AppColors.red, onTap: _signOut),
                        const SizedBox(height: 40),
                        Center(
                          child: Text(
                            'WELCOME2GH · WISCONSIN INTERNATIONAL UNIVERSITY COLLEGE · ACCRA',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.grey, fontSize: 9),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ]),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _avatarPlaceholder() => Container(
        width: 90, height: 90,
        color: AppColors.navyCard,
        child: Icon(Icons.person_rounded, color: AppColors.grey, size: 48),
      );

  String _roleLabel(String r) {
    switch (r) {
      case 'student': return 'INTERNATIONAL STUDENT';
      case 'tourist': return 'TOURIST';
      case 'local':   return 'LOCAL EXPERT';
      case 'admin':   return 'ADMIN';
      default:        return r.toUpperCase();
    }
  }

  void _showEmergency(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('EMERGENCY', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.red)),
          const SizedBox(height: 8),
          Text('Emergency Contacts', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          _EmergencyItem(icon: Icons.local_police_rounded, label: 'Police',         number: '191',           color: const Color(0xFF1565C0)),
          const SizedBox(height: 10),
          _EmergencyItem(icon: Icons.local_hospital_rounded, label: 'Ambulance',    number: '193',           color: AppColors.red),
          const SizedBox(height: 10),
          _EmergencyItem(icon: Icons.fire_truck_rounded, label: 'Fire Service',     number: '192',           color: const Color(0xFFFF7043)),
          const SizedBox(height: 10),
          _EmergencyItem(icon: Icons.school_rounded, label: 'WIUC Security',        number: '+233303959999', color: AppColors.yellow),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  const _StatItem({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: AppColors.yellow)),
      const SizedBox(height: 2),
      Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11)),
    ]);
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  const _SettingItem({required this.icon, required this.label, this.accent = const Color(0xFFFFFFFF), required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
        child: Row(children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(color: accent, fontWeight: FontWeight.w500, fontSize: 14)),
          const Spacer(),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: AppColors.grey, size: 18),
        ]),
      ),
    );
  }
}

class _EmergencyItem extends StatelessWidget {
  final IconData icon;
  final String label, number;
  final Color color;
  const _EmergencyItem({required this.icon, required this.label, required this.number, required this.color});

  Future<void> _call() async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _call,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            Text(number, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const Spacer(),
          Icon(Icons.call_rounded, color: color, size: 20),
        ]),
      ),
    );
  }
}
