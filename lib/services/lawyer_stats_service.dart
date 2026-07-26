import 'package:supabase_flutter/supabase_flutter.dart';

class LawyerCaseCounts {
  final int completed;
  final int active;

  const LawyerCaseCounts({required this.completed, required this.active});
}

class LawyerCategoryStat {
  final String category;
  final int completedCount;

  const LawyerCategoryStat({required this.category, required this.completedCount});
}

class LawyerCategoryEarning {
  final String category;
  final int casesCount;
  final num grossAmount;
  final num payoutAmount;

  const LawyerCategoryEarning({
    required this.category,
    required this.casesCount,
    required this.grossAmount,
    required this.payoutAmount,
  });
}

class LawyerEarnings {
  final List<LawyerCategoryEarning> byCategory;
  final num totalPayout;
  final num totalCommission;
  final num inProgressAmount;

  const LawyerEarnings({
    required this.byCategory,
    required this.totalPayout,
    required this.totalCommission,
    required this.inProgressAmount,
  });

  static const empty = LawyerEarnings(
    byCategory: [],
    totalPayout: 0,
    totalCommission: 0,
    inProgressAmount: 0,
  );
}

// Общая статистика юриста — используется и в профиле (краткая сводка),
// и в отдельном экране "Статистика" (полная версия с заработком).
// Вынесено в сервис, чтобы не дублировать запросы в двух экранах.
class LawyerStatsService {
  static final _supabase = Supabase.instance.client;

  // Считаем по заявкам, где отклик юриста был принят клиентом
  // (conversations.status == accepted).
  static Future<LawyerCaseCounts> fetchCaseCounts(String lawyerId) async {
    final convRaw = await _supabase
        .from('conversations')
        .select('case_id')
        .eq('lawyer_id', lawyerId)
        .eq('status', 'accepted');
    final caseIds = List<Map<String, dynamic>>.from(convRaw as List)
        .map((c) => c['case_id'].toString())
        .toList();

    if (caseIds.isEmpty) {
      return const LawyerCaseCounts(completed: 0, active: 0);
    }

    final casesRaw = await _supabase.from('cases').select('status').inFilter('id', caseIds);
    final cases = List<Map<String, dynamic>>.from(casesRaw as List);
    final completed = cases.where((c) => c['status'] == 'completed').length;
    return LawyerCaseCounts(completed: completed, active: cases.length - completed);
  }

  static Future<List<LawyerCategoryStat>> fetchCategoryStats(String lawyerId) async {
    final raw = await _supabase.rpc('get_lawyer_category_stats', params: {'p_lawyer_id': lawyerId});
    return List<Map<String, dynamic>>.from(raw as List)
        .map((s) => LawyerCategoryStat(
              category: s['category']?.toString() ?? '',
              completedCount: (s['completed_count'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  // Заработок виден только самому юристу — RPC get_lawyer_earnings_stats()
  // не принимает id, всегда берёт auth.uid() на стороне БД.
  // Требует миграции 20260726_lawyer_earnings_stats.sql.
  static Future<LawyerEarnings> fetchEarnings(String lawyerId) async {
    final byCategoryRaw = await _supabase.rpc('get_lawyer_earnings_stats');
    final byCategory = List<Map<String, dynamic>>.from(byCategoryRaw as List)
        .map((e) => LawyerCategoryEarning(
              category: e['category']?.toString() ?? '',
              casesCount: (e['cases_count'] as num?)?.toInt() ?? 0,
              grossAmount: (e['gross_amount'] as num?) ?? 0,
              payoutAmount: (e['payout_amount'] as num?) ?? 0,
            ))
        .toList();

    final totalPayout = byCategory.fold<num>(0, (sum, e) => sum + e.payoutAmount);
    final totalCommission = byCategory.fold<num>(0, (sum, e) => sum + (e.grossAmount - e.payoutAmount));

    // Деньги ещё не выплачены (эскроу создан, дело не завершено обеими
    // сторонами) — прямой запрос к escrow_accounts, своя RLS-политика
    // (escrow_select_own) уже это разрешает без отдельной RPC.
    final pendingRaw = await _supabase
        .from('escrow_accounts')
        .select('amount')
        .eq('lawyer_id', lawyerId)
        .neq('status', 'released');
    final inProgressAmount = List<Map<String, dynamic>>.from(pendingRaw as List)
        .fold<num>(0, (sum, row) => sum + ((row['amount'] as num?) ?? 0));

    return LawyerEarnings(
      byCategory: byCategory,
      totalPayout: totalPayout,
      totalCommission: totalCommission,
      inProgressAmount: inProgressAmount,
    );
  }

  static Future<int> fetchCancellationCount(String lawyerId) async {
    final raw = await _supabase.rpc('get_lawyer_cancellation_count');
    return (raw as num?)?.toInt() ?? 0;
  }

  static Future<({double average, int count})> fetchAverageRating(String lawyerId) async {
    final raw = await _supabase.from('reviews').select('rating').eq('lawyer_id', lawyerId);
    final ratings = List<Map<String, dynamic>>.from(raw as List)
        .map((r) => (r['rating'] as num).toDouble())
        .toList();
    if (ratings.isEmpty) return (average: 0.0, count: 0);
    return (average: ratings.reduce((a, b) => a + b) / ratings.length, count: ratings.length);
  }
}
