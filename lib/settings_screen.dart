import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/push_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _pushEnabled = false;
  bool _pushToggling = false;
  bool _notifyNewResponse = true;
  bool _notifyStatusChange = true;
  bool _notifyNewMessage = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await _supabase
          .from('profiles')
          .select('fcm_token, notify_new_response, notify_status_change, notify_new_message')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _pushEnabled = data?['fcm_token'] != null;
          _notifyNewResponse = data?['notify_new_response'] ?? true;
          _notifyStatusChange = data?['notify_status_change'] ?? true;
          _notifyNewMessage = data?['notify_new_message'] ?? true;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  // Общий вкл/выкл push — управляет реальной подпиской в браузере через
  // PushService (запрос разрешения / удаление токена), а не отдельным
  // флагом в БД: наличие fcm_token и есть источник истины.
  Future<void> _togglePush(bool value) async {
    setState(() => _pushToggling = true);
    try {
      if (value) {
        await PushService.init();
      } else {
        await PushService.clearToken();
      }
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('profiles').select('fcm_token').eq('id', user.id).maybeSingle();
        if (mounted) setState(() => _pushEnabled = data?['fcm_token'] != null);
      }
    } finally {
      if (mounted) setState(() => _pushToggling = false);
    }
  }

  Future<void> _saveNotifyPref(String column, bool value) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('profiles').update({column: value}).eq('id', user.id);
    } catch (_) {}
  }

  Future<void> _setLanguage(String code) async {
    context.setLocale(Locale(code));
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('profiles').upsert({'id': user.id, 'preferred_language': code});
    } catch (_) {}
  }

  Widget _sectionHeader(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const Divider(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Читаем context.locale, чтобы экран подписался на смену языка —
    // иначе выделение активного языка ниже не обновится сразу.
    final currentLang = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('profile.preferred_language'.tr()),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final entry in [('kk', 'Қазақша'), ('ru', 'Русский'), ('en', 'English')])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => _setLanguage(entry.$1),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: currentLang == entry.$1 ? const Color(0xFFA6192E) : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: currentLang == entry.$1 ? const Color(0xFFA6192E) : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  entry.$2,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: currentLang == entry.$1 ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _sectionHeader('profile.notifications'.tr()),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFFA6192E),
                    title: Text('profile.push_enabled'.tr()),
                    subtitle: Text('profile.push_enabled_hint'.tr(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    value: _pushEnabled,
                    onChanged: _pushToggling ? null : _togglePush,
                  ),
                  const Divider(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFFA6192E),
                    title: Text('profile.notify_new_response'.tr()),
                    value: _notifyNewResponse,
                    onChanged: (v) {
                      setState(() => _notifyNewResponse = v);
                      _saveNotifyPref('notify_new_response', v);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFFA6192E),
                    title: Text('profile.notify_status_change'.tr()),
                    value: _notifyStatusChange,
                    onChanged: (v) {
                      setState(() => _notifyStatusChange = v);
                      _saveNotifyPref('notify_status_change', v);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFFA6192E),
                    title: Text('profile.notify_new_message'.tr()),
                    value: _notifyNewMessage,
                    onChanged: (v) {
                      setState(() => _notifyNewMessage = v);
                      _saveNotifyPref('notify_new_message', v);
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
