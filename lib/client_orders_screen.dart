import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'chat_screen.dart';
import 'region_translations.dart';
import 'widgets.dart';
import 'services/unread_counts_service.dart';

String _trCat(String cat) {
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

class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({Key? key}) : super(key: key);

  @override
  _ClientOrdersScreenState createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  // Ключ для принудительного перестроения FutureBuilder после удаления
  int _refreshKey = 0;

  Future<List<Map<String, dynamic>>> _fetchMyOrders() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final orders = await _supabase
        .from('cases')
        .select('*')
        .eq('client_id', user.id)
        .order('created_at', ascending: false);

    final list = List<Map<String, dynamic>>.from(orders);
    if (list.isEmpty) return list;

    // Отмечаем, по каким заявкам уже принят юрист — только тогда имеет
    // смысл показывать «Подтвердить завершение» вместо простого «Отменить».
    final caseIds = list.map((o) => o['id'].toString()).toList();
    final acceptedRaw = await _supabase
        .from('conversations')
        .select('case_id')
        .inFilter('case_id', caseIds)
        .eq('status', 'accepted');
    final acceptedCaseIds = List<Map<String, dynamic>>.from(acceptedRaw)
        .map((c) => c['case_id'].toString())
        .toSet();

    // Для завершённых дел нужен lawyer_id (чтобы оставить отзыв) и признак,
    // оставлен ли отзыв уже — берём lawyer_id из escrow_accounts, а не из
    // conversations, т.к. case_id там уникален (один принятый юрист на дело).
    final escrowRaw = await _supabase
        .from('escrow_accounts')
        .select('case_id, lawyer_id')
        .inFilter('case_id', caseIds);
    final lawyerIdByCase = {
      for (final e in List<Map<String, dynamic>>.from(escrowRaw))
        e['case_id'].toString(): e['lawyer_id'].toString()
    };

    final reviewsRaw = await _supabase
        .from('reviews')
        .select('case_id')
        .inFilter('case_id', caseIds);
    final reviewedCaseIds = List<Map<String, dynamic>>.from(reviewsRaw)
        .map((r) => r['case_id'].toString())
        .toSet();

    for (final order in list) {
      final caseId = order['id'].toString();
      order['_hasAcceptedLawyer'] = acceptedCaseIds.contains(caseId);
      order['_lawyerId'] = lawyerIdByCase[caseId];
      order['_hasReview'] = reviewedCaseIds.contains(caseId);
    }
    return list;
  }

  Future<void> _submitReview(String caseId, String lawyerId) async {
    int rating = 0;
    bool isAnonymous = false;
    final commentController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('review.dialog_title'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StarRatingInput(
                rating: rating,
                onChanged: (v) => setDialogState(() => rating = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'review.comment_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              CheckboxListTile(
                value: isAnonymous,
                onChanged: (v) => setDialogState(() => isAnonymous = v ?? false),
                title: Text('review.anonymous_checkbox'.tr(), style: const TextStyle(fontSize: 13)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr()),
            ),
            TextButton(
              onPressed: rating == 0
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text('review.submit'.tr()),
            ),
          ],
        ),
      ),
    );

    if (submitted != true) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('reviews').insert({
        'case_id': caseId,
        'client_id': user.id,
        'lawyer_id': lawyerId,
        'rating': rating,
        'comment': commentController.text.trim().isEmpty ? null : commentController.text.trim(),
        'is_anonymous': isAnonymous,
      });
      if (mounted) {
        showAppSnackBar(context, 'review.submitted'.tr());
        setState(() => _refreshKey++);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Ошибка: $e', kind: SnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Дело закрывается только после подтверждения ОБЕИХ сторон — эта функция
  // ставит только сторону клиента. Остальное (status='completed', списание
  // комиссии) делает серверный триггер, когда юрист подтвердит тоже
  // (см. supabase/migrations/20260703_escrow_commission_dual_confirmation.sql).
  Future<void> _confirmCompletion(String caseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('client.confirm_completion_title'.tr()),
        content: Text('client.confirm_completion_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.no'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.yes_confirm'.tr(), style: const TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('cases')
          .update({'client_confirmed_completion_at': DateTime.now().toIso8601String()})
          .eq('id', caseId);
      if (mounted) {
        setState(() => _refreshKey++);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Ошибка: $e', kind: SnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Отмена заявки через DELETE — обходим constraint "cases_status_check"
  Future<void> _cancelOrder(String caseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('client.delete_confirm_title'.tr()),
        content: Text('client.delete_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.no'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.yes_delete'.tr(), style: const TextStyle(color: const Color(0xFFA6192E))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('cases').delete().eq('id', caseId);

      if (mounted) {
        showAppSnackBar(context, 'client.order_deleted'.tr());
        setState(() => _refreshKey++);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Ошибка: $e', kind: SnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'active':
      case 'open':
        color = Colors.blue;
        text = 'status.active'.tr();
        break;
      case 'in_progress':
        color = Colors.orange;
        text = 'status.in_progress'.tr();
        break;
      case 'completed':
        color = Colors.green;
        text = 'status.completed'.tr();
        break;
      case 'cancelled':
        color = Colors.grey;
        text = 'status.cancelled'.tr();
        break;
      default:
        color = Colors.black45;
        text = status;
    }

    return Chip(
      label: Text(text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text('client.orders_title'.tr()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(_refreshKey),
              future: _fetchMyOrders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Ошибка загрузки данных: ${snapshot.error}'));
                }
                final orders = snapshot.data ?? [];
                if (orders.isEmpty) {
                  return Center(child: Text('client.no_orders'.tr()));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final String status = order['status'] ?? 'active';
                    final String title = order['title'] ?? 'case.legal_help'.tr();
                    final String desc = order['description'] ?? '';
                    final String region = order['region'] ?? '';
                    final String category = order['category'] ?? '';
                    final int totalBudget = ((order['budget'] ?? 0) as num).toInt();
                    final bool hasAcceptedLawyer = order['_hasAcceptedLawyer'] == true;
                    final bool clientConfirmed = order['client_confirmed_completion_at'] != null;
                    final String caseId = order['id'].toString();
                    final bool isUnread = UnreadCountsService.instance.unreadCaseIds.value.contains(caseId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: isUnread ? const Color(0xFFFFF3F3) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isUnread
                            ? const BorderSide(color: Color(0xFFA6192E), width: 1.5)
                            : BorderSide.none,
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                              fontSize: 18, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      ValueListenableBuilder<Set<String>>(
                                        valueListenable: UnreadCountsService.instance.unreadCaseIds,
                                        builder: (_, ids, __) => UnreadDot(show: ids.contains(caseId)),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStatusChip(status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (region.isNotEmpty || category.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                children: [
                                  if (category.isNotEmpty)
                                    Chip(
                                      label: Text(_trCat(category), style: const TextStyle(fontSize: 11)),
                                      backgroundColor: const Color(0xFFFAE8EB),
                                      labelStyle: TextStyle(color: const Color(0xFFA6192E)),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  if (region.isNotEmpty)
                                    Chip(
                                      avatar: const Icon(Icons.location_on_rounded, size: 14, color: const Color(0xFFA6192E)),
                                      label: Text(translateRegion(region, lang), style: const TextStyle(fontSize: 11)),
                                      backgroundColor: const Color(0xFFFAE8EB),
                                      labelStyle: TextStyle(color: const Color(0xFFA6192E)),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                ],
                              ),
                            const SizedBox(height: 6),
                            if (totalBudget > 0) ...[
                              Text('${'filter.budget'.tr()}: $totalBudget ₸',
                                  style: TextStyle(fontSize: 13, color: Colors.green[700], fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                            ],
                            Text(
                              desc,
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 14),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              runSpacing: 6,
                              children: [
                                TextButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ConversationListScreen(
                                        caseId: order['id'].toString(),
                                        caseTitle: title,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.people_outline, color: const Color(0xFFA6192E), size: 18),
                                  label: Text('client.responses'.tr(), style: const TextStyle(color: const Color(0xFFA6192E))),
                                ),
                                if (status == 'active' ||
                                    status == 'open' ||
                                    status == 'in_progress')
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (hasAcceptedLawyer && clientConfirmed)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            'client.waiting_lawyer_confirmation'.tr(),
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        )
                                      else if (hasAcceptedLawyer)
                                        TextButton.icon(
                                          onPressed: () => _confirmCompletion(order['id'].toString()),
                                          icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                                          label: Text('client.confirm_completion'.tr(), style: const TextStyle(color: Colors.green)),
                                        ),
                                      IconButton(
                                        onPressed: () => _cancelOrder(order['id'].toString()),
                                        icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                        tooltip: 'client.delete'.tr(),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                if (status == 'completed' && order['_lawyerId'] != null)
                                  order['_hasReview'] == true
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            'review.review_left'.tr(),
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        )
                                      : TextButton.icon(
                                          onPressed: () => _submitReview(
                                              order['id'].toString(), order['_lawyerId'].toString()),
                                          icon: const Icon(Icons.star_outline_rounded,
                                              color: const Color(0xFFA6192E), size: 18),
                                          label: Text('review.leave_review'.tr(),
                                              style: const TextStyle(color: const Color(0xFFA6192E))),
                                        ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
