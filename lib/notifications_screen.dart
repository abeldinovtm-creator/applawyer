import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/unread_counts_service.dart';
import 'widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;

  // Какие уведомления были непрочитаны ДО открытия этого экрана — сам
  // экран сразу помечает всё прочитанным (для бейджа в меню), но точку
  // "новое" на конкретном пункте показываем по этому снимку состояния,
  // иначе она пропадала бы мгновенно вместе с бейджем.
  Set<String> _unreadIds = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];

    final raw = await _supabase
        .from('notifications')
        .select()
        .or('recipient_id.eq.$uid,recipient_id.is.null')
        .order('created_at', ascending: false);

    final items = List<Map<String, dynamic>>.from(raw as List);

    try {
      final readRows = await _supabase
          .from('notification_reads')
          .select('notification_id')
          .eq('user_id', uid);
      final alreadyRead = Set<String>.from(
          List<Map<String, dynamic>>.from(readRows as List).map((r) => r['notification_id'].toString()));
      _unreadIds = items.map((n) => n['id'].toString()).where((id) => !alreadyRead.contains(id)).toSet();
    } catch (_) {}

    await _markAllRead(items, uid);
    return items;
  }

  // Отмечаем всё показанное как прочитанное — ignoreDuplicates, чтобы не
  // затирать read_at у уже прочитанных записей повторным открытием экрана.
  Future<void> _markAllRead(List<Map<String, dynamic>> items, String uid) async {
    if (items.isEmpty) return;
    try {
      await _supabase.from('notification_reads').upsert(
        items.map((n) => {'notification_id': n['id'], 'user_id': uid}).toList(),
        onConflict: 'notification_id,user_id',
        ignoreDuplicates: true,
      );
      UnreadCountsService.instance.refresh();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('notifications.title'.tr())),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 56, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'notifications.empty'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = items[i];
                final title = n['title']?.toString() ?? '';
                final body = n['body']?.toString() ?? '';
                final createdAt = DateTime.tryParse(n['created_at']?.toString() ?? '');
                final isUnread = _unreadIds.contains(n['id'].toString());

                return Card(
                  elevation: 0,
                  color: isUnread ? const Color(0xFFFFF3F3) : Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isUnread
                        ? const BorderSide(color: Color(0xFFA6192E), width: 1.5)
                        : BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notifications_rounded, color: Color(0xFFA6192E)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ),
                                  const SizedBox(width: 6),
                                  UnreadDot(show: _unreadIds.contains(n['id'].toString())),
                                ],
                              ),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(body, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                              ],
                              if (createdAt != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year} '
                                  '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
