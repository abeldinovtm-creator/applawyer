import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/push_service.dart';
import 'services/route_persistence.dart';
import 'auth_screen.dart';
import 'privacy_policy_screen.dart';
import 'widgets.dart';

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

  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _changingPass = false;
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    setLastRoute('/settings');
    _load();
  }

  @override
  void dispose() {
    setLastRoute(null);
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
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

  void _showSnack(String msg, Color color) {
    final kind = color == Colors.green
        ? SnackKind.success
        : color == Colors.orange
            ? SnackKind.warning
            : SnackKind.error;
    showAppSnackBar(context, msg, kind: kind);
  }

  Future<void> _changePassword() async {
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (newPass.length < 6) {
      _showSnack('profile.password_min'.tr(), Colors.orange);
      return;
    }
    if (newPass != confirmPass) {
      _showSnack('profile.password_mismatch'.tr(), Colors.orange);
      return;
    }

    setState(() => _changingPass = true);
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPass));
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (mounted) {
        _showSnack('profile.password_changed'.tr(), Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('Ошибка: $e', const Color(0xFFA6192E));
    } finally {
      if (mounted) setState(() => _changingPass = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile.delete_confirm_title'.tr()),
        content: Text('profile.delete_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.yes_delete'.tr(), style: const TextStyle(color: const Color(0xFFA6192E))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await _supabase.rpc('delete_user');
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        _showSnack('Ошибка: $e', const Color(0xFFA6192E));
        setState(() => _deletingAccount = false);
      }
    }
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

                  const SizedBox(height: 32),
                  _sectionHeader('profile.change_password'.tr()),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPassCtrl,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'profile.new_password'.tr(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPassCtrl,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'profile.confirm_password'.tr(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: const Color(0xFFA6192E)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _changingPass ? null : _changePassword,
                    child: _changingPass
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFFA6192E)),
                          )
                        : Text('profile.change_password_btn'.tr(),
                            style: const TextStyle(
                              color: const Color(0xFFA6192E),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  const SizedBox(height: 32),
                  _sectionHeader('profile.documents'.tr()),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.shield_outlined, color: const Color(0xFFA6192E)),
                    title: Text('profile.privacy_policy'.tr()),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined, color: const Color(0xFFA6192E)),
                    title: Text('profile.terms_of_service'.tr()),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen())),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.fact_check_outlined, color: const Color(0xFFA6192E)),
                    title: Text('profile.personal_data_consent'.tr()),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalDataConsentScreen())),
                  ),

                  const SizedBox(height: 24),
                  _sectionHeader('profile.danger_zone'.tr()),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      foregroundColor: Colors.grey[700],
                    ),
                    onPressed: _deletingAccount ? null : _deleteAccount,
                    icon: _deletingAccount
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_forever_outlined),
                    label: Text(
                      'profile.delete_account'.tr(),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
