import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lawyer_profile_view_screen.dart';

// Список бесед по заявке (для клиента)
class ConversationListScreen extends StatefulWidget {
  final String caseId;
  final String caseTitle;

  const ConversationListScreen({
    Key? key,
    required this.caseId,
    required this.caseTitle,
  }) : super(key: key);

  @override
  _ConversationListScreenState createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  final _supabase = Supabase.instance.client;
  int _refreshKey = 0;

  Future<List<Map<String, dynamic>>> _load() async {
    final convRaw = await _supabase
        .from('conversations')
        .select('id, lawyer_id, created_at, status, price_prepayment, price_on_completion, price_on_result')
        .eq('case_id', widget.caseId)
        .order('created_at', ascending: false);

    final convs = List<Map<String, dynamic>>.from(convRaw as List);
    if (convs.isEmpty) return [];

    final lawyerIds = convs.map((c) => c['lawyer_id'].toString()).toList();

    Map<String, Map<String, dynamic>> profileMap = {};
    try {
      final profileRaw = await _supabase
          .from('profiles')
          .select('*')
          .inFilter('id', lawyerIds);
      for (final p in List<Map<String, dynamic>>.from(profileRaw as List)) {
        profileMap[p['id'].toString()] = p;
      }
    } catch (_) {}

    return convs.map((c) {
      final key = c['lawyer_id'].toString();
      return <String, dynamic>{...c, 'profile': profileMap[key] ?? <String, dynamic>{}};
    }).toList();
  }

  Widget _priceRow(String label, int amount) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.green[700])),
          Text('$amount ₸', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green[900])),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String convId, String status) async {
    await _supabase.from('conversations').update({'status': status}).eq('id', convId);
    setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang == 'kk' ? 'Заңгерлердің жауаптары' : 'Ответы юристов',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              widget.caseTitle,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(_refreshKey),
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Ошибка: ${snap.error}'));
          }
          final convs = snap.data ?? [];
          if (convs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  lang == 'kk'
                      ? 'Заңгерлер әлі жазбаған'
                      : 'Юристы пока не написали по этой заявке',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _refreshKey++),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: convs.length,
              itemBuilder: (context, i) {
                final conv = convs[i];
                final profile = Map<String, dynamic>.from(conv['profile'] as Map? ?? {});
                final convId = conv['id'].toString();
                final status = conv['status']?.toString() ?? 'pending';

                final name = profile['full_name']?.toString() ?? '';
                final city = profile['city']?.toString() ?? '';
                final exp = profile['experience_years'];
                final about = profile['about']?.toString() ?? '';
                final subtype = profile['lawyer_subtype']?.toString() ?? 'lawyer';
                final pricePrepay = conv['price_prepayment'] as int?;
                final priceCompletion = conv['price_on_completion'] as int?;
                final priceResult = conv['price_on_result'] as int?;
                final hasPrice = pricePrepay != null || priceCompletion != null || priceResult != null;

                final subtypeLabel = subtype == 'advocate'
                    ? 'Адвокат'
                    : subtype == 'private_court_executor'
                        ? 'ЧСИ'
                        : (lang == 'kk' ? 'Заңгер' : 'Юрист');

                final displayName = name.isNotEmpty
                    ? name
                    : '${lang == 'kk' ? 'Заңгер' : 'Юрист'} ${i + 1}';

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Профиль юриста
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.red,
                              child: Text(
                                displayName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          subtypeLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.red[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (city.isNotEmpty || (exp != null && exp > 0)) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      [
                                        if (city.isNotEmpty) city,
                                        if (exp != null && exp > 0)
                                          '${lang == 'kk' ? 'тәжірибе' : 'опыт'} $exp ${lang == 'kk' ? 'жыл' : 'лет'}',
                                      ].join(' · '),
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (about.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            about,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                        ],
                        if (hasPrice) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.payments_outlined, size: 15, color: Colors.green[700]),
                                    const SizedBox(width: 6),
                                    Text(
                                      lang == 'kk' ? 'Төлем шарттары' : lang == 'en' ? 'Payment terms' : 'Условия оплаты',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[800]),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (pricePrepay != null)
                                  _priceRow(
                                    lang == 'kk' ? 'Алдын ала төлем' : lang == 'en' ? 'Prepayment' : 'Предоплата',
                                    pricePrepay,
                                  ),
                                if (priceCompletion != null)
                                  _priceRow(
                                    lang == 'kk' ? 'Қызмет көрсетілгеннен кейін' : lang == 'en' ? 'After service' : 'После оказания услуг',
                                    priceCompletion,
                                  ),
                                if (priceResult != null)
                                  _priceRow(
                                    lang == 'kk' ? 'Нәтиже бойынша' : lang == 'en' ? 'On result' : 'По результатам',
                                    priceResult,
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LawyerProfileViewScreen(profile: profile),
                              ),
                            ),
                            icon: const Icon(Icons.person_outline, size: 16),
                            label: Text(lang == 'kk' ? 'Толық профиль' : 'Полный профиль'),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                          ),
                        ),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // Кнопки по статусу
                        if (status == 'pending') ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                    foregroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _updateStatus(convId, 'rejected'),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: Text(lang == 'kk' ? 'Бас тарту' : 'Отклонить'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _updateStatus(convId, 'accepted'),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: Text(lang == 'kk' ? 'Қабылдау' : 'Принять'),
                                ),
                              ),
                            ],
                          ),
                        ] else if (status == 'accepted') ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    conversationId: convId,
                                    caseTitle: widget.caseTitle,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline, size: 16),
                              label: Text(lang == 'kk' ? 'Чатты ашу' : 'Открыть чат'),
                            ),
                          ),
                        ] else ...[
                          // rejected
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.block, size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  lang == 'kk' ? 'Бас тартылды' : 'Отклонён',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// Список откликов юриста
class LawyerConversationListScreen extends StatefulWidget {
  const LawyerConversationListScreen({Key? key}) : super(key: key);

  @override
  _LawyerConversationListScreenState createState() => _LawyerConversationListScreenState();
}

class _LawyerConversationListScreenState extends State<LawyerConversationListScreen> {
  final _supabase = Supabase.instance.client;
  int _refreshKey = 0;

  Future<List<Map<String, dynamic>>> _load() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];

    final convRaw = await _supabase
        .from('conversations')
        .select('id, case_id, created_at, status')
        .eq('lawyer_id', uid)
        .order('created_at', ascending: false);

    final convs = List<Map<String, dynamic>>.from(convRaw as List);
    if (convs.isEmpty) return [];

    final caseIds = convs.map((c) => c['case_id'].toString()).toList();

    Map<String, Map<String, dynamic>> caseMap = {};
    try {
      final casesRaw = await _supabase
          .from('cases')
          .select('id, title, category')
          .inFilter('id', caseIds);
      for (final c in List<Map<String, dynamic>>.from(casesRaw as List)) {
        caseMap[c['id'].toString()] = c;
      }
    } catch (_) {}

    return convs.map((c) {
      return <String, dynamic>{...c, 'case': caseMap[c['case_id'].toString()] ?? <String, dynamic>{}};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang == 'kk' ? 'Менің жауаптарым' : lang == 'en' ? 'My Responses' : 'Мои отклики'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(_refreshKey),
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final convs = snap.data ?? [];
          if (convs.isEmpty) {
            return Center(
              child: Text(
                lang == 'kk' ? 'Отклик жоқ' : lang == 'en' ? 'No responses yet' : 'Откликов пока нет',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _refreshKey++),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: convs.length,
              itemBuilder: (context, i) {
                final conv = convs[i];
                final caseData = Map<String, dynamic>.from(conv['case'] as Map? ?? {});
                final convId = conv['id'].toString();
                final status = conv['status']?.toString() ?? 'pending';
                final caseTitle = caseData['title']?.toString() ?? '';
                final category = caseData['category']?.toString() ?? '';

                Color statusColor;
                String statusLabel;
                switch (status) {
                  case 'accepted':
                    statusColor = Colors.green;
                    statusLabel = lang == 'kk' ? 'Қабылданды' : lang == 'en' ? 'Accepted' : 'Принят';
                    break;
                  case 'rejected':
                    statusColor = Colors.red;
                    statusLabel = lang == 'kk' ? 'Бас тартылды' : lang == 'en' ? 'Rejected' : 'Отклонён';
                    break;
                  default:
                    statusColor = Colors.orange;
                    statusLabel = lang == 'kk' ? 'Күтілуде' : lang == 'en' ? 'Pending' : 'Ожидает';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (category.isNotEmpty)
                          Text(category,
                              style: TextStyle(fontSize: 12, color: Colors.red[700], fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          caseTitle.isNotEmpty ? caseTitle : '—',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withOpacity(0.4)),
                              ),
                              child: Text(statusLabel,
                                  style: TextStyle(
                                      color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            if (status == 'accepted')
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      conversationId: convId,
                                      caseTitle: caseTitle,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                label: Text(lang == 'kk' ? 'Чат' : lang == 'en' ? 'Chat' : 'Чат'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// Экран чата
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String caseTitle;

  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.caseTitle,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  late final Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .order('created_at', ascending: true);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _sending = true);
    try {
      await _supabase.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': uid,
        'text': text,
      });
      _textCtrl.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final myId = _supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Чат', style: TextStyle(fontSize: 16)),
            Text(
              widget.caseTitle,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data ?? [];
                if (msgs.isEmpty) {
                  return Center(
                    child: Text(
                      lang == 'kk'
                          ? 'Хабарламалар жоқ. Алғашқы болып жазыңыз!'
                          : 'Нет сообщений. Напишите первым!',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final msg = msgs[i];
                    final isMe = msg['sender_id'] == myId;
                    return _bubble(msg['text'] ?? '', isMe);
                  },
                );
              },
            ),
          ),
          _inputBar(lang),
        ],
      ),
    );
  }

  Widget _bubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.red : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _inputBar(String lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: lang == 'kk' ? 'Хабарлама...' : 'Сообщение...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _sending
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, color: Colors.red),
                    iconSize: 28,
                  ),
          ],
        ),
      ),
    );
  }
}
