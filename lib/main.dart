import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets.dart';
import 'lawyer_screen.dart';
import 'auth_screen.dart';
import 'client_orders_screen.dart';
import 'profile_screen.dart';
import 'region_translations.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(
    EasyLocalization(
      supportedLocales: [Locale('kk'), Locale('ru'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: Locale('kk'), 
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
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
      ),
      home: session != null ? const AuthRouter() : const AuthScreen(),
    );
  }
}

// === ЧИСТЫЙ АВТОМАТИЧЕСКИЙ РОУТЕР ПО БАЗЕ ДАННЫХ ===
class AuthRouter extends StatelessWidget {
  const AuthRouter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const AuthScreen();

    return FutureBuilder<Map<String, dynamic>?>(
      future: Supabase.instance.client
          .from('profiles')
          .select('role, lawyer_subtype')
          .eq('id', user.id)
          .maybeSingle(),
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

        if (role == 'lawyer') {
          return LawyerDashboardScreen(lawyerSubtype: lawyerSubtype);
        } else {
          return const CategorySelectionScreen();
        }
      },
    );
  }
}

class CategorySelectionScreen extends StatelessWidget {
  const CategorySelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> categories = [
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

    return Scaffold(
      appBar: AppBar(
        title: Text('category.screen_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded),
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthScreen()));
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_turned_in_rounded),
            tooltip: 'client.orders_title'.tr(),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientOrdersScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'profile.title'.tr(),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // ОШИБКА ИСПРАВЛЕНА: crossAxisAlignment вместо cross
          children: [
            const SizedBox(height: 10),
            Text(
              'category.welcome'.tr(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 20),
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
                            Icon(cat['icon'], size: 40, color: Colors.red),
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
  String _selectedRegion = 'Алматы'; // регион клиента

  static const List<String> kRegions = [
    'Алматы', 'Астана', 'Шымкент', 'Актобе', 'Атырау',
    'Караганда', 'Тараз', 'Павлодар', 'Усть-Каменогорск',
    'Семей', 'Костанай', 'Петропавловск', 'Кызылорда',
    'Актау', 'Туркестан', 'Кокшетау', 'Талдыкорган',
    'Онлайн (любой регион)',
  ];

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('payment.fill_error'.tr()),
          backgroundColor: Colors.red,
        ));
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('case.success'.tr()), backgroundColor: Colors.red),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error / Ошибка: $e'), backgroundColor: Colors.red),
      );
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
        actions: [
          buildLanguageButton(context, 'kk', 'KZ', isDarkAppBar: true),
          buildLanguageButton(context, 'ru', 'RU', isDarkAppBar: true),
          buildLanguageButton(context, 'en', 'EN', isDarkAppBar: true),
        ],
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
                        prefixIcon: const Icon(Icons.topic_rounded, color: Colors.red),
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
                            backgroundColor: _isListeningTitle ? Colors.red : Colors.blue,
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
                            backgroundColor: _isListeningDesc ? Colors.red : Colors.blue, 
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
                              const Icon(Icons.payments_rounded, color: Colors.red, size: 18),
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
                    DropdownButtonFormField<String>(
                      value: _selectedRegion,
                      decoration: InputDecoration(
                        labelText: 'case.city_label'.tr(),
                        prefixIcon: const Icon(Icons.location_on_rounded, color: Colors.red),
                        border: const OutlineInputBorder(),
                      ),
                      items: _CreateCaseScreenState.kRegions.map((r) {
                        return DropdownMenuItem(value: r, child: Text(translateRegion(r, lang)));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedRegion = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedServiceType,
                      decoration: InputDecoration(
                        labelText: 'case.service_type_label'.tr(),
                        prefixIcon: const Icon(Icons.assignment_turned_in_rounded, color: Colors.red),
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
                        backgroundColor: Colors.red,
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
