import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(title: const Text('TERMS OF SERVICE')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Last updated: June 2026', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 20),

          _Sec('1. Acceptance', 'By creating an account and using Welcome2GH, you agree to these terms. If you don\'t agree, please don\'t use the app.'),

          _Sec('2. The Service',
              'Welcome2GH is a community-driven smart tourism assistant for Accra, Ghana. We provide place discovery, reviews, fair-price reporting, safety alerts and an AI guide. The app is provided "as is" â€” places, prices and alerts are crowd-sourced and may not always be accurate.'),

          _Sec('3. Your Account',
              'You\'re responsible for the security of your account. Keep your password private. Notify us immediately if you suspect unauthorized access.'),

          _Sec('4. Acceptable Use',
              'Be respectful. Do NOT post: spam, harassment, hate speech, illegal content, fake reviews, fabricated price reports, or false safety alerts. Admins may remove your content and account if you break these rules.'),

          _Sec('5. User Content',
              'You retain ownership of the content you post, but you grant Welcome2GH a license to display it in the app. You confirm you have the right to share any photos you upload.'),

          _Sec('6. Safety Disclaimer',
              'Welcome2GH provides safety information from community reports and IoT sensors. It is a helpful tool, not a substitute for your own judgment. In an emergency, call 191 (Police), 193 (Ambulance) or 192 (Fire) directly.'),

          _Sec('7. Fair Price Disclaimer',
              'Prices in the app are community-reported averages. Actual prices may vary. We do not guarantee any specific price will be honored by any vendor or driver.'),

          _Sec('8. Liability',
              'To the maximum extent permitted by Ghanaian law, Welcome2GH is not liable for incidents, losses or damages resulting from use of the app, including reliance on community data.'),

          _Sec('9. Termination',
              'You can delete your account any time through Help & Support. We may suspend or terminate accounts that violate these terms.'),

          _Sec('10. Changes',
              'We may update these terms occasionally. Continued use after changes constitutes acceptance.'),

          _Sec('11. Governing Law',
              'These terms are governed by the laws of the Republic of Ghana.'),

          _Sec('12. Contact',
              'For legal questions, reach us through Profile â†’ Help & Support.'),

          const SizedBox(height: 30),
          Center(child: Text('Â© 2026 Welcome2GH Â· Wisconsin International University College', textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey, fontSize: 10))),
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
