import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(title: const Text('ABOUT')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Center(child: AppLogoChip(size: 96, glow: true)),
          const SizedBox(height: 16),
          Center(child: Text('WELCOME2GH', style: Theme.of(context).textTheme.displaySmall?.copyWith(letterSpacing: 3))),
          const SizedBox(height: 4),
          Center(child: Text('Version 1.0.0', style: TextStyle(color: AppColors.grey, fontSize: 12))),
          const SizedBox(height: 32),

          Text('OUR MISSION', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          Text(
            'Welcome2Gh is the smart companion for international students and tourists visiting Ghana. '
            'We help you discover safe places, navigate Accra confidently, find fair prices, and connect with '
            'a vibrant local community — all backed by real-time IoT environmental intelligence.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
          ),
          const SizedBox(height: 28),

          Text('FEATURES', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          _Feat(Icons.map_rounded, 'Smart Maps', 'Live places, crowd levels, safety alerts'),
          _Feat(Icons.shield_rounded, 'Community Safety', 'Real-time scam warnings and tips'),
          _Feat(Icons.attach_money_rounded, 'Fair Prices', 'Verified transport and market prices'),
          _Feat(Icons.auto_awesome_rounded, 'AI Guide', 'Ask anything about Accra'),
          _Feat(Icons.sensors_rounded, 'IoT Live', 'Air quality, noise, crowd density'),
          const SizedBox(height: 28),

          Text('DEVELOPED BY', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Wisconsin International University College', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              SizedBox(height: 4),
              Text('Accra, Ghana', style: TextStyle(color: AppColors.grey, fontSize: 12)),
              SizedBox(height: 10),
              Text(
                'Built with Flutter and Supabase. Open source spirit, made for foreigners by people who know Accra.',
                style: TextStyle(color: AppColors.greyLight, fontSize: 12, height: 1.5),
              ),
            ]),
          ),
          const SizedBox(height: 28),

          Text('LEGAL', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          _LinkRow(label: 'Privacy Policy', onTap: (ctx) => ctx.push('/privacy')),
          _LinkRow(label: 'Terms of Service', onTap: (ctx) => ctx.push('/terms')),
          _LinkRow(label: 'Open Source Licenses', onTap: (ctx) => showLicensePage(context: ctx, applicationName: 'Welcome2GH', applicationVersion: '1.0.0')),
          const SizedBox(height: 30),

          Center(child: Text('© 2026 Welcome2GH · Made with 💛 in Accra', style: TextStyle(color: AppColors.grey, fontSize: 11))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _Feat extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const _Feat(this.icon, this.title, this.sub);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: AppColors.yellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3))),
          child: Icon(icon, color: AppColors.yellow, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: AppColors.grey, fontSize: 11)),
        ])),
      ]),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final void Function(BuildContext) onTap;
  const _LinkRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w500, fontSize: 13))),
          Icon(Icons.chevron_right_rounded, color: AppColors.grey, size: 16),
        ]),
      ),
    );
  }
}
