import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Общий источник счётчиков непрочитанного (уведомления + сообщения в чатах)
// для бейджей в меню. ValueNotifier, а не Provider/Riverpod — в проекте
// нет стейт-менеджмента, а виджетов, которым это нужно, всего несколько.
class UnreadCountsService {
  UnreadCountsService._();
  static final instance = UnreadCountsService._();

  final ValueNotifier<int> notifications = ValueNotifier<int>(0);
  final ValueNotifier<int> messages = ValueNotifier<int>(0);

  Future<void> refresh() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      notifications.value = 0;
      messages.value = 0;
      return;
    }
    try {
      final result = await Supabase.instance.client.rpc('get_unread_counts');
      final rows = result as List;
      final row = rows.isNotEmpty ? rows.first as Map : <String, dynamic>{};
      notifications.value = (row['unread_notifications'] as num?)?.toInt() ?? 0;
      messages.value = (row['unread_messages'] as num?)?.toInt() ?? 0;
    } catch (_) {}
  }

  void reset() {
    notifications.value = 0;
    messages.value = 0;
  }
}
