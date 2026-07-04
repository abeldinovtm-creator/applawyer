import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Общий источник счётчиков непрочитанного (уведомления + сообщения в чатах)
// для бейджей в меню. ValueNotifier, а не Provider/Riverpod — в проекте
// нет стейт-менеджмента, а виджетов, которым это нужно, всего несколько.
class UnreadCountsService {
  UnreadCountsService._();
  static final instance = UnreadCountsService._();

  final ValueNotifier<int> notifications = ValueNotifier<int>(0);
  // Раздельно: одному аккаунту может быть видно и как клиенту, и как
  // юристу (переключение active_role) — единый счётчик "сообщений"
  // вешал непрочитанное юриста на пункт "Мои заявки", откуда его не
  // открыть, и бейдж никогда не гас.
  final ValueNotifier<int> messagesAsClient = ValueNotifier<int>(0);
  final ValueNotifier<int> messagesAsLawyer = ValueNotifier<int>(0);

  // Точечные id — какие именно беседы/заявки содержат непрочитанное,
  // чтобы подсветить конкретную карточку, а не только показать общее число.
  final ValueNotifier<Set<String>> unreadConversationIds = ValueNotifier<Set<String>>({});
  final ValueNotifier<Set<String>> unreadCaseIds = ValueNotifier<Set<String>>({});

  Future<void> refresh() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      reset();
      return;
    }
    try {
      final result = await Supabase.instance.client.rpc('get_unread_counts');
      final rows = result as List;
      final row = rows.isNotEmpty ? rows.first as Map : <String, dynamic>{};
      notifications.value = (row['unread_notifications'] as num?)?.toInt() ?? 0;
      messagesAsClient.value = (row['unread_messages_client'] as num?)?.toInt() ?? 0;
      messagesAsLawyer.value = (row['unread_messages_lawyer'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    try {
      final idRows = await Supabase.instance.client.rpc('get_unread_conversation_ids') as List;
      unreadConversationIds.value = idRows.map((r) => (r as Map)['conversation_id'].toString()).toSet();
      unreadCaseIds.value = idRows.map((r) => (r as Map)['case_id'].toString()).toSet();
    } catch (_) {}
  }

  void reset() {
    notifications.value = 0;
    messagesAsClient.value = 0;
    messagesAsLawyer.value = 0;
    unreadConversationIds.value = {};
    unreadCaseIds.value = {};
  }
}
