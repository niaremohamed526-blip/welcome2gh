import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/models.dart';
import '../../core/supabase_service.dart';
import '../../core/image_upload.dart';
import '../../shared/widgets/app_image.dart';
import '../add_place/add_place_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _checkingAccess = true;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
    _verifyAccess();
  }

  Future<void> _verifyAccess() async {
    final isAdmin = await SupabaseService.instance.isCurrentUserAdmin();
    if (!mounted) return;
    setState(() {
      _hasAccess = isAdmin;
      _checkingAccess = false;
    });
    if (!isAdmin && mounted) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return Scaffold(backgroundColor: AppColors.navy, body: Center(child: CircularProgressIndicator(color: AppColors.yellow)));
    }
    if (!_hasAccess) {
      return Scaffold(
        backgroundColor: AppColors.navy,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_rounded, color: AppColors.red, size: 56),
            const SizedBox(height: 16),
            const Text('ACCESS DENIED', style: TextStyle(color: AppColors.red, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text('Admin role required.', style: TextStyle(color: AppColors.greyLight, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Redirecting…', style: TextStyle(color: AppColors.grey, fontSize: 11)),
          ]),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(6)),
            child: Text('ADMIN', style: TextStyle(color: AppColors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
          const SizedBox(width: 10),
          const Text('DASHBOARD'),
        ]),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.yellow,
          labelColor: AppColors.yellow,
          unselectedLabelColor: AppColors.grey,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          tabs: const [
            Tab(text: 'OVERVIEW'),
            Tab(text: 'USERS'),
            Tab(text: 'PLACES'),
            Tab(text: 'REVIEWS'),
            Tab(text: 'POSTS'),
            Tab(text: 'ALERTS'),
            Tab(text: 'PRICES'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: const [
        _OverviewTab(),
        _UsersTab(),
        _PlacesTab(),
        _ReviewsTab(),
        _PostsTab(),
        _AlertsTab(),
        _PricesTab(),
      ]),
    );
  }
}

// ── OVERVIEW ────────────────────────────────────────────────────────────────
class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final s = await SupabaseService.instance.getAdminStats();
    if (mounted) setState(() { _stats = s; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.yellow));
    final s = _stats ?? {};
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.yellow,
      backgroundColor: AppColors.navyCard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('USERS', [
            _stat('Total users', '${s['total_users'] ?? 0}', Icons.people_rounded, AppColors.yellow),
            _stat('Admins', '${s['total_admins'] ?? 0}', Icons.shield_rounded, AppColors.red),
            _stat('Students', '${s['total_students'] ?? 0}', Icons.school_rounded, const Color(0xFF7C4DFF)),
            _stat('Tourists', '${s['total_tourists'] ?? 0}', Icons.flight_rounded, const Color(0xFF00BCD4)),
          ]),
          _section('PLACES', [
            _stat('Active places', '${s['total_places'] ?? 0}', Icons.place_rounded, AppColors.green),
            _stat('Unverified', '${s['unverified_places'] ?? 0}', Icons.help_outline_rounded, const Color(0xFFFF7043)),
          ]),
          _section('CONTENT', [
            _stat('Reviews', '${s['total_reviews'] ?? 0}', Icons.star_rounded, AppColors.yellow),
            _stat('Community posts', '${s['total_posts'] ?? 0}', Icons.chat_bubble_rounded, AppColors.green),
            _stat('Active alerts', '${s['active_alerts'] ?? 0}', Icons.warning_rounded, AppColors.red),
            _stat('Fair prices', '${s['total_prices'] ?? 0}', Icons.attach_money_rounded, AppColors.yellow),
            _stat('Unverified prices', '${s['unverified_prices'] ?? 0}', Icons.help_outline_rounded, const Color(0xFFFF7043)),
          ]),
          Text('HOME PAGE', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.navyCard,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              builder: (_) => const _HeroEditorSheet(),
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
              child: Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.yellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.image_rounded, color: AppColors.yellow, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hero Section', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Edit the home page banner image & text', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                ])),
                Icon(Icons.chevron_right_rounded, color: AppColors.grey, size: 18),
              ]),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> items) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2,
            children: items,
          ),
        ]),
      );

  Widget _stat(String label, String value, IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20)),
            Text(label, style: TextStyle(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.w600)),
          ])),
        ]),
      );
}

// ── HERO EDITOR ───────────────────────────────────────────────────────────────
class _HeroEditorSheet extends StatefulWidget {
  const _HeroEditorSheet();
  @override
  State<_HeroEditorSheet> createState() => _HeroEditorSheetState();
}

// Available CTA destinations the admin can choose from
const _ctaRoutes = [
  (label: 'Map',        icon: Icons.map_rounded,            route: '/map'),
  (label: 'Community',  icon: Icons.people_rounded,          route: '/community'),
  (label: 'AI Guide',   icon: Icons.auto_awesome_rounded,    route: '/ai'),
  (label: 'Favorites',  icon: Icons.bookmark_rounded,        route: '/favorites'),
  (label: 'Home',       icon: Icons.home_rounded,            route: '/home'),
];

class _HeroEditorSheetState extends State<_HeroEditorSheet> {
  final _title    = TextEditingController();
  final _subtitle = TextEditingController();
  final _ctaText  = TextEditingController();
  final _urlCtrl  = TextEditingController(); // paste-URL field

  String _imageUrl  = '';
  String _ctaRoute  = '/map';
  bool   _loading   = true;
  bool   _saving    = false;
  bool   _showUrlField = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final h = await SupabaseService.instance.getHeroConfig();
    if (!mounted) return;
    setState(() {
      _title.text    = h['title']    ?? '';
      _subtitle.text = h['subtitle'] ?? '';
      _ctaText.text  = h['cta_text'] ?? 'OPEN THE MAP';
      _ctaRoute      = h['cta_route'] ?? '/map';
      _imageUrl      = h['image_url'] ?? '';
      _urlCtrl.text  = _imageUrl;
      _loading       = false;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _ctaText.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SupabaseService.instance.updateHeroConfig(
        title:    _title.text.trim(),
        subtitle: _subtitle.text.trim(),
        imageUrl: _imageUrl,
        ctaText:  _ctaText.text.trim().isNotEmpty ? _ctaText.text.trim() : 'OPEN THE MAP',
        ctaRoute: _ctaRoute,
      );
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Hero section updated — pull-to-refresh the home screen to see it.'), backgroundColor: AppColors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
          : Column(children: [
              // Handle + header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.yellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.image_rounded, color: AppColors.yellow, size: 18)),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('HERO SECTION', style: Theme.of(context).textTheme.labelSmall),
                      Text('Home page banner', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                ]),
              ),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    // ── Live preview ──────────────────────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 180,
                        child: Stack(fit: StackFit.expand, children: [
                          AppImage(url: _imageUrl, fit: BoxFit.cover, fallbackIcon: Icons.image_rounded),
                          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppColors.navy.withValues(alpha: 0.92)]))),
                          Positioned(
                            left: 16, bottom: 16, right: 16,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              Text(_subtitle.text.toUpperCase(), style: const TextStyle(color: AppColors.yellow, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                              const SizedBox(height: 4),
                              Text(_title.text.replaceAll('\n', ' '), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  _ctaText.text.isNotEmpty ? _ctaText.text.toUpperCase() : 'BUTTON TEXT',
                                  style: TextStyle(color: AppColors.navy, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                                ),
                              ),
                            ]),
                          ),
                          // Preview label
                          Positioned(top: 10, right: 10, child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(6)),
                            child: Text('LIVE PREVIEW', style: TextStyle(color: AppColors.grey, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          )),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Title ─────────────────────────────────────────────
                    _label('BANNER TITLE'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _title,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: AppColors.white),
                      maxLines: 2,
                      decoration: InputDecoration(hintText: 'e.g. YOUR NEW\nPLAYGROUND.', helperText: 'Use a line break (↵) to split into 2 lines'),
                    ),
                    const SizedBox(height: 16),

                    // ── Subtitle ──────────────────────────────────────────
                    _label('SUBTITLE / TAGLINE'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _subtitle,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(hintText: 'e.g. ACCRA, A CITY ALIVE'),
                    ),
                    const SizedBox(height: 24),

                    // ── Image ─────────────────────────────────────────────
                    _label('BANNER IMAGE'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final url = await ImageUploadHelper.pickAndUpload(context, bucket: 'places', folder: 'hero');
                        if (url != null && mounted) setState(() { _imageUrl = url; _urlCtrl.text = url; });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
                        child: Row(children: [
                          Icon(Icons.upload_rounded, color: AppColors.yellow, size: 20),
                          SizedBox(width: 12),
                          Expanded(child: Text('Upload from device', style: TextStyle(color: AppColors.white, fontSize: 14))),
                          Icon(Icons.chevron_right_rounded, color: AppColors.grey, size: 18),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // OR paste a URL
                    GestureDetector(
                      onTap: () => setState(() => _showUrlField = !_showUrlField),
                      child: Row(children: [
                        Icon(Icons.link_rounded, color: AppColors.grey, size: 14),
                        const SizedBox(width: 6),
                        Text(_showUrlField ? 'Hide URL field' : 'Or paste an image URL (Unsplash, CDN…)', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                      ]),
                    ),
                    if (_showUrlField) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _urlCtrl,
                        onChanged: (v) => setState(() => _imageUrl = v.trim()),
                        style: TextStyle(color: AppColors.white, fontSize: 13),
                        decoration: InputDecoration(hintText: 'https://images.unsplash.com/…'),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── CTA Button ────────────────────────────────────────
                    _label('CALL-TO-ACTION BUTTON'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ctaText,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: AppColors.white),
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(hintText: 'e.g. EXPLORE NOW', helperText: 'Text shown on the yellow button'),
                    ),
                    const SizedBox(height: 16),

                    // ── CTA Destination ───────────────────────────────────
                    _label('BUTTON DESTINATION'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _ctaRoutes.map((r) {
                        final active = _ctaRoute == r.route;
                        return GestureDetector(
                          onTap: () => setState(() => _ctaRoute = r.route),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: active ? AppColors.yellow : AppColors.navyCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: active ? AppColors.yellow : AppColors.cardBorder),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(r.icon, color: active ? AppColors.navy : AppColors.grey, size: 16),
                              const SizedBox(width: 6),
                              Text(r.label, style: TextStyle(color: active ? AppColors.navy : AppColors.grey, fontSize: 12, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // ── Save ──────────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(_saving ? 'SAVING…' : 'SAVE HERO SECTION'),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
    );
  }

  Widget _label(String text) => Text(text, style: TextStyle(color: AppColors.grey, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5));
}

// ── USERS ───────────────────────────────────────────────────────────────────
class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<UserProfile> _users = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final u = await SupabaseService.instance.getAllUsers();
    if (mounted) setState(() { _users = u; _loading = false; });
  }

  Future<void> _changeRole(UserProfile u) async {
    final newRole = await showDialog<String>(context: context, builder: (_) => SimpleDialog(
      backgroundColor: AppColors.navyCard,
      title: Text('Change role for ${u.name}', style: TextStyle(color: AppColors.white, fontSize: 16)),
      children: ['tourist', 'student', 'local', 'admin'].map((r) => SimpleDialogOption(
        onPressed: () => Navigator.pop(context, r),
        child: Row(children: [
          if (r == u.role) const Icon(Icons.check_rounded, color: AppColors.yellow, size: 16) else const SizedBox(width: 16),
          const SizedBox(width: 10),
          Text(r.toUpperCase(), style: TextStyle(color: r == 'admin' ? AppColors.red : AppColors.white, fontWeight: FontWeight.w600)),
        ]),
      )).toList(),
    ));
    if (newRole != null && newRole != u.role) {
      await SupabaseService.instance.setUserRole(u.id, newRole);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.yellow));
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.yellow,
      backgroundColor: AppColors.navyCard,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (_, i) {
          final u = _users[i];
          final isAdmin = u.role == 'admin';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: isAdmin ? AppColors.red.withValues(alpha: 0.2) : AppColors.yellow.withValues(alpha: 0.2), child: Icon(isAdmin ? Icons.shield_rounded : Icons.person_rounded, color: isAdmin ? AppColors.red : AppColors.yellow, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.name, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                if (u.email != null) Text(u.email!, style: TextStyle(color: AppColors.grey, fontSize: 11)),
                const SizedBox(height: 3),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: isAdmin ? AppColors.red.withValues(alpha: 0.15) : AppColors.yellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text(u.role.toUpperCase(), style: TextStyle(color: isAdmin ? AppColors.red : AppColors.yellow, fontSize: 9, fontWeight: FontWeight.w800))),
              ])),
              IconButton(icon: Icon(Icons.edit_rounded, color: AppColors.grey, size: 18), onPressed: () => _changeRole(u)),
            ]),
          );
        },
      ),
    );
  }
}

// ── PLACES ──────────────────────────────────────────────────────────────────
class _PlacesTab extends StatefulWidget {
  const _PlacesTab();
  @override
  State<_PlacesTab> createState() => _PlacesTabState();
}

class _PlacesTabState extends State<_PlacesTab> {
  List<Place> _places = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SupabaseService.instance.getAllPlacesForAdmin();
    if (mounted) setState(() { _places = p; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.yellow));
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.yellow,
      backgroundColor: AppColors.navyCard,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _places.length,
        itemBuilder: (_, i) {
          final p = _places[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
            child: Row(children: [
              AppImage(url: p.imageUrl, width: 48, height: 48, borderRadius: BorderRadius.circular(8), fallbackIcon: Icons.place),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${p.category} · ${p.address}', style: TextStyle(color: AppColors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              IconButton(
                icon: Icon(p.verified ? Icons.verified_rounded : Icons.verified_outlined, color: p.verified ? AppColors.green : AppColors.grey, size: 18),
                onPressed: () async { await SupabaseService.instance.verifyPlace(p.id, !p.verified); _load(); },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.yellow, size: 18),
                tooltip: 'Edit place',
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddPlaceScreen(editPlace: p)));
                  _load();
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 18),
                onPressed: () async {
                  final ok = await _confirm(context, 'Delete ${p.name}?');
                  if (ok) { await SupabaseService.instance.deletePlace(p.id); _load(); }
                },
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ── REVIEWS ─────────────────────────────────────────────────────────────────
class _ReviewsTab extends StatefulWidget {
  const _ReviewsTab();
  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  List<Review> _reviews = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final r = await SupabaseService.instance.getAllReviews();
    if (mounted) setState(() { _reviews = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.yellow));
    if (_reviews.isEmpty) return Center(child: Text('No reviews yet', style: TextStyle(color: AppColors.grey)));
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.yellow,
      backgroundColor: AppColors.navyCard,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reviews.length,
        itemBuilder: (_, i) {
          final r = _reviews[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(r.userName, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 8),
                  Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, color: i < r.rating.floor() ? AppColors.yellow : AppColors.grey.withValues(alpha: 0.3), size: 12))),
                ]),
                const SizedBox(height: 4),
                Text(r.comment, style: TextStyle(color: AppColors.greyLight, fontSize: 12)),
              ])),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 18),
                onPressed: () async {
                  final ok = await _confirm(context, 'Delete this review?');
                  if (ok) { await SupabaseService.instance.deleteReview(r.id); _load(); }
                },
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ── POSTS ───────────────────────────────────────────────────────────────────
class _PostsTab extends StatefulWidget {
  const _PostsTab();
  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> {
  List<CommunityPost> _posts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SupabaseService.instance.getAllPostsForAdmin();
    if (mounted) setState(() { _posts = p; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.yellow));
    if (_posts.isEmpty) return Center(child: Text('No posts yet', style: TextStyle(color: AppColors.grey)));
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.yellow,
      backgroundColor: AppColors.navyCard,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length,
        itemBuilder: (_, i) {
          final p = _posts[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(p.authorName, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.yellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text(p.category.toUpperCase(), style: const TextStyle(color: AppColors.yellow, fontSize: 9, fontWeight: FontWeight.w800))),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.yellow, size: 18),
                  tooltip: 'Edit post',
                  onPressed: () => _editPost(p),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 18),
                  onPressed: () async {
                    final ok = await _confirm(context, 'Hide this post?');
                    if (ok) { await SupabaseService.instance.deletePost(p.id); _load(); }
                  },
                ),
              ]),
              Text(p.content, style: TextStyle(color: AppColors.greyLight, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis),
            ]),
          );
        },
      ),
    );
  }

  void _editPost(CommunityPost p) {
    final ctrl = TextEditingController(text: p.content);
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.navyCard,
      title: Text('Edit post', style: TextStyle(color: AppColors.white)),
      content: TextField(controller: ctrl, maxLines: 5, style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'Post content')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppColors.grey))),
        ElevatedButton(onPressed: () async {
          final text = ctrl.text.trim();
          if (text.isEmpty) return;
          final nav = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          try {
            await SupabaseService.instance.updatePost(p.id, content: text, category: p.category);
            nav.pop();
            _load();
          } catch (e) { messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red)); }
        }, child: const Text('SAVE')),
      ],
    ));
  }
}

// ── ALERTS ──────────────────────────────────────────────────────────────────
class _AlertsTab extends StatefulWidget {
  const _AlertsTab();
  @override
  State<_AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<_AlertsTab> {
  List<AlertItem> _alerts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final a = await SupabaseService.instance.getAllAlertsForAdmin();
    if (mounted) setState(() { _alerts = a; _loading = false; });
  }

  Color _sev(String s) {
    switch (s) { case 'critical': return const Color(0xFFD32F2F); case 'high': return AppColors.red; case 'medium': return const Color(0xFFFF7043); default: return AppColors.yellow; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.white,
        onPressed: () => _alertSheet(),
        child: const Icon(Icons.add_alert_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
          : _alerts.isEmpty
              ? Center(child: Text('No alerts. Tap + to create one.', style: TextStyle(color: AppColors.grey)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.yellow,
                  backgroundColor: AppColors.navyCard,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _alerts.length,
                    itemBuilder: (_, i) {
                      final a = _alerts[i];
                      final color = _sev(a.severity);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.4))),
                        child: Row(children: [
                          Icon(Icons.warning_amber_rounded, color: color, size: 22),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(a.title, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(width: 6),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)), child: Text(a.severity.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800))),
                            ]),
                            const SizedBox(height: 2),
                            Text(a.description, style: TextStyle(color: AppColors.grey, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ])),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.yellow, size: 18),
                            tooltip: 'Edit alert',
                            onPressed: () => _alertSheet(existing: a),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 18),
                            onPressed: () async {
                              final ok = await _confirm(context, 'Deactivate this alert?');
                              if (ok) { await SupabaseService.instance.deactivateAlert(a.id); _load(); }
                            },
                          ),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }

  void _alertSheet({AlertItem? existing}) {
    final title = TextEditingController(text: existing?.title ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    final lat = TextEditingController(text: existing?.lat?.toString() ?? '');
    final lng = TextEditingController(text: existing?.lng?.toString() ?? '');
    String type = existing?.type ?? 'unsafe_area';
    String severity = existing?.severity ?? 'medium';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setSh) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 24),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(existing == null ? 'NEW ALERT' : 'EDIT ALERT', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.red)),
            const SizedBox(height: 8),
            Text(existing == null ? 'Broadcast a safety warning' : 'Edit this alert', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 18),
            Row(children: ['unsafe_area', 'scam', 'traffic', 'high_crowd', 'emergency'].map((t) => Expanded(child: GestureDetector(onTap: () => setSh(() => type = t), child: Container(margin: EdgeInsets.only(right: 4), padding: EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: type == t ? AppColors.red : AppColors.navy, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder)), child: Center(child: Text(t.replaceAll('_', ' '), style: TextStyle(color: type == t ? AppColors.white : AppColors.grey, fontSize: 9, fontWeight: FontWeight.w700))))))).toList()),
            const SizedBox(height: 10),
            Row(children: ['low', 'medium', 'high', 'critical'].map((s) => Expanded(child: GestureDetector(onTap: () => setSh(() => severity = s), child: Container(margin: EdgeInsets.only(right: 4), padding: EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: severity == s ? _sev(s) : AppColors.navy, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder)), child: Center(child: Text(s.toUpperCase(), style: TextStyle(color: severity == s ? AppColors.white : AppColors.grey, fontSize: 10, fontWeight: FontWeight.w700))))))).toList()),
            const SizedBox(height: 14),
            TextField(controller: title, style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'Title')),
            const SizedBox(height: 10),
            TextField(controller: desc, maxLines: 3, style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'Description')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: lat, keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true), style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'Lat (optional)'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: lng, keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true), style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'Lng (optional)'))),
            ]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: AppColors.white),
              onPressed: () async {
                if (title.text.trim().isEmpty) return;
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  if (existing == null) {
                    await SupabaseService.instance.createAlert(
                      type: type, severity: severity, title: title.text.trim(), description: desc.text.trim(),
                      lat: double.tryParse(lat.text.trim()), lng: double.tryParse(lng.text.trim()),
                    );
                  } else {
                    await SupabaseService.instance.updateAlert(
                      existing.id,
                      type: type, severity: severity, title: title.text.trim(), description: desc.text.trim(),
                      lat: double.tryParse(lat.text.trim()), lng: double.tryParse(lng.text.trim()),
                    );
                  }
                  if (mounted) { nav.pop(); _load(); }
                } catch (e) {
                  if (mounted) messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red));
                }
              },
              child: Text(existing == null ? 'BROADCAST ALERT' : 'SAVE CHANGES'),
            )),
            const SizedBox(height: 24),
          ]),
        ),
      )),
    );
  }
}

// ── FAIR PRICES (admin) ─────────────────────────────────────────────────────
class _PricesTab extends StatefulWidget {
  const _PricesTab();
  @override
  State<_PricesTab> createState() => _PricesTabState();
}

class _PricesTabState extends State<_PricesTab> {
  List<FairPrice> _prices = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SupabaseService.instance.getAllFairPricesForAdmin();
    if (mounted) setState(() { _prices = p; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.yellow));
    if (_prices.isEmpty) return Center(child: Text('No fair prices reported', style: TextStyle(color: AppColors.grey)));
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.yellow,
      backgroundColor: AppColors.navyCard,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _prices.length,
        itemBuilder: (_, i) {
          final p = _prices[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.itemName ?? '${p.routeFrom ?? ''} → ${p.routeTo ?? ''}', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${p.serviceType.toUpperCase()} · GHS ${p.amountGhs.toStringAsFixed(0)}', style: TextStyle(color: AppColors.grey, fontSize: 11)),
              ])),
              IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.yellow, size: 18), tooltip: 'Edit price', onPressed: () => _editPrice(p)),
              IconButton(icon: Icon(p.verified ? Icons.verified_rounded : Icons.verified_outlined, color: p.verified ? AppColors.green : AppColors.grey, size: 18), onPressed: () async { await SupabaseService.instance.verifyFairPrice(p.id, !p.verified); _load(); }),
              IconButton(icon: const Icon(Icons.flag_outlined, color: Color(0xFFFF7043), size: 18), onPressed: () async { await SupabaseService.instance.flagFairPrice(p.id); _load(); }),
              IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 18), onPressed: () async {
                final ok = await _confirm(context, 'Delete this price report?');
                if (ok) { await SupabaseService.instance.deleteFairPrice(p.id); _load(); }
              }),
            ]),
          );
        },
      ),
    );
  }

  void _editPrice(FairPrice p) {
    final ctrl = TextEditingController(text: p.amountGhs.toStringAsFixed(0));
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.navyCard,
      title: Text('Edit price (GHS)', style: TextStyle(color: AppColors.white)),
      content: TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: AppColors.white), decoration: InputDecoration(hintText: 'Amount in GHS')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppColors.grey))),
        ElevatedButton(onPressed: () async {
          final amount = double.tryParse(ctrl.text.trim());
          if (amount == null) return;
          final nav = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          try {
            await SupabaseService.instance.updateFairPriceAmount(p.id, amount);
            nav.pop();
            _load();
          } catch (e) { messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red)); }
        }, child: const Text('SAVE')),
      ],
    ));
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────
Future<bool> _confirm(BuildContext context, String message) async {
  return await showDialog<bool>(context: context, builder: (_) => AlertDialog(
    backgroundColor: AppColors.navyCard,
    title: Text('Confirm', style: TextStyle(color: AppColors.white)),
    content: Text(message, style: TextStyle(color: AppColors.greyLight)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: AppColors.grey))),
      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700))),
    ],
  )) ?? false;
}
