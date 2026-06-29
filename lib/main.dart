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
    final lang = context.locale.languageCode;

    String screenTitle = lang == 'kk' ? 'Бөлімді таңдаңыз' : (lang == 'en' ? 'Select Category' : 'Выберите раздел');
    String welcomeText = lang == 'kk' ? 'Сізде қандай заңдық мәселе бар?' : (lang == 'en' ? 'What is your legal issue?' : 'Какая у вас юридическая проблема?');

    final List<Map<String, dynamic>> categories = [
      {
        'id': 'Составить или проверить договор',
        'title': lang == 'kk' ? 'Шартты жасау немесе тексеру' : (lang == 'en' ? 'Contract drafting/review' : 'Составить или проверить договор'),
        'icon': Icons.description_rounded,
      },
      {
        'id': 'Споры, суды и долги',
        'title': lang == 'kk' ? 'Даулар, соттар және борыштар' : (lang == 'en' ? 'Disputes & Debts' : 'Споры, суды и долги'),
        'icon': Icons.gavel_rounded,
      },
      {
        'id': 'Трудовые споры',
        'title': lang == 'kk' ? 'Еңбек даулары' : (lang == 'en' ? 'Labor disputes' : 'Трудовые споры'),
        'icon': Icons.work_rounded,
      },
      {
        'id': 'Семья, брак и развод',
        'title': lang == 'kk' ? 'Отбасы, неке және ажырасу' : (lang == 'en' ? 'Family & Divorce' : 'Семья, брак и развод'),
        'icon': Icons.favorite_rounded,
      },
      {
        'id': 'Штрафы, налоги и госорганы',
        'title': lang == 'kk' ? 'Айыппұлдар, салықтар және мемлекеттік органдар' : (lang == 'en' ? 'Fines & Taxes' : 'Штрафы, налоги и госорганы'),
        'icon': Icons.account_balance_rounded,
      },
      {
        'id': 'Бизнес, ИП и ТОО',
        'title': lang == 'kk' ? 'Бизнес, ЖК және ЖШС' : (lang == 'en' ? 'Business & SME' : 'Бизнес, ИП и ТОО'),
        'icon': Icons.business_center_rounded,
      },
      {
        'id': 'Земельные вопросы',
        'title': lang == 'kk' ? 'Жер мәселелері' : (lang == 'en' ? 'Land issues' : 'Земельные вопросы'),
        'icon': Icons.landscape_rounded,
      },
      {
        'id': 'Долги и коллекторы',
        'title': lang == 'kk' ? 'Борыштар және коллекторлар' : (lang == 'en' ? 'Debts & collectors' : 'Долги и коллекторы'),
        'icon': Icons.money_off_rounded,
      },
      {
        'id': 'Уголовные дела',
        'title': lang == 'kk' ? 'Қылмыстық істер' : (lang == 'en' ? 'Criminal cases' : 'Уголовные дела'),
        'icon': Icons.security_rounded,
      },
      {
        'id': 'Исполнение решения суда / ЧСИ',
        'title': lang == 'kk' ? 'Сот шешімін орындау / ЖСО' : (lang == 'en' ? 'Court enforcement / Bailiff' : 'Исполнение решения суда / ЧСИ'),
        'icon': Icons.assignment_turned_in_rounded,
      },
      {
        'id': 'Другой вопрос',
        'title': lang == 'kk' ? 'Басқа сұрақ' : (lang == 'en' ? 'Other issue' : 'Другой вопрос'),
        'icon': Icons.help_outline_rounded,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
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
            tooltip: lang == 'kk' ? 'Менің өтінімдерім' : lang == 'en' ? 'My orders' : 'Мои заявки',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientOrdersScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // ОШИБКА ИСПРАВЛЕНА: crossAxisAlignment вместо cross
          children: [
            const SizedBox(height: 10),
            Text(
              welcomeText,
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
        final l = context.locale.languageCode;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l == 'kk' ? 'Кем дегенде бір төлем өрісін толтырыңыз' : l == 'en' ? 'Fill in at least one payment field' : 'Заполните хотя бы одно поле оплаты'),
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
      
      final _lang = context.locale.languageCode;
      String successText = _lang == 'kk' ? 'Сәтті жіберілді!' : _lang == 'en' ? 'Successfully submitted!' : 'Успешно отправлено!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successText), backgroundColor: Colors.red),
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

    String screenTitle = lang == 'kk' ? 'Өтінішті сипаттау' : lang == 'en' ? 'Describe your case' : 'Описание обращения';
    String fieldRequiredMsg = lang == 'kk' ? 'Өрісті толтырыңыз' : lang == 'en' ? 'Required field' : 'Заполните поле';
    String titleLabel = lang == 'kk' ? 'Мәселенің атауы' : lang == 'en' ? 'Issue title' : 'Название вашей проблемы';
    String descLabel = lang == 'kk' ? 'Жағдайды толық сипаттаңыз' : lang == 'en' ? 'Describe your situation in detail' : 'Опишите ситуацию подробно';
    final budgetSectionLabel = lang == 'kk' ? 'Төлем шарттары (кем дегенде біреуін толтырыңыз)' : lang == 'en' ? 'Payment terms (fill at least one)' : 'Условия оплаты (заполните хотя бы одно)';
    String serviceTypeLabel = lang == 'kk' ? 'Не істеу керек?' : lang == 'en' ? 'What do you need?' : 'Что нужно сделать?';
    String categoryLabel = lang == 'kk' ? 'Таңдалған тақырып' : lang == 'en' ? 'Selected category' : 'Выбранная тема';
    String btnText = lang == 'kk' ? 'Заңгерлерге жіберу' : lang == 'en' ? 'Send to lawyers' : 'Отправить юристам';

    Map<String, String> categoryMap = {
      'Составить или проверить договор': lang == 'kk' ? 'Шартты жасау немесе тексеру' : (lang == 'en' ? 'Contract drafting/review' : 'Составить или проверить договор'),
      'Споры, суды и долги': lang == 'kk' ? 'Даулар, соттар және борыштар' : (lang == 'en' ? 'Disputes & Debts' : 'Споры, суды и долги'),
      'Трудовые споры': lang == 'kk' ? 'Еңбек даулары' : (lang == 'en' ? 'Labor disputes' : 'Трудовые споры'),
      'Семья, брак и развод': lang == 'kk' ? 'Отбасы, неке және ажырасу' : (lang == 'en' ? 'Family & Divorce' : 'Семья, брак и развод'),
      'Штрафы, налоги и госорганы': lang == 'kk' ? 'Айыппұлдар, салықтар және мемлекеттік органдар' : (lang == 'en' ? 'Fines & Taxes' : 'Штрафы, налоги и госорганы'),
      'Бизнес, ИП и ТОО': lang == 'kk' ? 'Бизнес, ЖК және ЖШС' : (lang == 'en' ? 'Business & SME' : 'Бизнес, ИП и ТОО'),
      'Земельные вопросы': lang == 'kk' ? 'Жер мәселелері' : (lang == 'en' ? 'Land issues' : 'Земельные вопросы'),
      'Долги и коллекторы': lang == 'kk' ? 'Борыштар және коллекторлар' : (lang == 'en' ? 'Debts & collectors' : 'Долги и коллекторы'),
      'Уголовные дела': lang == 'kk' ? 'Қылмыстық істер' : (lang == 'en' ? 'Criminal cases' : 'Уголовные дела'),
      'Исполнение решения суда / ЧСИ': lang == 'kk' ? 'Сот шешімін орындау / ЖСО' : (lang == 'en' ? 'Court enforcement / Bailiff' : 'Исполнение решения суда / ЧСИ'),
      'Другой вопрос': lang == 'kk' ? 'Басқа сұрақ' : (lang == 'en' ? 'Other issue' : 'Другой вопрос'),
    };

    Map<String, String> serviceMap = {
      'Консультация': lang == 'kk' ? 'Консультация' : lang == 'en' ? 'Consultation' : 'Консультация',
      'Подготовка документов': lang == 'kk' ? 'Құжаттарды дайындау' : lang == 'en' ? 'Document preparation' : 'Подготовка документов',
      'Полное сопровождение': lang == 'kk' ? 'Толық сүйемелдеу' : lang == 'en' ? 'Full legal support' : 'Полное сопровождение',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
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
                        labelText: categoryLabel,
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
                            labelText: titleLabel,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.only(top: 16, left: 12, right: 50, bottom: 16),
                          ),
                          validator: (value) => value!.isEmpty ? fieldRequiredMsg : null,
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
                            labelText: descLabel,
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                            contentPadding: const EdgeInsets.only(top: 16, left: 12, right: 50, bottom: 16),
                          ),
                          validator: (value) => value!.isEmpty ? fieldRequiredMsg : null,
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
                                child: Text(budgetSectionLabel,
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
                              labelText: lang == 'kk' ? 'Алдын ала төлем' : lang == 'en' ? 'Prepayment' : 'Предоплата',
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
                              labelText: lang == 'kk' ? 'Қызмет көрсетілгеннен кейін' : lang == 'en' ? 'After service' : 'После оказания услуг',
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
                              labelText: lang == 'kk' ? 'Нәтиже бойынша' : lang == 'en' ? 'On result' : 'По результатам',
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
                        labelText: lang == 'kk' ? 'Жұмыс орны (қала/өңір)' : lang == 'en' ? 'City / Region' : 'Место работы (город/регион)',
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
                        labelText: serviceTypeLabel,
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
                      child: Text(btnText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
