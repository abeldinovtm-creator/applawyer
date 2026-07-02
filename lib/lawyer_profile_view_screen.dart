import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LawyerProfileViewScreen extends StatelessWidget {
  final Map<String, dynamic> profile;

  const LawyerProfileViewScreen({Key? key, required this.profile}) : super(key: key);

  String _subtypeLabel(String subtype) {
    switch (subtype) {
      case 'advocate':
        return 'specialist.advocate'.tr();
      case 'private_court_executor':
        return 'specialist.pce_full'.tr();
      case 'notary':
        return 'specialist.notary'.tr();
      default:
        return 'specialist.lawyer'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = profile['full_name']?.toString() ?? '';
    final city = profile['city']?.toString() ?? '';
    final expRaw = profile['experience_years'];
    final exp = expRaw != null ? (expRaw as num).toInt() : 0;
    final about = profile['about']?.toString() ?? '';
    final phone = profile['phone']?.toString() ?? '';
    final subtype = profile['lawyer_subtype']?.toString() ?? 'lawyer';

    final displayName = name.isNotEmpty ? name : 'profile_view.specialist'.tr();

    return Scaffold(
      appBar: AppBar(
        title: Text('profile_view.title'.tr()),
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
                    backgroundColor: const Color(0xFFA6192E),
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
                      color: const Color(0xFFFAE8EB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCF8A97)),
                    ),
                    child: Text(
                      _subtypeLabel(subtype),
                      style: TextStyle(
                        color: const Color(0xFF8A1525),
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
              'profile_view.city'.tr(),
              city.isNotEmpty ? city : '—',
            ),
            if (exp > 0)
              _infoRow(
                Icons.work_history_outlined,
                'profile_view.experience'.tr(),
                '$exp ${'profile_view.years'.tr()}',
              ),
            if (phone.isNotEmpty)
              _infoRow(
                Icons.phone_outlined,
                'profile_view.phone'.tr(),
                phone,
              ),
            if (about.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'profile_view.about'.tr(),
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
          Icon(icon, size: 20, color: const Color(0xFFA6192E)),
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
