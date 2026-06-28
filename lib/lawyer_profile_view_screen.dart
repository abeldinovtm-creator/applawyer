import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LawyerProfileViewScreen extends StatelessWidget {
  final Map<String, dynamic> profile;

  const LawyerProfileViewScreen({Key? key, required this.profile}) : super(key: key);

  String _subtypeLabel(String subtype, String lang) {
    switch (subtype) {
      case 'advocate':
        return lang == 'kk' ? 'Адвокат' : 'Адвокат';
      case 'private_court_executor':
        return lang == 'kk' ? 'Жеке сот орындаушысы (ЖСО)' : 'Частный судебный исполнитель (ЧСИ)';
      default:
        return lang == 'kk' ? 'Заңгер' : 'Юрист';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final name = profile['full_name']?.toString() ?? '';
    final city = profile['city']?.toString() ?? '';
    final expRaw = profile['experience_years'];
    final exp = expRaw != null ? (expRaw as num).toInt() : 0;
    final about = profile['about']?.toString() ?? '';
    final phone = profile['phone']?.toString() ?? '';
    final subtype = profile['lawyer_subtype']?.toString() ?? 'lawyer';

    final displayName = name.isNotEmpty ? name : (lang == 'kk' ? 'Маман' : 'Специалист');

    return Scaffold(
      appBar: AppBar(
        title: Text(lang == 'kk' ? 'Маман профилі' : 'Профиль специалиста'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.red,
                    child: Text(
                      displayName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 36,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _subtypeLabel(subtype, lang),
                      style: TextStyle(
                        color: Colors.red[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _infoRow(
              Icons.location_on_outlined,
              lang == 'kk' ? 'Қала / Аймақ' : 'Город / Регион',
              city.isNotEmpty ? city : '—',
            ),
            if (exp > 0)
              _infoRow(
                Icons.work_history_outlined,
                lang == 'kk' ? 'Тәжірибе' : 'Опыт работы',
                '$exp ${lang == 'kk' ? 'жыл' : 'лет'}',
              ),
            if (phone.isNotEmpty)
              _infoRow(
                Icons.phone_outlined,
                lang == 'kk' ? 'Телефон' : 'Телефон',
                phone,
              ),
            if (about.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                lang == 'kk' ? 'Өзі туралы' : 'О себе',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                about,
                style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.6),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.red[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
