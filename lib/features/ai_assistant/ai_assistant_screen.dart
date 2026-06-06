import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/supabase_service.dart';

const _kGreeting =
    'Akwaaba! 👋 I\'m your local Ghanaian guide. Ask me anything about Accra: safe spots, cheap food, transport prices, places to avoid, student tips and more!';

class _Message {
  final String text;
  final bool isUser;
  _Message({required this.text, required this.isUser});
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  final _messages = <_Message>[
    _Message(text: _kGreeting, isUser: false),
  ];
  bool _typing = false;

  final _suggestions = [
    'Best cheap restaurants near Legon?',
    'Normal taxi price from airport to Osu?',
    'Safe areas to stay as a student?',
    'Quiet cafes to study in Accra?',
    'What areas should I avoid at night?',
  ];

  final _responses = {
    'restaurants': 'Great choice! Near Legon campus, try **Papaye** (GHS 25-40 for full meal), **KFC Legon** (GHS 35-55), or local chop bars around the campus gate for GHS 15-25. The chop bars serve the most authentic jollof and fufu!',
    'taxi': 'The normal price from Kotoka Airport to Osu is **GHS 80-100** by regular taxi. If someone quotes GHS 200+, walk away. Uber is usually GHS 60-80. Always agree on the price before getting in!',
    'safe': 'Safest student areas include **Legon** (near UG), **East Legon**, **Airport Residential**, and **Adenta**. These areas have good lighting, security presence and are familiar with international students.',
    'cafe': 'For quiet study spots, try **Woodin Café** in East Legon, **Republic Bar** (quiet during day), **the UG Library** (open 24/7 during exams), or **Cuppa Coffee** in Osu.',
    'avoid': 'At night, be cautious around **Nima**, **Newtown**, **Agbogbloshie** and very busy markets like Makola. These areas are fine during the day but get risky after dark. Always use Uber at night.',
  };

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _typing) return;
    setState(() {
      _messages.add(_Message(text: text, isUser: true));
      _typing = true;
    });
    _ctrl.clear();
    _scrollToBottom();

    try {
      // Build conversation history for the API, skipping the initial greeting.
      final history = _messages
          .skip(1)
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
          .toList();

      // Best-effort location for context.
      double? lat, lng;
      try {
        if (await Geolocator.checkPermission() != LocationPermission.denied) {
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low)
              .timeout(const Duration(seconds: 4));
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } catch (_) {/* location optional */}

      final profile = await SupabaseService.instance.getMyProfile();

      final reply = await SupabaseService.instance.askAiGuide(
        history: history,
        role: profile?.role,
        nationality: profile?.nationality,
        lat: lat,
        lng: lng,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(_Message(text: reply, isUser: false));
        _typing = false;
      });
      _scrollToBottom();
    } catch (e) {
      // Graceful fallback to local canned answers if the backend isn't ready.
      if (!mounted) return;
      setState(() {
        _messages.add(_Message(text: _fallbackReply(text), isUser: false));
        _typing = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  String _fallbackReply(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('restaurant') || lower.contains('food') || lower.contains('eat')) return _responses['restaurants']!;
    if (lower.contains('taxi') || lower.contains('price') || lower.contains('airport')) return _responses['taxi']!;
    if (lower.contains('safe') || lower.contains('stay') || lower.contains('hostel')) return _responses['safe']!;
    if (lower.contains('cafe') || lower.contains('study') || lower.contains('quiet')) return _responses['cafe']!;
    if (lower.contains('avoid') || lower.contains('night') || lower.contains('danger')) return _responses['avoid']!;
    return 'I\'m having trouble reaching my brain right now (the AI service may not be set up yet). In the meantime: explore Osu for nightlife, Labadi Beach to relax, and always check the map\'s safety levels before heading somewhere new.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_messages.length > 1)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.grey),
              tooltip: 'Clear chat',
              onPressed: () => setState(() {
                _messages
                  ..clear()
                  ..add(_Message(text: _kGreeting, isUser: false));
              }),
            ),
        ],
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.yellow, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI LOCAL GUIDE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                Text('Your Ghanaian companion', style: TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.normal)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_typing ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) return _TypingBubble();
                return _ChatBubble(message: _messages[i]);
              },
            ),
          ),
          // Suggestions (show until user has sent their first message)
          if (!_messages.any((m) => m.isUser))
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _suggestions.map((s) => GestureDetector(
                  onTap: () => _send(s),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.navyCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Text(s, style: TextStyle(color: AppColors.greyLight, fontSize: 12)),
                  ),
                )).toList(),
              ),
            ),
          const SizedBox(height: 8),
          // Input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.navyLight,
              border: Border(top: BorderSide(color: AppColors.cardBorder)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: TextStyle(color: AppColors.white),
                      onSubmitted: _send,
                      decoration: InputDecoration(
                        hintText: 'Ask about Accra...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _send(_ctrl.text),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.yellow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.send_rounded, color: AppColors.navy, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _Message message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.yellow : AppColors.navyCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: AppColors.cardBorder),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? AppColors.navy : AppColors.white,
            fontSize: 14,
            height: 1.5,
            fontWeight: isUser ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.navyCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _Dot(delay: i * 200)),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: AppColors.grey, shape: BoxShape.circle),
      ),
    );
  }
}
