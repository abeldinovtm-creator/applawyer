import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lawyer_screen.dart';
import 'auth_screen.dart';
import 'client_orders_screen.dart';
import 'profile_screen.dart';
import 'region_translations.dart';
import 'region_picker_screen.dart';
import 'services/push_service.dart';
import 'app_drawer.dart';
import 'widgets.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

const _kBrandRed = MaterialColor(0xFFA6192E, {
  50:  Color(0xFFFAE8EB),
  100: Color(0xFFF2C4CB),
  200: Color(0xFFCF8A97),
  300: Color(0xFFBD607A),
  400: Color(0xFFB03C5B),
  500: Color(0xFFA6192E),
  600: Color(0xFF961727),
  700: Color(0xFF83131F),
  800: Color(0xFF8A1525),
  900: Color(0xFF831320),
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Перехватываем ошибки Flutter-фреймворка — показываем вместо красного экрана
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // Перехватываем необработанные ошибки вне Flutter (async, Platform)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Unhandled platform error: $error\n$stack');
    return true;
  };

  // Кастомный виджет ошибки вместо красного экрана смерти в виджет-дереве
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFA6192E), size: 52),
              const SizedBox(height: 16),
              const Text(
                'Произошла ошибка',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text(
                  details.summary.toString(),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  };

  await EasyLocalization.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Слушаем вход/выход — регистрируем или удаляем FCM токен
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn) {
      PushService.init();
    } else if (data.event == AuthChangeEvent.signedOut) {
      PushService.clearToken();
    }
  });

  // Если сессия уже активна при запуске
  if (Supabase.instance.client.auth.currentSession != null) {
    PushService.init();
  }

  runApp(
    EasyLocalization(
      supportedLocales: [Locale('kk'), Locale('ru'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('kk'),
      startLocale: const Locale('kk'),
      useOnlyLangCode: true,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      localizationsDelegates: [
        ...context.localizationDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      title: 'Applawyer',
      theme: ThemeData(
        primarySwatch: _kBrandRed,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFA6192E),
          foregroundColor: Colors.white,
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
        ),
      ),
      home: session != null ? const AuthRouter() : const AuthScreen(),
    );
  }
}

// === ЧИСТЫЙ АВТОМАТИЧЕСКИЙ РОУТЕР ПО БАЗЕ ДАННЫХ ===
class AuthRouter extends StatefulWidget {
  const AuthRouter({Key? key}) : super(key: key);

  @override
  State<AuthRouter> createState() => _AuthRouterState();
}

class _AuthRouterState extends State<AuthRouter> {
  // Future кешируется в State, чтобы перестройки виджета (например, при смене языка)
  // не перезапускали запрос к БД и не перезаписывали ручной выбор пользователя.
  late final Future<Map<String, dynamic>?> _profileFuture;

  // Флаг: язык из БД уже был применён при первом входе — повторно не применять.
  bool _localeAppliedFromDb = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _profileFuture = user != null
        ? Supabase.instance.client
            .from('profiles')
            .select('role, lawyer_subtype, preferred_language')
            .eq('id', user.id)
            .maybeSingle()
        : Future.value(null);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const AuthScreen();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Ошибка авторизации БД: ${snapshot.error}')),
          );
        }

        final data = snapshot.data;
        final role = (data != null && data['role'] != null)
            ? data['role'].toString()
            : 'client';
        final lawyerSubtype = data?['lawyer_subtype']?.toString() ?? 'lawyer';
        final preferredLang = data?['preferred_language']?.toString();

        // Применяем язык из БД только один раз при первом входе.
        // После этого ручное переключение языка пользователем имеет приоритет.
        if (!_localeAppliedFromDb && preferredLang != null && preferredLang.isNotEmpty) {
          _localeAppliedFromDb = true;
          final targetLocale = Locale(preferredLang);
          if (context.locale != targetLocale) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.setLocale(targetLocale);
            });
          }
        }

        if (role == 'lawyer') {
          return LawyerDashboardScreen(lawyerSubtype: lawyerSubtype);
        } else {
          return const CategorySelectionScreen();
        }
      },
    );
  }
}

class CategorySelectionScreen extends StatefulWidget {
  const CategorySelectionScreen({Key? key}) : super(key: key);

  @override
  State<CategorySelectionScreen> createState() => _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  bool _isSearching = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> allCategories = [
      {'id': 'Составить или проверить договор', 'title': 'category.contract'.tr(), 'icon': Icons.description_rounded},
      {'id': 'Споры, суды и долги', 'title': 'category.disputes'.tr(), 'icon': Icons.gavel_rounded},
      {'id': 'Трудовые споры', 'title': 'category.labor'.tr(), 'icon': Icons.work_rounded},
      {'id': 'Семья, брак и развод', 'title': 'category.family'.tr(), 'icon': Icons.favorite_rounded},
      {'id': 'Штрафы, налоги и госорганы', 'title': 'category.taxes'.tr(), 'icon': Icons.account_balance_rounded},
      {'id': 'Бизнес, ИП и ТОО', 'title': 'category.business'.tr(), 'icon': Icons.business_center_rounded},
      {'id': 'Земельные вопросы', 'title': 'category.land'.tr(), 'icon': Icons.landscape_rounded},
      {'id': 'Долги и коллекторы', 'title': 'category.debts'.tr(), 'icon': Icons.money_off_rounded},
      {'id': 'Уголовные дела', 'title': 'category.criminal'.tr(), 'icon': Icons.security_rounded},
      {'id': 'Исполнение решения суда / ЧСИ', 'title': 'category.enforcement'.tr(), 'icon': Icons.assignment_turned_in_rounded},
      {'id': 'Другой вопрос', 'title': 'category.other'.tr(), 'icon': Icons.help_outline_rounded},
    ];

    final categories = _searchQuery.isEmpty
        ? allCategories
        : allCategories.where((cat) {
            final q = _searchQuery.toLowerCase();
            return cat['title'].toString().toLowerCase().contains(q) ||
                   cat['id'].toString().toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      endDrawer: const AppDrawer(role: 'client'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'search.hint'.tr(),
                  hintStyle: const TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : Text('category.screen_title'.tr()),
        actions: [
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'profile.title'.tr(),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _stopSearch,
            ),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isSearching) ...[
              const SizedBox(height: 10),
              Text(
                'category.welcome'.tr(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 20),
            ],
            if (categories.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'search.no_results'.tr(),
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateCaseScreen(initialCategory: cat['id']),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(cat['icon'], size: 40, color: const Color(0xFFA6192E)),
                              const SizedBox(height: 12),
                              Text(
                                cat['title'],
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CreateCaseScreen extends StatefulWidget {
  final bool isLawyerAsking; 
  final String initialCategory; 

  const CreateCaseScreen({
    Key? key, 
    this.isLawyerAsking = false, 
    this.initialCategory = 'Составить или проверить договор'
  }) : super(key: key);

  @override
  _CreateCaseScreenState createState() => _CreateCaseScreenState();
}

class _CreateCaseScreenState extends State<CreateCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetPrepayCtrl = TextEditingController();
  final _budgetCompletionCtrl = TextEditingController();
  final _budgetResultCtrl = TextEditingController();
  
  late String _selectedCategory;
  String _selectedServiceType = 'Консультация';
  String _selectedRegion = '';

  bool _isLoading = false;
  late stt.SpeechToText _speech;
  bool _isListeningTitle = false;
  bool _isListeningDesc = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _selectedCategory = widget.initialCategory;
  }

  Future<void> _pickRegion() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RegionPickerScreen(selectedRegion: _selectedRegion),
      ),
    );
    if (result != null) setState(() => _selectedRegion = result);
  }

  void _toggleListen({required bool isTitle}) async {
    bool currentListening = isTitle ? _isListeningTitle : _isListeningDesc;

    if (!currentListening) {
      if (_speech.isListening) _speech.stop();
      
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() {
              _isListeningTitle = false;
              _isListeningDesc = false;
            });
          }
        },
        onError: (val) => setState(() {
          _isListeningTitle = false;
          _isListeningDesc = false;
        }),
      );
      
      if (available) {
        setState(() {
          if (isTitle) {
            _isListeningTitle = true;
            _isListeningDesc = false; 
          } else {
            _isListeningDesc = true;
            _isListeningTitle = false; 
          }
        });
        
        _speech.listen(
          localeId: context.locale.languageCode == 'kk' ? 'kk_KZ' : 'ru_RU',
          listenFor: const Duration(minutes: 10),
          pauseFor: const Duration(seconds: 30),
          onResult: (val) => setState(() {
            if (isTitle) {
              _titleController.text = val.recognizedWords;
            } else {
              _descriptionController.text = val.recognizedWords;
            }
          }),
        );
      }
    } else {
      setState(() {
        _isListeningTitle = false;
        _isListeningDesc = false;
      });
      _speech.stop();
    }
  }

  Future<void> _submitCase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("Пользователь не авторизован");

      final prepay = _budgetPrepayCtrl.text.isNotEmpty ? int.tryParse(_budgetPrepayCtrl.text) : null;
      final completion = _budgetCompletionCtrl.text.isNotEmpty ? int.tryParse(_budgetCompletionCtrl.text) : null;
      final result = _budgetResultCtrl.text.isNotEmpty ? int.tryParse(_budgetResultCtrl.text) : null;

      if (prepay == null && completion == null && result == null) {
        showAppSnackBar(context, 'payment.fill_error'.tr(), kind: SnackKind.error);
        setState(() => _isLoading = false);
        return;
      }

      // budget = сумма всех полей для фильтрации по бюджету у юриста
      final totalBudget = (prepay ?? 0) + (completion ?? 0) + (result ?? 0);

      await Supabase.instance.client.from('cases').insert({
        'client_id': user.id,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'category': _selectedCategory,
        'language': context.locale.languageCode,
        'status': 'open',
        'budget': totalBudget,
        if (prepay != null) 'budget_prepayment': prepay,
        if (completion != null) 'budget_on_completion': completion,
        if (result != null) 'budget_on_result': result,
        'service_type': _selectedServiceType,
        'region': _selectedRegion,
      });

      _titleController.clear();
      _descriptionController.clear();
      _budgetPrepayCtrl.clear();
      _budgetCompletionCtrl.clear();
      _budgetResultCtrl.clear();
      
      showAppSnackBar(context, 'case.success'.tr());
      Navigator.pop(context);
    } catch (e) {
      showAppSnackBar(context, 'Error / Ошибка: $e', kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    final Map<String, String> categoryMap = {
      'Составить или проверить договор': 'category.contract'.tr(),
      'Споры, суды и долги': 'category.disputes'.tr(),
      'Трудовые споры': 'category.labor'.tr(),
      'Семья, брак и развод': 'category.family'.tr(),
      'Штрафы, налоги и госорганы': 'category.taxes'.tr(),
      'Бизнес, ИП и ТОО': 'category.business'.tr(),
      'Земельные вопросы': 'category.land'.tr(),
      'Долги и коллекторы': 'category.debts'.tr(),
      'Уголовные дела': 'category.criminal'.tr(),
      'Исполнение решения суда / ЧСИ': 'category.enforcement'.tr(),
      'Другой вопрос': 'category.other'.tr(),
    };

    final Map<String, String> serviceMap = {
      'Консультация': 'service.consultation'.tr(),
      'Подготовка документов': 'service.documents_full'.tr(),
      'Полное сопровождение': 'service.full_support_full'.tr(),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('case.describe_title'.tr()),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'case.category_label'.tr(),
                        prefixIcon: const Icon(Icons.topic_rounded, color: const Color(0xFFA6192E)),
                        border: const OutlineInputBorder(),
                      ),
                      items: categoryMap.keys.map((String key) {
                        return DropdownMenuItem<String>(
                          value: key,
                          child: Text(categoryMap[key]!),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedCategory = value!),
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'case.title_label'.tr(),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.only(top: 16, left: 12, right: 50, bottom: 16),
                          ),
                          validator: (value) => value!.isEmpty ? 'common.required'.tr() : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FloatingActionButton.small(
                            heroTag: "micTitle",
                            onPressed: () => _toggleListen(isTitle: true),
                            backgroundColor: _isListeningTitle ? const Color(0xFFA6192E) : Colors.blue,
                            child: Icon(_isListeningTitle ? Icons.mic : Icons.mic_none),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: 'case.description_label'.tr(),
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                            contentPadding: const EdgeInsets.only(top: 16, left: 12, right: 50, bottom: 16),
                          ),
                          validator: (value) => value!.isEmpty ? 'common.required'.tr() : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, right: 8.0),
                          child: FloatingActionButton.small(
                            heroTag: "micDesc",
                            onPressed: () => _toggleListen(isTitle: false),
                            backgroundColor: _isListeningDesc ? const Color(0xFFA6192E) : Colors.blue, 
                            child: Icon(_isListeningDesc ? Icons.mic : Icons.mic_none),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payments_rounded, color: const Color(0xFFA6192E), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('case.payment_section'.tr(),
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _budgetPrepayCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: 'payment.prepayment'.tr(),
                              hintText: '0',
                              border: const OutlineInputBorder(),
                              suffixText: '₸',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _budgetCompletionCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: 'payment.after_service'.tr(),
                              hintText: '0',
                              border: const OutlineInputBorder(),
                              suffixText: '₸',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _budgetResultCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: 'payment.on_result'.tr(),
                              hintText: '0',
                              border: const OutlineInputBorder(),
                              suffixText: '₸',
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickRegion,
                      borderRadius: BorderRadius.circular(4),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'case.city_label'.tr(),
                          prefixIcon: const Icon(Icons.location_on_rounded, color: const Color(0xFFA6192E)),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                          border: const OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedRegion.isNotEmpty
                              ? translateRegion(_selectedRegion, lang)
                              : 'profile.city_select'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedRegion.isNotEmpty ? Colors.black87 : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedServiceType,
                      decoration: InputDecoration(
                        labelText: 'case.service_type_label'.tr(),
                        prefixIcon: const Icon(Icons.assignment_turned_in_rounded, color: const Color(0xFFA6192E)),
                        border: const OutlineInputBorder(),
                      ),
                      items: serviceMap.keys.map((String key) {
                        return DropdownMenuItem<String>(
                          value: key,
                          child: Text(serviceMap[key]!),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedServiceType = value!),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA6192E),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _submitCase,
                      child: Text('case.send_btn'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
