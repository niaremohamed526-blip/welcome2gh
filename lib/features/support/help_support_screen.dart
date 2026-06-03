import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/supabase_service.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_subject.text.trim().isEmpty || _message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields'), backgroundColor: AppColors.red),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      // Save support ticket as a community post tagged 'general' for admin to see
      // (Could be a dedicated support_tickets table)
      await SupabaseService.instance.createPost(
        content: '[SUPPORT] ${_subject.text.trim()}\n\n${_message.text.trim()}',
        category: 'general',
      );
      if (!mounted) return;
      _subject.clear();
      _message.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent. We\'ll get back to you.'), backgroundColor: AppColors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(title: const Text('HELP & SUPPORT')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('FREQUENTLY ASKED', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          _Faq('How do I save a place?', 'Tap the bookmark icon on any place card or detail screen. Saved places appear in the Saved tab.'),
          _Faq('Why don\'t I see my reviews?', 'Reviews appear under the place you reviewed. Open the place detail screen to see them.'),
          _Faq('How are fair prices verified?', 'Community members report prices. Admins verify them. The verified mark means an admin confirmed it.'),
          _Faq('Can I become an admin?', 'Admins are appointed by the W2G team. Contact us through this form if you\'d like to contribute.'),
          _Faq('Is my data safe?', 'Yes. We use Supabase Auth and Row Level Security. Only you can see your private data.'),
          const SizedBox(height: 24),

          Text('QUICK CONTACT', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          _ContactRow(icon: Icons.email_outlined, label: 'Email', value: 'support@welcome2gh.app', onTap: () => _launch('mailto:support@welcome2gh.app')),
          _ContactRow(icon: Icons.phone_outlined, label: 'WIUC Helpdesk', value: '+233 30 395 9999', onTap: () => _launch('tel:+233303959999')),
          const SizedBox(height: 24),

          Text('SEND US A MESSAGE', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _subject,
            style: TextStyle(color: AppColors.white),
            decoration: InputDecoration(hintText: 'Subject (e.g. report a bug, suggest a feature)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _message,
            maxLines: 6,
            style: TextStyle(color: AppColors.white),
            decoration: InputDecoration(hintText: 'Describe your issue or feedback...'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                  : const Text('SEND MESSAGE'),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Faq extends StatefulWidget {
  final String q;
  final String a;
  const _Faq(this.q, this.a);
  @override
  State<_Faq> createState() => _FaqState();
}

class _FaqState extends State<_Faq> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(widget.q, style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600))),
            Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.grey, size: 18),
          ]),
          if (_open) ...[
            const SizedBox(height: 8),
            Text(widget.a, style: TextStyle(color: AppColors.greyLight, fontSize: 13, height: 1.5)),
          ],
        ]),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
  const _ContactRow({required this.icon, required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.navyCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
        child: Row(children: [
          Icon(icon, color: AppColors.yellow, size: 20),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, color: AppColors.grey, size: 14),
        ]),
      ),
    );
  }
}
