import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'privacy_policy_screen.dart';

// Обязательное согласие с условиями альфа-тестирования — показывается диалогом
// при первом входе после регистрации и при каждом следующем входе, пока
// profiles.alpha_terms_accepted_at пусто. Закрыть без чекбокса нельзя
// (barrierDismissible: false, без кнопки "Отмена").
Future<void> showAlphaTermsDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AlphaTermsDialog(),
  );
}

class _AlphaTermsDialog extends StatefulWidget {
  const _AlphaTermsDialog();

  @override
  State<_AlphaTermsDialog> createState() => _AlphaTermsDialogState();
}

class _AlphaTermsDialogState extends State<_AlphaTermsDialog> {
  bool _checked = false;
  bool _isSaving = false;

  Future<void> _confirm() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'alpha_terms_accepted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', user.id);
    } catch (_) {
      // Если запись не удалась — не блокируем пользователя диалогом
      // навсегда, диалог просто покажется снова при следующем входе.
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _openDoc(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.science_rounded, color: Colors.orange, size: 36),
      title: Text('alpha_terms.dialog_title'.tr(), textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('alpha_terms.body'.tr()),
            const SizedBox(height: 16),
            Text('alpha_terms.links_intro'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _openDoc(const TermsOfServiceScreen()),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'alpha_terms.link_terms'.tr(),
                  style: const TextStyle(color: Color(0xFFA6192E), decoration: TextDecoration.underline),
                ),
              ),
            ),
            InkWell(
              onTap: () => _openDoc(const PrivacyPolicyScreen()),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'alpha_terms.link_privacy'.tr(),
                  style: const TextStyle(color: Color(0xFFA6192E), decoration: TextDecoration.underline),
                ),
              ),
            ),
            InkWell(
              onTap: () => _openDoc(const PersonalDataConsentScreen()),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'alpha_terms.link_pdn'.tr(),
                  style: const TextStyle(color: Color(0xFFA6192E), decoration: TextDecoration.underline),
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _isSaving ? null : () => setState(() => _checked = !_checked),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _checked,
                    onChanged: _isSaving ? null : (v) => setState(() => _checked = v ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('alpha_terms.checkbox_label'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA6192E),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 46),
          ),
          onPressed: (_checked && !_isSaving) ? _confirm : null,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text('alpha_terms.confirm_btn'.tr()),
        ),
      ],
    );
  }
}
