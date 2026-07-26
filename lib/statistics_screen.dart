import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/lawyer_stats_service.dart';
import 'services/route_persistence.dart';
import 'widgets.dart';

const _kGreen = Color(0xFF2E7D32);
const _kRed = Color(0xFFC62828);
const _kOrange = Color(0xFFE65100);
const _kBrand = Color(0xFFA6192E);

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

String _money(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

class _StatisticsData {
  final LawyerCaseCounts counts;
  final int cancelled;
  final LawyerEarnings earnings;
  final ({double average, int count}) rating;

  const _StatisticsData({
    required this.counts,
    required this.cancelled,
    required this.earnings,
    required this.rating,
  });
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late final Future<_StatisticsData> _future = _load();

  @override
  void initState() {
    super.initState();
    setLastRoute('/statistics');
  }

  @override
  void dispose() {
    setLastRoute(null);
    super.dispose();
  }

  Future<_StatisticsData> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const _StatisticsData(
        counts: LawyerCaseCounts(completed: 0, active: 0),
        cancelled: 0,
        earnings: LawyerEarnings.empty,
        rating: (average: 0.0, count: 0),
      );
    }
    final results = await Future.wait([
      LawyerStatsService.fetchCaseCounts(user.id),
      LawyerStatsService.fetchCancellationCount(user.id),
      LawyerStatsService.fetchEarnings(user.id),
      LawyerStatsService.fetchAverageRating(user.id),
    ]);
    return _StatisticsData(
      counts: results[0] as LawyerCaseCounts,
      cancelled: results[1] as int,
      earnings: results[2] as LawyerEarnings,
      rating: results[3] as ({double average, int count}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('lawyer.statistics_menu'.tr())),
      body: FutureBuilder<_StatisticsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('lawyer.statistics_load_error'.tr()));
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'profile.completed_cases'.tr(),
                      value: '${data.counts.completed}',
                      color: _kGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: 'profile.active_cases'.tr(),
                      value: '${data.counts.active}',
                      color: _kOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: 'lawyer.statistics_cancelled'.tr(),
                      value: '${data.cancelled}',
                      color: _kRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _CompletedVsCancelledChart(completed: data.counts.completed, cancelled: data.cancelled),
              const SizedBox(height: 12),
              if (data.rating.count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      StarRatingDisplay(rating: data.rating.average, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${data.rating.average.toStringAsFixed(1)} · ${data.rating.count} ${'review.reviews_count'.tr()}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'lawyer.statistics_earnings_title'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'lawyer.statistics_earnings_hint'.tr(),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'lawyer.statistics_earned_total'.tr(),
                      value: '${_money(data.earnings.totalPayout)} ₸',
                      color: _kGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: 'lawyer.statistics_in_progress'.tr(),
                      value: '${_money(data.earnings.inProgressAmount)} ₸',
                      color: _kOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              StatCard(
                label: 'lawyer.statistics_commission_total'.tr(),
                value: '${_money(data.earnings.totalCommission)} ₸',
                color: Colors.grey,
              ),
              const SizedBox(height: 20),
              Text(
                'lawyer.statistics_earnings_by_category'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (data.earnings.byCategory.isEmpty)
                Text(
                  'lawyer.statistics_no_earnings'.tr(),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                )
              else ...[
                _EarningsByCategoryChart(byCategory: data.earnings.byCategory),
                const SizedBox(height: 16),
                ...data.earnings.byCategory.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_trCategory(e.category),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  '${e.casesCount} ${'profile.completed_cases'.tr().toLowerCase()}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${_money(e.payoutAmount)} ₸',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kBrand),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

// Столбчатая диаграмма "Завершено / Отменено" — сравнение двух счётчиков
// одной размерности (число дел), поэтому одна общая ось Y.
class _CompletedVsCancelledChart extends StatelessWidget {
  final int completed;
  final int cancelled;

  const _CompletedVsCancelledChart({required this.completed, required this.cancelled});

  @override
  Widget build(BuildContext context) {
    final maxVal = [completed, cancelled, 1].reduce((a, b) => a > b ? a : b).toDouble();
    return SizedBox(
      height: 170,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.3,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                rod.toY.round().toString(),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final label =
                      value.round() == 0 ? 'profile.completed_cases'.tr() : 'lawyer.statistics_cancelled'.tr();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(x: 0, barRods: [
              BarChartRodData(
                toY: completed.toDouble(),
                color: _kGreen,
                width: 44,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ]),
            BarChartGroupData(x: 1, barRods: [
              BarChartRodData(
                toY: cancelled.toDouble(),
                color: _kRed,
                width: 44,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// Заработок по категориям — горизонтально прокручиваемая полоса столбцов,
// т.к. число категорий заранее не ограничено (см. _trCategory) и фиксированная
// ширина экрана не гарантирует читаемые подписи под каждым столбцом.
class _EarningsByCategoryChart extends StatelessWidget {
  final List<LawyerCategoryEarning> byCategory;

  const _EarningsByCategoryChart({required this.byCategory});

  @override
  Widget build(BuildContext context) {
    final maxVal = byCategory.map((e) => e.payoutAmount.toDouble()).reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal <= 0 ? 1.0 : maxVal;
    return SizedBox(
      height: 210,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: byCategory.length * 76.0,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: safeMax * 1.3,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    '${_money(rod.toY)} ₸',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 || i >= byCategory.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: 68,
                          child: Text(
                            _trCategory(byCategory[i].category),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < byCategory.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: byCategory[i].payoutAmount.toDouble(),
                      color: _kBrand,
                      width: 28,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
