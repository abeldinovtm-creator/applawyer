import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets.dart';
import 'auth_screen.dart';
import 'main.dart';
import 'region_picker_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class LawyerDashboardScreen extends StatefulWidget {
  final String lawyerSubtype;

  const LawyerDashboardScreen({Key? key, required this.lawyerSubtype}) : super(key: key);

  @override
  _LawyerDashboardScreenState createState() => _LawyerDashboardScreenState();
}

class _LawyerDashboardScreenState extends State<LawyerDashboardScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _casesFuture;
  String _selectedCategory = 'Все';
  String _selectedServiceType = 'Все';
  String _selectedRegion = 'Все регионы';
  int? _budgetFrom;
  int? _budgetTo;

  // Категории, доступные по подтипу специалиста
  static List<String> _allowedCategories(String subtype) {
    if (subtype == 'private_court_executor') {
      return ['Исполнение решения суда / ЧСИ'];
    } else if (subtype == 'lawyer') {
      return [
        'Составить или проверить договор', 'Споры, суды и долги',
        'Трудовые споры', 'Семья, брак и развод', 'Штрафы, налоги и госорганы',
        'Бизнес, ИП и ТОО', 'Земельные вопросы', 'Долги и коллекторы',
        'Исполнение решения суда / ЧСИ', 'Другой вопрос',
      ];
    } else {
      // advocate — все категории
      return [
        'Составить или проверить договор', 'Споры, суды и долги',
        'Трудовые споры', 'Семья, брак и развод', 'Штрафы, налоги и госорганы',
        'Бизнес, ИП и ТОО', 'Земельные вопросы', 'Долги и коллекторы',
        'Уголовные дела', 'Исполнение решения суда / ЧСИ', 'Другой вопрос',
      ];
    }
  }

  static String _subtypeLabel(String subtype, String lang) {
    switch (subtype) {
      case 'advocate':
        return lang == 'kk' ? 'Адвокат' : 'Адвокат';
      case 'private_court_executor':
        return lang == 'kk' ? 'ЖСО' : 'ЧСИ';
      default:
        return lang == 'kk' ? 'Заңгер' : 'Юрист';
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshCases();
  }

  void _refreshCases() {
    final allowed = _allowedCategories(widget.lawyerSubtype);
    setState(() {
      _casesFuture = _supabase
          .from('cases')
          .select()
          .order('id', ascending: false)
          .then((value) {
            var list = List<Map<String, dynamic>>.from(value);

            // Фильтрация по разрешённым категориям для подтипа
            list = list.where((c) => allowed.contains(c['category'])).toList();

            if (_selectedCategory != 'Все') {
              list = list.where((c) => c['category'] == _selectedCategory).toList();
            }

            if (_selectedServiceType != 'Все') {
              list = list.where((c) => c['service_type'] == _selectedServiceType).toList();
            }

            if (_selectedRegion != 'Все регионы') {
              list = list.where((c) =>
                (c['region'] ?? '').toString().contains(_selectedRegion) ||
                c['region'] == _selectedRegion
              ).toList();
            }

            if (_budgetFrom != null) {
              list = list.where((c) => ((c['budget'] ?? 0) as num).toInt() >= _budgetFrom!).toList();
            }

            if (_budgetTo != null) {
              list = list.where((c) => ((c['budget'] ?? 0) as num).toInt() <= _budgetTo!).toList();
            }

            return list;
          });
    });
  }

  Future<void> _sendResponse(String caseId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final lang = context.locale.languageCode;

    // Проверяем существующий отклик
    final existing = await _supabase
        .from('conversations')
        .select('id, status')
        .eq('case_id', caseId)
        .eq('lawyer_id', user.id)
        .maybeSingle();

    if (existing != null) {
      final status = existing['status']?.toString() ?? 'pending';
      String msg;
      Color color;
      if (status == 'rejected') {
        msg = lang == 'kk' ? 'Клиент сіздің өтінімді қабылдамады' : 'Клиент отклонил ваш отклик';
        color = Colors.red;
      } else if (status == 'accepted') {
        msg = lang == 'kk' ? 'Клиент өтінімді қабылдады!' : 'Клиент принял ваш отклик!';
        color = Colors.green;
      } else {
        msg = lang == 'kk' ? 'Отклик жіберілген, күтіңіз' : 'Отклик уже отправлен, ожидайте';
        color = Colors.orange;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color),
      );
      return;
    }

    try {
      await _supabase.from('conversations').insert({
        'case_id': caseId,
        'lawyer_id': user.id,
        'status': 'pending',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(lang == 'kk' ? 'Отклик жіберілді!' : 'Отклик отправлен!'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openRegionPicker() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RegionPickerScreen(selectedRegion: _selectedRegion),
      ),
    );
    if (result != null) {
      setState(() => _selectedRegion = result);
      _refreshCases();
    }
  }

  void _openBudgetFilter() async {
    final lang = context.locale.languageCode;
    final fromCtrl = TextEditingController(text: _budgetFrom?.toString() ?? '');
    final toCtrl = TextEditingController(text: _budgetTo?.toString() ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang == 'kk' ? 'Бюджет (₸)' : 'Бюджет клиента (₸)',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    fromCtrl.clear();
                    toCtrl.clear();
                  },
                  child: Text(lang == 'kk' ? 'Тазарту' : 'Сбросить',
                      style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: fromCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: lang == 'kk' ? 'Бастап' : 'От',
                      hintText: '0',
                      border: const OutlineInputBorder(),
                      suffixText: '₸',
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('—', style: TextStyle(fontSize: 20, color: Colors.grey)),
                ),
                Expanded(
                  child: TextField(
                    controller: toCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: lang == 'kk' ? 'Дейін' : 'До',
                      hintText: '∞',
                      border: const OutlineInputBorder(),
                      suffixText: '₸',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  _budgetFrom = fromCtrl.text.isNotEmpty ? int.tryParse(fromCtrl.text) : null;
                  _budgetTo = toCtrl.text.isNotEmpty ? int.tryParse(toCtrl.text) : null;
                });
                Navigator.pop(ctx);
                _refreshCases();
              },
              child: Text(
                lang == 'kk' ? 'Қолдану' : 'Применить',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipRow() {
    final lang = context.locale.languageCode;

    String regionLabel = _selectedRegion == 'Все регионы'
        ? (lang == 'kk' ? 'Аймақ' : 'Регион')
        : _selectedRegion;

    String budgetLabel;
    if (_budgetFrom != null && _budgetTo != null) {
      budgetLabel = '${_budgetFrom!.toString()} – ${_budgetTo!.toString()} ₸';
    } else if (_budgetFrom != null) {
      budgetLabel = 'от ${_budgetFrom!} ₸';
    } else if (_budgetTo != null) {
      budgetLabel = 'до ${_budgetTo!} ₸';
    } else {
      budgetLabel = lang == 'kk' ? 'Бюджет' : 'Бюджет';
    }

    final bool regionActive = _selectedRegion != 'Все регионы';
    final bool budgetActive = _budgetFrom != null || _budgetTo != null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Кнопка региона
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: _openRegionPicker,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: regionActive ? Colors.red : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14,
                        color: regionActive ? Colors.white : Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      regionLabel.length > 22 ? '${regionLabel.substring(0, 20)}…' : regionLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: regionActive ? Colors.white : Colors.black87,
                        fontWeight: regionActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down,
                        size: 14,
                        color: regionActive ? Colors.white : Colors.black54),
                  ],
                ),
              ),
            ),
          ),

          // Кнопка бюджета
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: _openBudgetFilter,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: budgetActive ? Colors.red : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.payments_outlined,
                        size: 14,
                        color: budgetActive ? Colors.white : Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      budgetLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: budgetActive ? Colors.white : Colors.black87,
                        fontWeight: budgetActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down,
                        size: 14,
                        color: budgetActive ? Colors.white : Colors.black54),
                  ],
                ),
              ),
            ),
          ),

          // Сброс всех фильтров
          if (regionActive || budgetActive || _selectedCategory != 'Все' || _selectedServiceType != 'Все')
            InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = 'Все';
                  _selectedServiceType = 'Все';
                  _selectedRegion = 'Все регионы';
                  _budgetFrom = null;
                  _budgetTo = null;
                });
                _refreshCases();
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceTypeRow(String lang) {
    final types = ['Все', 'Консультация', 'Подготовка документов', 'Полное сопровождение'];
    final labels = {
      'Все': lang == 'kk' ? 'Барлығы' : 'Все',
      'Консультация': lang == 'kk' ? 'Консультация' : 'Консультация',
      'Подготовка документов': lang == 'kk' ? 'Құжаттар' : 'Документы',
      'Полное сопровождение': lang == 'kk' ? 'Толық сүйемелдеу' : 'Сопровождение',
    };

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: types.map((t) {
          final isSelected = _selectedServiceType == t;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                labels[t] ?? t,
                style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87),
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedServiceType = t);
                _refreshCases();
              },
              backgroundColor: Colors.grey[200],
              selectedColor: Colors.indigo,
              checkmarkColor: Colors.white,
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryRow(String lang) {
    final categories = ['Все', ..._allowedCategories(widget.lawyerSubtype)];

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          final label = cat == 'Все' ? (lang == 'kk' ? 'Барлығы' : 'Все') : cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                label.length > 20 ? '${label.substring(0, 18)}…' : label,
                style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87),
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedCategory = cat);
                _refreshCases();
              },
              backgroundColor: Colors.grey[200],
              selectedColor: Colors.red,
              checkmarkColor: Colors.white,
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    final subtypeLabel = _subtypeLabel(widget.lawyerSubtype, lang);
    final appBarTitle = '$subtypeLabel — ${lang == 'kk' ? 'Жұмыс кеңістігі' : (lang == 'en' ? 'Dashboard' : 'Рабочее пространство')}';
    final activeCasesLabel = lang == 'kk' ? 'Белсенді өтінімдер' : (lang == 'en' ? 'Active Cases' : 'Активные заявки');
    final emptyCasesText = lang == 'kk' ? 'Өтінімдер табылмады' : (lang == 'en' ? 'No cases found' : 'Заявки не найдены');
    final budgetPrefix = lang == 'kk' ? 'Бюджеті:' : (lang == 'en' ? 'Budget:' : 'Бюджет:');
    final respondBtn = lang == 'kk' ? 'Өтінімге жауап беру' : (lang == 'en' ? 'Apply' : 'Откликнуться');

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded),
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AuthScreen()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            tooltip: lang == 'kk' ? 'Профиль' : 'Профиль',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          buildLanguageButton(context, 'kk', 'KZ', isDarkAppBar: true),
          buildLanguageButton(context, 'ru', 'RU', isDarkAppBar: true),
          buildLanguageButton(context, 'en', 'EN', isDarkAppBar: true),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок + кнопка обновления
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(activeCasesLabel,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.red),
                  onPressed: _refreshCases,
                ),
              ],
            ),

            // Фильтр по категории
            _buildCategoryRow(lang),
            const SizedBox(height: 6),

            // Фильтр по типу услуги
            _buildServiceTypeRow(lang),
            const SizedBox(height: 6),

            // Фильтры регион + бюджет
            _buildFilterChipRow(),
            const SizedBox(height: 10),

            // Список заявок
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async { _refreshCases(); await _casesFuture; },
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _casesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return ListView(children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Center(child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center)),
                      ]);
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final cases = snapshot.data ?? [];
                    if (cases.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                          Center(child: Text(emptyCasesText,
                              style: const TextStyle(color: Colors.grey, fontSize: 16))),
                        ],
                      );
                    }

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: cases.length,
                      itemBuilder: (context, index) {
                        final item = cases[index];
                        final String title = item['title'] ?? '';
                        final String description = item['description'] ?? '';
                        final String category = item['category'] ?? '';
                        final String serviceType = item['service_type'] ?? 'Консультация';
                        final int budget = ((item['budget'] ?? 0) as num).toInt();
                        final String clientLang = (item['language'] ?? 'ru').toUpperCase();
                        final String region = item['region'] ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(category,
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red[700])),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                                      child: Text(clientLang,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Chip(
                                      label: Text(serviceType, style: const TextStyle(fontSize: 12)),
                                      backgroundColor: Colors.red[50],
                                      labelStyle: TextStyle(color: Colors.red[900], fontWeight: FontWeight.w600),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    Chip(
                                      avatar: const Icon(Icons.location_on_rounded, size: 14, color: Colors.red),
                                      label: Text(
                                        region.isNotEmpty ? region : '—',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: Colors.red[50],
                                      labelStyle: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(description,
                                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(budgetPrefix, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        Text('$budget ₸',
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => _sendResponse(item['id'].toString()),
                                      icon: const Icon(Icons.send_outlined, size: 16),
                                      label: Text(respondBtn),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
