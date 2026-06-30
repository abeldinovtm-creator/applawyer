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

// Универсальный контрастный компонент для кнопок языка
Widget buildLanguageButton(BuildContext context, String langCode, String label, {required bool isDarkAppBar}) {
  bool isSelected = context.locale.languageCode == langCode;
  
  Color selectedBgDark = Colors.white;
  Color selectedTextDark = const Color(0xFFA6192E);
  Color unselectedTextDark = Colors.white70;

  Color selectedBgLight = const Color(0xFFA6192E);
  Color selectedTextLight = Colors.white;
  Color unselectedTextLight = Colors.black54;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 10.0),
    child: TextButton(
      style: TextButton.styleFrom(
        backgroundColor: isSelected 
            ? (isDarkAppBar ? selectedBgDark : selectedBgLight) 
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isSelected
              ? (isDarkAppBar ? selectedTextDark : selectedTextLight)
              : (isDarkAppBar ? unselectedTextDark : unselectedTextLight),
        ),
      ),
      onPressed: () => context.setLocale(Locale(langCode)),
    ),
  );
}


