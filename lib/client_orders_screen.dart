import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'chat_screen.dart';

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

  // Отмена заявки через DELETE — обходим constraint "cases_status_check"
  Future<void> _cancelOrder(String caseId) async {
    final l = context.locale.languageCode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l == 'kk' ? 'Өтінімді жою?' : 'Удалить заявку?'),
        content: Text(l == 'kk'
            ? 'Өтінім толығымен жойылады. Растайсыз ба?'
            : 'Заявка будет полностью удалена. Подтвердить?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l == 'kk' ? 'Жоқ' : 'Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l == 'kk' ? 'Иә, жою' : 'Да, удалить',
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
            content: Text(l == 'kk' ? 'Өтінім жойылды' : 'Заявка удалена'),
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
        text = lang == 'kk' ? 'Белсенді' : 'Активна';
        break;
      case 'in_progress':
        color = Colors.orange;
        text = lang == 'kk' ? 'Жұмыста' : 'В работе';
        break;
      case 'completed':
        color = Colors.green;
        text = lang == 'kk' ? 'Аяқталды' : 'Завершена';
        break;
      case 'cancelled':
        color = Colors.grey;
        text = lang == 'kk' ? 'Бас тартылды' : 'Отменена';
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
        title: Text(lang == 'kk' ? 'Менің өтінімдерім' : 'Мои заявки'),
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
                        (lang == 'kk' ? 'Заңгерлік көмек' : 'Юридическая помощь');
                    final String desc = order['description'] ?? '';

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
                            const SizedBox(height: 8),
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
                                    lang == 'kk' ? 'Өтінімдер' : 'Отклики',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                                if (status == 'active' ||
                                    status == 'open' ||
                                    status == 'in_progress')
                                  TextButton.icon(
                                    onPressed: () => _cancelOrder(order['id'].toString()),
                                    icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                                    label: Text(
                                      lang == 'kk' ? 'Жою' : 'Удалить',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
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
