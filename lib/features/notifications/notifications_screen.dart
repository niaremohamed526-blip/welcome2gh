import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/time_utils.dart';
import '../../core/supabase_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = SupabaseService.instance.watchNotifications();
    // Opening the screen clears the unread badge.
    SupabaseService.instance.markAllNotificationsRead();
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'like': return Icons.favorite_rounded;
      case 'comment': return Icons.chat_bubble_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'like': return const Color(0xFFEF5350);
      case 'comment': return const Color(0xFF42A5F5);
      default: return AppColors.yellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        title: Text('Notifications', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: AppColors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.yellow));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.notifications_off_rounded, color: AppColors.grey.withValues(alpha: 0.4), size: 56),
                const SizedBox(height: 12),
                Text('No notifications yet', style: TextStyle(color: AppColors.grey)),
                const SizedBox(height: 4),
                Text("You'll be notified when someone likes or comments on your posts.",
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey, fontSize: 12)),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final n = items[i];
              final data = n['data'] as Map<String, dynamic>?;
              final type = data?['type']?.toString();
              final created = DateTime.tryParse(n['created_at']?.toString() ?? '') ?? DateTime.now();
              final unread = n['read'] != true;
              final color = _colorFor(type);
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: unread ? AppColors.navyCard : AppColors.navy,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: unread ? color.withValues(alpha: 0.4) : AppColors.cardBorder),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(_iconFor(type), color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n['title']?.toString() ?? '', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    if ((n['body']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(n['body'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.greyLight, fontSize: 12)),
                    ],
                    const SizedBox(height: 4),
                    Text(timeAgo(created), style: TextStyle(color: AppColors.grey, fontSize: 11)),
                  ])),
                  if (unread) Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
