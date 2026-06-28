import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// Универсальный контрастный компонент для кнопок языка
Widget buildLanguageButton(BuildContext context, String langCode, String label, {required bool isDarkAppBar}) {
  bool isSelected = context.locale.languageCode == langCode;
  
  Color selectedBgDark = Colors.white;
  Color selectedTextDark = Colors.red;
  Color unselectedTextDark = Colors.white70;

  Color selectedBgLight = Colors.red;
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


