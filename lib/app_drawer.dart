import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'client_orders_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'statistics_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'auth_screen.dart';
import 'main.dart';
import 'services/unread_counts_service.dart';
import 'widgets.dart';

class AppDrawer extends StatefulWidget {
  final String role;

  const AppDrawer({super.key, required this.role});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // Инициализируется один раз для этого State — не на каждой перестройке
  // родительского экрана (Scaffold.drawer пересоздаёт AppDrawer как виджет
  // при любом setState на экране, но Flutter переиспользует этот State,
  // если бы future был получен инлайн в build(), запрос к Supabase уходил
  // бы заново при каждом ребилде родителя, даже если Drawer не открыт).
  late final Future<bool> _isRealLawyerFuture = _isRealLawyer();

  String get role => widget.role;

  @override
  Widget build(BuildContext context) {
    // Читаем context.locale, чтобы виджет подписался на смену языка —
    // иначе .tr() ниже не обновится сразу при смене языка в "Настройках".
    context.locale;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: const Color(0xFFA6192E),
              child: const Row(
                children: [
                  Icon(Icons.gavel_rounded, color: Colors.white, size: 26),
                  SizedBox(width: 12),
                  Text(
                    'Applawyer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded, color: const Color(0xFFA6192E)),
              title: Text('profile.title'.tr()),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/profile'), builder: (_) => const ProfileScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none_rounded, color: const Color(0xFFA6192E)),
              title: Text('notifications.title'.tr()),
              trailing: ValueListenableBuilder<int>(
                valueListenable: UnreadCountsService.instance.notifications,
                builder: (_, count, __) => CountBadge(count: count),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/notifications'), builder: (_) => const NotificationsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: const Color(0xFFA6192E)),
              title: Text('settings.title'.tr()),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/settings'), builder: (_) => const SettingsScreen()));
              },
            ),
            const Divider(),
            // Переключение в режим юриста доступно только зарегистрированным
            // юристам (profiles.role == 'lawyer') — активная роль (active_role)
            // сама по себе не даёт прав отвечать на заявки (RLS-политика
            // "Юрист создаёт беседу" проверяет базовую role, а не active_role),
            // поэтому клиенту показывать эту кнопку нельзя — иначе он попадает
            // в лже-режим юриста, где страница выглядит рабочей, но любой
            // отклик падает с ошибкой RLS 42501.
            if (role == 'lawyer')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: OutlinedButton.icon(
                  onPressed: () => _switchRole(context, role),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFA6192E),
                    side: const BorderSide(color: Color(0xFFA6192E)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.person_outline_rounded),
                  label: Text('role_switch.to_client'.tr()),
                ),
              )
            else
              FutureBuilder<bool>(
                future: _isRealLawyerFuture,
                builder: (context, snap) {
                  if (snap.data != true) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _switchRole(context, role),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA6192E),
                        side: const BorderSide(color: Color(0xFFA6192E)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.gavel_rounded),
                      label: Text('role_switch.to_lawyer'.tr()),
                    ),
                  );
                },
              ),
            const Divider(),
            if (role == 'client')
              ListTile(
                leading: const Icon(Icons.assignment_turned_in_rounded, color: const Color(0xFFA6192E)),
                title: Text('client.orders_title'.tr()),
                trailing: ValueListenableBuilder<int>(
                  valueListenable: UnreadCountsService.instance.messagesAsClient,
                  builder: (_, count, __) => CountBadge(count: count),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientOrdersScreen()));
                },
              ),
            if (role == 'lawyer') ...[
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: const Color(0xFFA6192E)),
                title: Text('lawyer.my_responses'.tr()),
                trailing: ValueListenableBuilder<int>(
                  valueListenable: UnreadCountsService.instance.messagesAsLawyer,
                  builder: (_, count, __) => CountBadge(count: count),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LawyerConversationListScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart_rounded, color: const Color(0xFFA6192E)),
                title: Text('lawyer.statistics_menu'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen()));
                },
              ),
            ],
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.grey),
              title: Text('common.logout'.tr(), style: TextStyle(color: Colors.grey[800])),
              onTap: () async {
                // Navigator сохраняем ДО await и pop() — после закрытия меню и
                // сигнала signOut() этот BuildContext может успеть размонтироваться,
                // из-за чего переход на экран входа раньше просто не происходил.
                final navigator = Navigator.of(context, rootNavigator: true);
                Navigator.pop(context);
                await Supabase.instance.client.auth.signOut();
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (_) => false,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _isRealLawyer() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return data?['role'] == 'lawyer';
    } catch (_) {
      return false;
    }
  }

  // Переключает active_role в profiles и перезапускает AuthRouter,
  // чтобы он заново прочитал роль из БД и показал нужный экран.
  // Основная role в БД не меняется — только active_role.
  Future<void> _switchRole(BuildContext context, String currentRole) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final newRole = currentRole == 'lawyer' ? 'client' : 'lawyer';

    // Повторная проверка на случай гонки/устаревшего UI — переключиться в
    // режим юриста может только реально зарегистрированный юрист.
    if (newRole == 'lawyer' && !await _isRealLawyer()) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    Navigator.pop(context);

    await Supabase.instance.client
        .from('profiles')
        .upsert({'id': user.id, 'active_role': newRole});

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthRouter()),
      (_) => false,
    );
  }
}
