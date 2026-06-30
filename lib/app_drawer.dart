import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'client_orders_screen.dart';
import 'chat_screen.dart';

class AppDrawer extends StatelessWidget {
  final String role;

  const AppDrawer({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'profile.preferred_language'.tr(),
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                children: [
                  _LangChip(code: 'kk', label: 'Қазақша'),
                  const SizedBox(width: 8),
                  _LangChip(code: 'ru', label: 'Русский'),
                  const SizedBox(width: 8),
                  _LangChip(code: 'en', label: 'English'),
                ],
              ),
            ),
            const Divider(),
            if (role == 'client')
              ListTile(
                leading: const Icon(Icons.assignment_turned_in_rounded, color: const Color(0xFFA6192E)),
                title: Text('client.orders_title'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientOrdersScreen()));
                },
              ),
            if (role == 'lawyer')
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: const Color(0xFFA6192E)),
                title: Text('lawyer.my_responses'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LawyerConversationListScreen()));
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String code;
  final String label;

  const _LangChip({required this.code, required this.label});

  @override
  Widget build(BuildContext context) {
    final isSelected = context.locale.languageCode == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => context.setLocale(Locale(code)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFA6192E) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFA6192E) : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
