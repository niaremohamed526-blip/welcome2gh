import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(title: const Text('PRIVACY POLICY')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Last updated: June 2026', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 20),

          _Sec('1. Information We Collect',
              'We collect the minimum data needed to run the app: your email address, name, account role (student/tourist/local/admin), nationality (optional), profile photo (optional), and the content you create (reviews, posts, comments, fair-price reports, saved favorites).'),

          _Sec('2. How We Use Your Data',
              'We use your account data to personalize your experience, secure your session, sync your saved places and preferences across devices, and let other community members see your public posts and reviews.'),

          _Sec('3. Location Data',
              'Welcome2GH uses your device location ONLY when you actively use the map or directions. Location is never stored on our servers unless you choose to attach it to a post or alert. You can revoke location permission at any time in your phone\'s settings.'),

          _Sec('4. Data Storage',
              'Your data is hosted on Supabase (EU region â€” Frankfurt). All connections are encrypted with HTTPS/TLS. Passwords are hashed using industry-standard bcrypt by Supabase Auth. We never see or store your password.'),

          _Sec('5. Sharing With Third Parties',
              'We do NOT sell your data. We use OpenStreetMap (CartoDB) for map tiles and OSRM for route calculation â€” these services receive anonymous tile/route requests with no personally identifying info.'),

          _Sec('6. Your Rights',
              'You can view, edit or delete your profile any time from the Profile screen. To delete your account entirely, contact us through Help & Support â€” we\'ll remove all your data within 30 days.'),

          _Sec('7. Community Content',
              'Posts, reviews and comments you make are public by default. Admins may moderate or remove content that violates community guidelines.'),

          _Sec('8. Children',
              'Welcome2GH is not directed at children under 13. If you believe a child has created an account, contact us and we will delete it.'),

          _Sec('9. Changes',
              'We may update this policy occasionally. Material changes will be announced in the app.'),

          _Sec('10. Contact',
              'Questions? Reach us through Profile â†’ Help & Support, or email support@welcome2gh.app.'),

          const SizedBox(height: 30),
          Center(child: Text('Â© 2026 Welcome2GH', style: TextStyle(color: AppColors.grey, fontSize: 11))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _Sec extends StatelessWidget {
  final String title, body;
  const _Sec(this.title, this.body);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppColors.yellow, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(body, style: TextStyle(color: AppColors.greyLight, fontSize: 13, height: 1.65)),
      ]),
    );
  }
}
