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
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('auth.email_required'.tr()),
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
            content: Text('auth.reset_sent'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _isForgotPassword = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: const Color(0xFFA6192E)),
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
              content: Text('auth.registered_success'.tr()),
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
            content: Text('auth.email_registered'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isSignUp = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFA6192E)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: const Color(0xFFA6192E)),
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
    // ===== ЭКРАН ВОССТАНОВЛЕНИЯ ПАРОЛЯ =====
    if (_isForgotPassword) {
      return Scaffold(
        appBar: AppBar(
          title: Text('auth.forgot_title'.tr()),
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
                      'auth.forgot_hint'.tr(),
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
                        backgroundColor: const Color(0xFFA6192E),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _handleForgotPassword,
                      child: Text(
                        'auth.send_link'.tr(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
      );
    }

    // ===== ОСНОВНОЙ ЭКРАН ВХОДА/РЕГИСТРАЦИИ =====
    final title = _isSignUp ? 'auth.sign_up'.tr() : 'auth.sign_in'.tr();
    final btnText = _isSignUp ? 'auth.sign_up_btn'.tr() : 'auth.sign_in_btn'.tr();
    final toggleText = _isSignUp ? 'auth.have_account'.tr() : 'auth.no_account'.tr();

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
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF831320)),
                    ),
                    const SizedBox(height: 40),

                    // Имя — только при регистрации
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'auth.full_name'.tr(),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (v) => v!.isEmpty ? 'auth.required'.tr() : null,
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
                      validator: (v) => v!.isEmpty ? 'auth.email_required'.tr() : null,
                    ),
                    const SizedBox(height: 16),

                    // Пароль
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'auth.password'.tr(),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (v) => v!.length < 6 ? 'auth.password_min'.tr() : null,
                    ),
                    const SizedBox(height: 8),

                    // Забыли пароль — только на экране входа
                    if (!_isSignUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() => _isForgotPassword = true),
                          child: Text(
                            'auth.forgot_password'.tr(),
                            style: TextStyle(color: const Color(0xFFA6192E)),
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
                          labelText: 'auth.phone'.tr(),
                          hintText: '+7 777 000 00 00',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'auth.phone_required'.tr();
                          }
                          if (v.trim().length < 10) {
                            return 'auth.phone_invalid'.tr();
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Роль
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          labelText: 'auth.who_are_you'.tr(),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'client',
                            child: Text('auth.i_need_lawyer'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'lawyer',
                            child: Text('auth.i_am_professional'.tr()),
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
                            labelText: 'auth.specialization'.tr(),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.gavel_outlined),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'lawyer',
                              child: Text('specialist.lawyer'.tr()),
                            ),
                            DropdownMenuItem(
                              value: 'advocate',
                              child: Text('specialist.advocate'.tr()),
                            ),
                            DropdownMenuItem(
                              value: 'private_court_executor',
                              child: Text('specialist.pce_full'.tr()),
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
                            labelText: 'auth.iin'.tr(),
                            hintText: '000000000000',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                          validator: (v) {
                            if (_selectedRole != 'lawyer') return null;
                            if (v == null || v.trim().isEmpty) {
                              return 'auth.iin_required'.tr();
                            }
                            if (v.trim().length != 12) {
                              return 'auth.iin_length'.tr();
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA6192E),
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
                      child: Text(toggleText, style: TextStyle(color: const Color(0xFFA6192E))),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
