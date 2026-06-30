import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

enum SnackKind { success, error, warning }

void showAppSnackBar(BuildContext context, String message, {SnackKind kind = SnackKind.success}) {
  Color color;
  IconData icon;
  if (kind == SnackKind.error) {
    color = const Color(0xFFC62828);
    icon = Icons.error_outline_rounded;
  } else if (kind == SnackKind.warning) {
    color = const Color(0xFFE65100);
    icon = Icons.warning_amber_rounded;
  } else {
    color = const Color(0xFF2E7D32);
    icon = Icons.check_circle_outline_rounded;
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
}

// Кнопка переключения языка — StatelessWidget со своим контекстом
class LanguageButton extends StatelessWidget {
  final String langCode;
  final String label;
  final bool isDarkAppBar;

  const LanguageButton({
    super.key,
    required this.langCode,
    required this.label,
    required this.isDarkAppBar,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = context.locale.languageCode == langCode;

    final selectedBg   = isDarkAppBar ? Colors.white : const Color(0xFFA6192E);
    final selectedText = isDarkAppBar ? const Color(0xFFA6192E) : Colors.white;
    final unselectedText = isDarkAppBar ? Colors.white70 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 10.0),
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? selectedBg : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: () => context.setLocale(Locale(langCode)),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? selectedText : unselectedText,
          ),
        ),
      ),
    );
  }
}


