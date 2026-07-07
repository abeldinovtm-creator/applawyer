import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import 'region_picker_screen.dart';
import 'region_translations.dart';
import 'chat_screen.dart';
import 'app_drawer.dart';
import 'widgets.dart';
import 'services/unread_counts_service.dart';
import 'test_mode_banner.dart';

String _trServiceType(String type) {
  const map = {
    'Консультация': 'service.consultation',
    'Подготовка документов': 'service.documents_full',
    'Полное сопровождение': 'service.full_support_full',
  };
  final key = map[type];
  return key != null ? key.tr() : type;
}

String _trCategory(String cat) {
  const map = {
    'Все': 'category.all',
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

class LawyerDashboardScreen extends StatefulWidget {
  final String lawyerSubtype;
  final int initialTabIndex;

  const LawyerDashboardScreen({
    Key? key,
    required this.lawyerSubtype,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  _LawyerDashboardScreenState createState() => _LawyerDashboardScreenState();
}

class _LawyerDashboardScreenState extends State<LawyerDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _casesFuture;
  late Future<List<Map<String, dynamic>>> _inProgressFuture;
  String _selectedCategory = 'Все';
  String _selectedServiceType = 'Все';
  String _selectedRegion = 'Все регионы';
  int? _budgetFrom;
  int? _budgetTo;
  bool _filtersExpanded = false;
  bool _isSearching = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Категории, доступные по подтипу специалиста
  static List<String> _allowedCategories(String subtype) {
    if (subtype == 'private_court_executor') {
      // ЧСИ исполняет, а не консультирует — "Исполнение решения суда"
      // (сопровождение процесса) остаётся юристам/адвокатам.
      return ['ЧСИ'];
    } else if (subtype == 'notary') {
      return ['Нотариальные услуги'];
    } else if (subtype == 'lawyer') {
      return [
        'Составить или проверить договор', 'Споры, суды и долги',
        'Трудовые споры', 'Семья, брак и развод', 'Штрафы, налоги и госорганы',
        'Бизнес, ИП и ТОО', 'Земельные вопросы', 'Долги и коллекторы',
        'Исполнение решения суда', 'Другой вопрос',
      ];
    } else {
      // advocate — все категории, кроме ЧСИ и нотариальных услуг —
      // это отдельные лицензируемые специальности, не входят в компетенцию адвоката
      return [
        'Составить или проверить договор', 'Споры, суды и долги',
        'Трудовые споры', 'Семья, брак и развод', 'Штрафы, налоги и госорганы',
        'Бизнес, ИП и ТОО', 'Земельные вопросы', 'Долги и коллекторы',
        'Уголовные дела', 'Исполнение решения суда', 'Другой вопрос',
      ];
    }
  }

  static String _subtypeLabel(String subtype) {
    switch (subtype) {
      case 'advocate': return 'specialist.advocate'.tr();
      case 'private_court_executor': return 'specialist.pce'.tr();
      case 'notary': return 'specialist.notary'.tr();
      default: return 'specialist.lawyer'.tr();
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _refreshCases();
    _refreshInProgress();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _budgetLine(String label, int amount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text('$amount ₸', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
      ],
    );
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

  void _refreshInProgress() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _inProgressFuture = Future.value([]));
      return;
    }
    setState(() {
      _inProgressFuture = _supabase
          .from('conversations')
          .select('id, case_id, created_at, price_amount')
          .eq('lawyer_id', user.id)
          .eq('status', 'accepted')
          .then((convRaw) async {
            final convs = List<Map<String, dynamic>>.from(convRaw as List);
            if (convs.isEmpty) return <Map<String, dynamic>>[];

            final caseIds = convs.map((c) => c['case_id'].toString()).toList();
            final casesRaw = await _supabase
                .from('cases')
                .select()
                .inFilter('id', caseIds);

            final casesMap = <String, Map<String, dynamic>>{};
            for (final c in List<Map<String, dynamic>>.from(casesRaw as List)) {
              casesMap[c['id'].toString()] = c;
            }

            return convs.map((conv) {
              final caseData = casesMap[conv['case_id'].toString()] ?? <String, dynamic>{};
              return <String, dynamic>{...conv, 'case': caseData};
            }).toList();
          });
    });
  }

  // Дело закрывается только после подтверждения ОБЕИХ сторон — эта функция
  // ставит только сторону юриста. Остальное (status='completed', списание
  // комиссии) делает серверный триггер, когда клиент подтвердит тоже
  // (см. supabase/migrations/20260703_escrow_commission_dual_confirmation.sql).
  Future<void> _confirmCompletion(String caseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('lawyer.confirm_completion_title'.tr()),
        content: Text('lawyer.confirm_completion_body'.tr()),
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

    try {
      await _supabase
          .from('cases')
          .update({'lawyer_confirmed_completion_at': DateTime.now().toIso8601String()})
          .eq('id', caseId);
      _refreshInProgress();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Ошибка: $e', kind: SnackKind.error);
      }
    }
  }

  Future<void> _sendResponse(String caseId, Map<String, dynamic> caseItem) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

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
        msg = 'lawyer.response_rejected'.tr();
        color = const Color(0xFFA6192E);
      } else if (status == 'accepted') {
        msg = 'lawyer.response_accepted'.tr();
        color = Colors.green;
      } else {
        msg = 'lawyer.response_pending'.tr();
        color = Colors.orange;
      }
      if (!mounted) return;
      showAppSnackBar(context, msg, kind: color == Colors.orange ? SnackKind.warning : SnackKind.error);
      return;
    }

    // Бюджет клиента из заявки
    final clientBudget = ((caseItem['budget'] ?? 0) as num).toInt();
    final hasClientPrice = clientBudget > 0;

    if (!mounted) return;
    final amountCtrl = TextEditingController();
    bool useClientPrice = false;
    String? validationError;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('lawyer.price_offer_title'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Чекбокс "Принять цену клиента"
              if (hasClientPrice) ...[
                InkWell(
                  onTap: () {
                    setModalState(() {
                      useClientPrice = !useClientPrice;
                      if (useClientPrice) {
                        amountCtrl.text = clientBudget.toString();
                        validationError = null;
                      } else {
                        amountCtrl.clear();
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: useClientPrice ? Colors.green[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: useClientPrice ? Colors.green : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          useClientPrice ? Icons.check_box : Icons.check_box_outline_blank,
                          color: useClientPrice ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'lawyer.accept_client_price'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            color: useClientPrice ? Colors.green[800] : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
              ] else ...[
                Text('lawyer.no_client_price'.tr(),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 8),
              ],

              TextField(
                controller: amountCtrl,
                enabled: !useClientPrice,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'payment.amount'.tr(),
                  hintText: 'payment.amount_hint'.tr(),
                  border: const OutlineInputBorder(),
                  suffixText: '₸',
                  filled: useClientPrice,
                  fillColor: Colors.green[50],
                ),
              ),
              if (validationError != null) ...[
                const SizedBox(height: 8),
                Text(validationError!, style: const TextStyle(color: const Color(0xFFA6192E), fontSize: 13)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA6192E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (!useClientPrice) {
                    final amount = int.tryParse(amountCtrl.text);
                    if (amount == null || amount <= 0) {
                      setModalState(() => validationError = 'common.required'.tr());
                      return;
                    }
                  }
                  Navigator.pop(ctx, true);
                },
                child: Text('lawyer.send_response_btn'.tr(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final amount = int.tryParse(amountCtrl.text);

    try {
      await _supabase.from('conversations').insert({
        'case_id': caseId,
        'lawyer_id': user.id,
        'status': 'pending',
        if (amount != null) 'price_amount': amount,
      });
      if (!mounted) return;
      showAppSnackBar(context, 'lawyer.response_sent'.tr());
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Ошибка: $e', kind: SnackKind.error);
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
                Text('filter.budget_client'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () { fromCtrl.clear(); toCtrl.clear(); },
                  child: Text('filter.reset'.tr(), style: const TextStyle(color: const Color(0xFFA6192E))),
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
                      labelText: 'filter.from_label'.tr(),
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
                      labelText: 'filter.to_label'.tr(),
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
                backgroundColor: const Color(0xFFA6192E),
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
              child: Text('filter.apply'.tr(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipRow() {
    final lang = context.locale.languageCode;

    String regionLabel = _selectedRegion == 'Все регионы'
        ? 'filter.region'.tr()
        : translateRegion(_selectedRegion, lang);

    String budgetLabel;
    if (_budgetFrom != null && _budgetTo != null) {
      budgetLabel = '${_budgetFrom!} – ${_budgetTo!} ₸';
    } else if (_budgetFrom != null) {
      budgetLabel = '${'filter.from'.tr()} ${_budgetFrom!} ₸';
    } else if (_budgetTo != null) {
      budgetLabel = '${'filter.to'.tr()} ${_budgetTo!} ₸';
    } else {
      budgetLabel = 'filter.budget'.tr();
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
                  color: regionActive ? const Color(0xFFA6192E) : Colors.grey[200],
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
                  color: budgetActive ? const Color(0xFFA6192E) : Colors.grey[200],
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
                  border: Border.all(color: const Color(0xFFA6192E)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close, size: 14, color: const Color(0xFFA6192E)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceTypeRow(String lang) {
    final types = ['Все', 'Консультация', 'Подготовка документов', 'Полное сопровождение'];
    final labels = {
      'Все': 'service.all'.tr(),
      'Консультация': 'service.consultation'.tr(),
      'Подготовка документов': 'service.documents'.tr(),
      'Полное сопровождение': 'service.full_support'.tr(),
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
          final label = _trCategory(cat);
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
              selectedColor: const Color(0xFFA6192E),
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

  Widget _buildCasesTab(String lang) {
    final budgetPrefix = 'lawyer.budget'.tr();
    final respondBtn = 'lawyer.respond_btn'.tr();
    final emptyCasesText = 'lawyer.no_cases'.tr();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('lawyer.active_cases'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: const Color(0xFFA6192E)),
                    onPressed: _refreshCases,
                  ),
                  IconButton(
                    icon: AnimatedRotation(
                      turns: _filtersExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, color: const Color(0xFFA6192E)),
                    ),
                    tooltip: _filtersExpanded ? 'Скрыть фильтры' : 'Показать фильтры',
                    onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
                  ),
                ],
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _filtersExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryRow(lang),
                const SizedBox(height: 6),
                _buildServiceTypeRow(lang),
                const SizedBox(height: 6),
                _buildFilterChipRow(),
                const SizedBox(height: 6),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 4),
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
                  var cases = snapshot.data ?? [];
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    cases = cases.where((c) {
                      return (c['title'] ?? '').toString().toLowerCase().contains(q) ||
                             (c['description'] ?? '').toString().toLowerCase().contains(q) ||
                             (c['category'] ?? '').toString().toLowerCase().contains(q) ||
                             (c['service_type'] ?? '').toString().toLowerCase().contains(q);
                    }).toList();
                  }
                  if (cases.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Center(child: Text(
                          _searchQuery.isNotEmpty ? 'search.no_results'.tr() : emptyCasesText,
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        )),
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
                      // Защита от самооткликов на UI-уровне (дублирует RESTRICTIVE
                      // RLS-политику lawyer_cannot_respond_own_case на conversations) —
                      // актуально при переключении роли (active_role) на одном аккаунте.
                      final bool isOwnCase = item['client_id'] == _supabase.auth.currentUser?.id;

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
                                    child: Text(_trCategory(category),
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFA6192E))),
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
                                    label: Text(_trServiceType(serviceType), style: const TextStyle(fontSize: 12)),
                                    backgroundColor: const Color(0xFFFAE8EB),
                                    labelStyle: TextStyle(color: const Color(0xFF831320), fontWeight: FontWeight.w600),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  Chip(
                                    avatar: const Icon(Icons.location_on_rounded, size: 14, color: const Color(0xFFA6192E)),
                                    label: Text(
                                      region.isNotEmpty ? translateRegion(region, lang) : '—',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: const Color(0xFFFAE8EB),
                                    labelStyle: TextStyle(color: const Color(0xFFA6192E), fontWeight: FontWeight.w500),
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
                                  isOwnCase
                                      ? Text(
                                          'lawyer.own_case'.tr(),
                                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                        )
                                      : ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFA6192E),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _sendResponse(item['id'].toString(), item),
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
    );
  }

  Widget _buildInProgressTab(String lang) {
    return RefreshIndicator(
      onRefresh: () async { _refreshInProgress(); await _inProgressFuture; },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _inProgressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.work_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('lawyer.in_progress_empty'.tr(),
                          style: const TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final conv = items[index];
              final caseData = Map<String, dynamic>.from(conv['case'] as Map? ?? {});
              final convId = conv['id'].toString();
              final caseId = caseData['id'].toString();
              final String title = caseData['title'] ?? 'case.legal_help'.tr();
              final String category = caseData['category'] ?? '';
              final String region = caseData['region'] ?? '';
              final bool isCaseCompleted = caseData['status'] == 'completed';
              final bool lawyerConfirmed = caseData['lawyer_confirmed_completion_at'] != null;
              final int? agreedAmount = conv['price_amount'] as int?;
              final hasAgreedPrice = agreedAmount != null;
              final isUnread = UnreadCountsService.instance.unreadConversationIds.value.contains(convId);

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 3,
                color: isUnread ? const Color(0xFFFFF3F3) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isUnread
                      ? const BorderSide(color: Color(0xFFA6192E), width: 1.5)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок + статус
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              category.isNotEmpty ? _trCategory(category) : title,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green[700]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Flexible(
                            child: Text(title,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          ValueListenableBuilder<Set<String>>(
                            valueListenable: UnreadCountsService.instance.unreadConversationIds,
                            builder: (_, ids, __) => UnreadDot(show: ids.contains(convId)),
                          ),
                        ],
                      ),
                      if (region.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 14, color: const Color(0xFFA6192E)),
                            const SizedBox(width: 4),
                            Text(translateRegion(region, lang),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ],
                      if (hasAgreedPrice) ...[
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
                                  Text('lawyer.agreed_price'.tr(),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[800])),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _budgetLine('payment.amount'.tr(), agreedAmount),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA6192E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: convId,
                                caseTitle: title,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
                          label: Text('chat.open_chat'.tr()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isCaseCompleted)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'lawyer.case_completed_badge'.tr(),
                            style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        )
                      else if (lawyerConfirmed)
                        Text(
                          'lawyer.waiting_client_confirmation'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green[800],
                              side: BorderSide(color: Colors.green.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _confirmCompletion(caseId),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: Text('lawyer.confirm_completion'.tr()),
                          ),
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

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final subtypeLabel = _subtypeLabel(widget.lawyerSubtype);
    final appBarTitle = '$subtypeLabel — ${'lawyer.workspace'.tr()}';

    return Scaffold(
      endDrawer: const AppDrawer(role: 'lawyer'),
      onEndDrawerChanged: (isOpen) {
        if (isOpen) UnreadCountsService.instance.refresh();
      },
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'search.hint_cases'.tr(),
                  hintStyle: const TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : Text(appBarTitle),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'lawyer.cases_tab'.tr()),
            Tab(text: 'lawyer.in_progress_tab'.tr()),
          ],
        ),
        actions: [
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => setState(() => _isSearching = true),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() {
                _isSearching = false;
                _searchQuery = '';
                _searchCtrl.clear();
              }),
            ),
          const MenuIconWithBadge(color: Colors.white),
        ],
      ),
      body: Column(
        children: [
          const TestModeBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCasesTab(lang),
                _buildInProgressTab(lang),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
