import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Одноразовый диалог согласия с тестовым режимом — показывается при первом
// входе, пока profiles.test_mode_acknowledged = false. Закрыть без чекбокса
// нельзя (barrierDismissible: false, без кнопки "Отмена").
Future<void> showTestModeDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _TestModeDialog(),
  );
}

class _TestModeDialog extends StatefulWidget {
  const _TestModeDialog();

  @override
  State<_TestModeDialog> createState() => _TestModeDialogState();
}

class _TestModeDialogState extends State<_TestModeDialog> {
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
          .update({'test_mode_acknowledged': true})
          .eq('id', user.id);
    } catch (_) {
      // Если запись не удалась — не блокируем пользователя диалогом
      // навсегда, диалог просто покажется снова при следующем входе.
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.science_rounded, color: Colors.orange, size: 36),
      title: Text('test_mode.dialog_title'.tr(), textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('test_mode.body'.tr()),
          const SizedBox(height: 16),
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
                    child: Text('test_mode.checkbox_label'.tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
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
              : Text('test_mode.confirm_btn'.tr()),
        ),
      ],
    );
  }
}
