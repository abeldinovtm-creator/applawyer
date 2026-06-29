import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'chat_screen.dart';
import 'region_translations.dart';

String _translateCat(String cat, String lang) {
  if (lang == 'ru') return cat;
  const Map<String, Map<String, String>> _t = {
    'Составить или проверить договор': {'kk': 'Шартты жасау немесе тексеру', 'en': 'Contract drafting/review'},
    'Споры, суды и долги': {'kk': 'Даулар, соттар және борыштар', 'en': 'Disputes & Debts'},
    'Трудовые споры': {'kk': 'Еңбек даулары', 'en': 'Labor disputes'},
    'Семья, брак и развод': {'kk': 'Отбасы, неке және ажырасу', 'en': 'Family & Divorce'},
    'Штрафы, налоги и госорганы': {'kk': 'Айыппұлдар, салықтар', 'en': 'Fines & Taxes'},
    'Бизнес, ИП и ТОО': {'kk': 'Бизнес, ЖК және ЖШС', 'en': 'Business & SME'},
    'Земельные вопросы': {'kk': 'Жер мәселелері', 'en': 'Land issues'},
    'Долги и коллекторы': {'kk': 'Борыштар және коллекторлар', 'en': 'Debts & collectors'},
    'Уголовные дела': {'kk': 'Қылмыстық істер', 'en': 'Criminal cases'},
    'Исполнение решения суда / ЧСИ': {'kk': 'Сот шешімін орындау / ЖСО', 'en': 'Court enforcement'},
    'Другой вопрос': {'kk': 'Басқа сұрақ', 'en': 'Other issue'},
  };
  return _t[cat]?[lang] ?? cat;
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

    return await _supabase
        .from('cases')
        .select('*')
        .eq('client_id', user.id)
        .order('created_at', ascending: false);
  }

  Future<void> _closeOrder(String caseId) async {
    final l = context.locale.languageCode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l == 'kk' ? 'Істі жабу?' : l == 'en' ? 'Close case?' : 'Закрыть заявку?'),
        content: Text(l == 'kk'
            ? 'Заявка аяқталды деп белгіленеді. Растайсыз ба?'
            : l == 'en'
                ? 'The order will be marked as completed. Confirm?'
                : 'Заявка будет отмечена как завершённая. Подтвердить?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l == 'kk' ? 'Жоқ' : l == 'en' ? 'Cancel' : 'Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l == 'kk' ? 'Иә, жабу' : l == 'en' ? 'Yes, close' : 'Да, закрыть',
              style: const TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('cases').update({'status': 'completed'}).eq('id', caseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l == 'kk' ? 'Заявка жабылды' : l == 'en' ? 'Case closed' : 'Заявка закрыта'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _refreshKey++);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Отмена заявки через DELETE — обходим constraint "cases_status_check"
  Future<void> _cancelOrder(String caseId) async {
    final l = context.locale.languageCode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l == 'kk' ? 'Өтінімді жою?' : l == 'en' ? 'Delete order?' : 'Удалить заявку?'),
        content: Text(l == 'kk'
            ? 'Өтінім толығымен жойылады. Растайсыз ба?'
            : l == 'en'
                ? 'The order will be permanently deleted. Confirm?'
                : 'Заявка будет полностью удалена. Подтвердить?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l == 'kk' ? 'Жоқ' : l == 'en' ? 'Cancel' : 'Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l == 'kk' ? 'Иә, жою' : l == 'en' ? 'Yes, delete' : 'Да, удалить',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('cases').delete().eq('id', caseId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l == 'kk' ? 'Өтінім жойылды' : l == 'en' ? 'Order deleted' : 'Заявка удалена'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _refreshKey++); // обновляем список
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatusChip(String status, String lang) {
    Color color;
    String text;

    switch (status) {
      case 'active':
      case 'open':
        color = Colors.blue;
        text = lang == 'kk' ? 'Белсенді' : lang == 'en' ? 'Active' : 'Активна';
        break;
      case 'in_progress':
        color = Colors.orange;
        text = lang == 'kk' ? 'Жұмыста' : lang == 'en' ? 'In progress' : 'В работе';
        break;
      case 'completed':
        color = Colors.green;
        text = lang == 'kk' ? 'Аяқталды' : lang == 'en' ? 'Completed' : 'Завершена';
        break;
      case 'cancelled':
        color = Colors.grey;
        text = lang == 'kk' ? 'Бас тартылды' : lang == 'en' ? 'Cancelled' : 'Отменена';
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
        title: Text(lang == 'kk' ? 'Менің өтінімдерім' : lang == 'en' ? 'My Orders' : 'Мои заявки'),
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
                  return Center(
                    child: Text(lang == 'kk'
                        ? 'Өтінімдер әлі жоқ'
                        : lang == 'en'
                            ? 'You have no orders yet'
                            : 'У вас пока нет созданных заявок'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final String status = order['status'] ?? 'active';
                    final String title = order['title'] ??
                        (lang == 'kk' ? 'Заңгерлік көмек' : lang == 'en' ? 'Legal help' : 'Юридическая помощь');
                    final String desc = order['description'] ?? '';
                    final String region = order['region'] ?? '';
                    final String category = order['category'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _buildStatusChip(status, lang),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (region.isNotEmpty || category.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                children: [
                                  if (category.isNotEmpty)
                                    Chip(
                                      label: Text(_translateCat(category, lang), style: const TextStyle(fontSize: 11)),
                                      backgroundColor: Colors.red[50],
                                      labelStyle: TextStyle(color: Colors.red[700]),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  if (region.isNotEmpty)
                                    Chip(
                                      avatar: const Icon(Icons.location_on_rounded, size: 14, color: Colors.red),
                                      label: Text(translateRegion(region, lang), style: const TextStyle(fontSize: 11)),
                                      backgroundColor: Colors.red[50],
                                      labelStyle: TextStyle(color: Colors.red[700]),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                ],
                              ),
                            const SizedBox(height: 6),
                            Text(
                              desc,
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 14),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  icon: const Icon(Icons.people_outline, color: Colors.red, size: 18),
                                  label: Text(
                                    lang == 'kk' ? 'Өтінімдер' : lang == 'en' ? 'Responses' : 'Отклики',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                                if (status == 'active' ||
                                    status == 'open' ||
                                    status == 'in_progress')
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _closeOrder(order['id'].toString()),
                                        icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                                        label: Text(
                                          lang == 'kk' ? 'Жабу' : lang == 'en' ? 'Close' : 'Закрыть',
                                          style: const TextStyle(color: Colors.green),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _cancelOrder(order['id'].toString()),
                                        icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                        tooltip: lang == 'kk' ? 'Жою' : lang == 'en' ? 'Delete' : 'Удалить',
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
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
