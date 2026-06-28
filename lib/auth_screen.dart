import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lawyer_screen.dart';
import 'main.dart';
import 'widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isSignUp = false;
  bool _isForgotPassword = false;
  String _selectedRole = 'client';
  String _selectedLawyerSubtype = 'lawyer';
  bool _isLoading = false;
  final _iinController = TextEditingController();

  // ===== ВОССТАНОВЛЕНИЕ ПАРОЛЯ =====
  Future<void> _handleForgotPassword() async {
    final lang = context.locale.languageCode;
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang == 'kk' ? 'Email енгізіңіз' : 'Введите email'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang == 'kk'
                ? 'Құпия сөзді қалпына келтіру сілтемесі email-ге жіберілді'
                : 'Ссылка для сброса пароля отправлена на email'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _isForgotPassword = false);
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final lang = context.locale.languageCode;

    try {
      if (_isSignUp) {
        await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'full_name': _nameController.text.trim(),
            'role': _selectedRole,
            'phone': _phoneController.text.trim(),
            if (_selectedRole == 'lawyer') 'lawyer_subtype': _selectedLawyerSubtype,
            if (_selectedRole == 'lawyer') 'iin': _iinController.text.trim(),
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lang == 'kk' ? 'Тіркелу сәтті өтті!' : 'Регистрация успешна!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      await _navigateBasedOnRole();

    } on AuthException catch (e) {
      if (e.statusCode == '422' || e.message.contains('already registered')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang == 'kk'
                ? 'Бұл email тіркелген. Кіру батырмасын басыңыз.'
                : 'Этот email уже зарегистрирован. Пожалуйста, войдите.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isSignUp = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateBasedOnRole() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    String role = _selectedRole;
    String lawyerSubtype = _selectedLawyerSubtype;

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final data = await supabase
            .from('profiles')
            .select('role, lawyer_subtype')
            .eq('id', user.id)
            .maybeSingle();
        if (data != null && data['role'] != null) {
          role = data['role'].toString();
          lawyerSubtype = data['lawyer_subtype']?.toString() ?? 'lawyer';
          break;
        }
      } catch (_) {}
      if (attempt < 2) await Future.delayed(const Duration(milliseconds: 800));
    }

    if (!mounted) return;

    if (role == 'lawyer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LawyerDashboardScreen(lawyerSubtype: lawyerSubtype),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CategorySelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    // ===== ЭКРАН ВОССТАНОВЛЕНИЯ ПАРОЛЯ =====
    if (_isForgotPassword) {
      return Scaffold(
        appBar: AppBar(
          title: Text(lang == 'kk' ? 'Құпия сөзді қалпына келтіру' : 'Восстановление пароля'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _isForgotPassword = false),
          ),
          actions: [
            buildLanguageButton(context, 'kk', 'KZ', isDarkAppBar: true),
            buildLanguageButton(context, 'ru', 'RU', isDarkAppBar: true),
            buildLanguageButton(context, 'en', 'EN', isDarkAppBar: true),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      lang == 'kk'
                          ? 'Email мекенжайыңызды енгізіңіз, біз сізге сілтеме жібереміз'
                          : 'Введите ваш email — мы отправим ссылку для сброса пароля',
                      style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _handleForgotPassword,
                      child: Text(
                        lang == 'kk' ? 'Сілтеме жіберу' : 'Отправить ссылку',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
      );
    }

    // ===== ОСНОВНОЙ ЭКРАН ВХОДА/РЕГИСТРАЦИИ =====
    String title = _isSignUp
        ? (lang == 'kk' ? 'Тіркелу' : (lang == 'en' ? 'Sign Up' : 'Регистрация'))
        : (lang == 'kk' ? 'Кіру' : (lang == 'en' ? 'Sign In' : 'Вход в систему'));

    String btnText = _isSignUp
        ? (lang == 'kk' ? 'Аккаунт жасау' : (lang == 'en' ? 'Create Account' : 'Создать аккаунт'))
        : (lang == 'kk' ? 'Кіру' : (lang == 'en' ? 'Sign In' : 'Войти'));

    String toggleText = _isSignUp
        ? (lang == 'kk' ? 'Аккаунтыңыз бар ма? Кіру' : (lang == 'en' ? 'Have an account? Sign In' : 'Уже есть аккаунт? Войти'))
        : (lang == 'kk' ? 'Аккаунт жоқ па? Тіркелу' : (lang == 'en' ? 'Don\'t have an account? Sign Up' : 'Нет аккаунта? Зарегистрироваться'));

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          buildLanguageButton(context, 'kk', 'KZ', isDarkAppBar: true),
          buildLanguageButton(context, 'ru', 'RU', isDarkAppBar: true),
          buildLanguageButton(context, 'en', 'EN', isDarkAppBar: true),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Applawyer',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red[900]),
                    ),
                    const SizedBox(height: 40),

                    // Имя — только при регистрации
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: lang == 'kk' ? 'Толық атыңыз' : (lang == 'en' ? 'Full Name' : 'Ваше имя и фамилия'),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (v) => v!.isEmpty ? (lang == 'kk' ? 'Өрісті толтырыңыз' : 'Заполните поле') : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => v!.isEmpty ? 'Введите email' : null,
                    ),
                    const SizedBox(height: 16),

                    // Пароль
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: lang == 'kk' ? 'Құпия сөз' : (lang == 'en' ? 'Password' : 'Пароль'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (v) => v!.length < 6
                          ? (lang == 'kk' ? 'Кемінде 6 таңба' : 'Минимум 6 символов')
                          : null,
                    ),
                    const SizedBox(height: 8),

                    // Забыли пароль — только на экране входа
                    if (!_isSignUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() => _isForgotPassword = true),
                          child: Text(
                            lang == 'kk' ? 'Құпия сөзді ұмыттыңыз ба?' : (lang == 'en' ? 'Forgot password?' : 'Забыли пароль?'),
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                      ),

                    if (_isSignUp) ...[
                      const SizedBox(height: 8),

                      // ===== ТЕЛЕФОН — ОБЯЗАТЕЛЬНОЕ ПОЛЕ =====
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]'))],
                        decoration: InputDecoration(
                          labelText: lang == 'kk' ? 'Телефон нөмірі*' : (lang == 'en' ? 'Phone number*' : 'Номер телефона*'),
                          hintText: '+7 777 000 00 00',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return lang == 'kk' ? 'Телефон нөмірін енгізіңіз' : 'Введите номер телефона';
                          }
                          if (v.trim().length < 10) {
                            return lang == 'kk' ? 'Дұрыс нөмір енгізіңіз' : 'Введите корректный номер';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Роль
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          labelText: lang == 'kk' ? 'Сіз кімсіз?' : (lang == 'en' ? 'Who are you?' : 'Кто вы?'),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'client',
                            child: Text(lang == 'kk' ? 'Маған заңгер керек (Клиент)' : (lang == 'en' ? 'I need a lawyer' : 'Мне нужен юрист (Клиент)')),
                          ),
                          DropdownMenuItem(
                            value: 'lawyer',
                            child: Text(lang == 'kk' ? 'Мен заң саласындамын' : (lang == 'en' ? 'I am a legal professional' : 'Я юридический специалист')),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _selectedRole = v!;
                          _selectedLawyerSubtype = 'lawyer';
                        }),
                      ),
                      // Подтип юриста — только если выбрана роль "lawyer"
                      if (_selectedRole == 'lawyer') ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedLawyerSubtype,
                          decoration: InputDecoration(
                            labelText: lang == 'kk' ? 'Мамандық' : (lang == 'en' ? 'Specialization' : 'Специализация'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.gavel_outlined),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'lawyer',
                              child: Text(lang == 'kk' ? 'Заңгер' : (lang == 'en' ? 'Lawyer' : 'Юрист')),
                            ),
                            DropdownMenuItem(
                              value: 'advocate',
                              child: Text(lang == 'kk' ? 'Адвокат' : (lang == 'en' ? 'Advocate' : 'Адвокат')),
                            ),
                            DropdownMenuItem(
                              value: 'private_court_executor',
                              child: Text(lang == 'kk' ? 'Жеке сот орындаушысы (ЖСО)' : (lang == 'en' ? 'Private Bailiff' : 'Частный судебный исполнитель (ЧСИ)')),
                            ),
                          ],
                          onChanged: (v) => setState(() => _selectedLawyerSubtype = v!),
                        ),
                      ],
                      // ИИН — обязательное поле для юристов
                      if (_selectedRole == 'lawyer') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _iinController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(12),
                          ],
                          decoration: InputDecoration(
                            labelText: lang == 'kk' ? 'ЖСН (ИИН)*' : (lang == 'en' ? 'IIN*' : 'ИИН*'),
                            hintText: '000000000000',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                          validator: (v) {
                            if (_selectedRole != 'lawyer') return null;
                            if (v == null || v.trim().isEmpty) {
                              return lang == 'kk' ? 'ЖСН міндетті' : 'ИИН обязателен';
                            }
                            if (v.trim().length != 12) {
                              return lang == 'kk' ? 'ЖСН 12 цифр болуы керек' : 'ИИН должен содержать 12 цифр';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _handleSubmit,
                      child: Text(btnText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(toggleText, style: TextStyle(color: Colors.red[700])),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
