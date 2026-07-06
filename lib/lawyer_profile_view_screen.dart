import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets.dart';

String _trCategory(String cat) {
  const map = {
    'Составить или проверить договор': 'category.contract',
    'Споры, суды и долги': 'category.disputes',
    'Трудовые споры': 'category.labor',
    'Семья, брак и развод': 'category.family',
    'Штрафы, налоги и госорганы': 'category.taxes',
    'Бизнес, ИП и ТОО': 'category.business',
    'Земельные вопросы': 'category.land',
    'Долги и коллекторы': 'category.debts',
    'Уголовные дела': 'category.criminal',
    'Исполнение решения суда': 'category.enforcement',
    'ЧСИ': 'category.pce',
    'Нотариальные услуги': 'category.notary',
    'Другой вопрос': 'category.other',
  };
  final key = map[cat];
  return key != null ? key.tr() : cat;
}

class LawyerProfileViewScreen extends StatelessWidget {
  final Map<String, dynamic> profile;

  const LawyerProfileViewScreen({Key? key, required this.profile}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchCategoryStats() async {
    final lawyerId = profile['id']?.toString();
    if (lawyerId == null) return [];
    final raw = await Supabase.instance.client.rpc('get_lawyer_category_stats', params: {'p_lawyer_id': lawyerId});
    return List<Map<String, dynamic>>.from(raw as List);
  }

  Future<List<Map<String, dynamic>>> _fetchReviews() async {
    final lawyerId = profile['id']?.toString();
    if (lawyerId == null) return [];
    final supabase = Supabase.instance.client;
    final raw = await supabase
        .from('reviews')
        .select('rating, comment, created_at, client_id, is_anonymous')
        .eq('lawyer_id', lawyerId)
        .order('created_at', ascending: false);
    final reviews = List<Map<String, dynamic>>.from(raw as List);
    if (reviews.isEmpty) return reviews;

    // Имя автора подтягиваем только для НЕ анонимных отзывов — для
    // анонимных даже не делаем запрос к profiles, чтобы не тянуть лишние
    // персональные данные, если они не нужны.
    final namedClientIds = reviews
        .where((r) => r['is_anonymous'] != true)
        .map((r) => r['client_id'].toString())
        .toSet()
        .toList();

    Map<String, String> nameByClientId = {};
    if (namedClientIds.isNotEmpty) {
      try {
        final profilesRaw = await supabase
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', namedClientIds);
        for (final p in List<Map<String, dynamic>>.from(profilesRaw as List)) {
          nameByClientId[p['id'].toString()] = p['full_name']?.toString() ?? '';
        }
      } catch (_) {}
    }

    for (final r in reviews) {
      r['_authorName'] = r['is_anonymous'] == true ? null : nameByClientId[r['client_id'].toString()];
    }
    return reviews;
  }

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
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'profile_view.category_stats_title'.tr(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchCategoryStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final stats = snapshot.data ?? [];
                if (stats.isEmpty) {
                  return Text(
                    'profile_view.category_stats_empty'.tr(),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: stats.map((s) {
                    final category = s['category']?.toString() ?? '';
                    final count = (s['completed_count'] as num?)?.toInt() ?? 0;
                    return Chip(
                      label: Text('${_trCategory(category)} · $count', style: const TextStyle(fontSize: 12)),
                      backgroundColor: const Color(0xFFFAE8EB),
                      labelStyle: const TextStyle(color: Color(0xFFA6192E)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'review.section_title'.tr(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchReviews(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final reviews = snapshot.data ?? [];
                if (reviews.isEmpty) {
                  return Text(
                    'review.no_reviews'.tr(),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  );
                }
                final avg = reviews.map((r) => (r['rating'] as num).toDouble()).reduce((a, b) => a + b) /
                    reviews.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StarRatingDisplay(rating: avg, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${avg.toStringAsFixed(1)} · ${reviews.length} ${'review.reviews_count'.tr()}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...reviews.map((r) {
                      final comment = r['comment']?.toString() ?? '';
                      final authorName = r['_authorName']?.toString();
                      final displayAuthor = (authorName != null && authorName.isNotEmpty)
                          ? authorName
                          : 'review.anonymous_author'.tr();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                StarRatingDisplay(rating: (r['rating'] as num).toDouble(), size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  displayAuthor,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            if (comment.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(comment, style: TextStyle(fontSize: 13, color: Colors.grey[800])),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
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
