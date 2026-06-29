import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'region_picker_screen.dart';
import 'auth_screen.dart';
import 'privacy_policy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _iinCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  String _role = 'client';
  String _lawyerSubtype = 'lawyer';
  String _selectedRegion = '';
  bool _loading = true;
  bool _saving = false;
  bool _changingPass = false;
  bool _deletingAccount = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool get _isLawyer => _role == 'lawyer';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _expCtrl.dispose();
    _aboutCtrl.dispose();
    _iinCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await _supabase
          .from('profiles')
          .select('full_name, phone, city, experience_years, about, role, lawyer_subtype, iin')
          .eq('id', user.id)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _role = data['role'] ?? 'client';
          _lawyerSubtype = data['lawyer_subtype'] ?? 'lawyer';
          _nameCtrl.text = data['full_name'] ?? '';
          _phoneCtrl.text = data['phone'] ?? '';
          _selectedRegion = data['city'] ?? '';
          _expCtrl.text = (data['experience_years'] ?? 0).toString();
          _aboutCtrl.text = data['about'] ?? '';
          _iinCtrl.text = data['iin'] ?? '';
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (_isLawyer) 'city': _selectedRegion,
        if (_isLawyer) 'experience_years': int.tryParse(_expCtrl.text) ?? 0,
        if (_isLawyer) 'about': _aboutCtrl.text.trim(),
        if (_isLawyer) 'iin': _iinCtrl.text.trim(),
      });

      if (mounted) {
        _showSnack(
          context.locale.languageCode == 'kk' ? 'Сақталды' : 'Сохранено',
          Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('profiles_iin_unique')
            ? (context.locale.languageCode == 'kk'
                ? 'Бұл ИИН тіркелген' : 'Этот ИИН уже зарегистрирован')
            : 'Ошибка: $e';
        _showSnack(msg, Colors.red);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final lang = context.locale.languageCode;
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (newPass.length < 6) {
      _showSnack(lang == 'kk' ? 'Кемінде 6 таңба' : 'Минимум 6 символов', Colors.orange);
      return;
    }
    if (newPass != confirmPass) {
      _showSnack(lang == 'kk' ? 'Құпия сөздер сәйкес емес' : 'Пароли не совпадают', Colors.orange);
      return;
    }

    setState(() => _changingPass = true);
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPass));
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (mounted) {
        _showSnack(lang == 'kk' ? 'Құпия сөз өзгертілді' : 'Пароль изменён', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('Ошибка: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _changingPass = false);
    }
  }

  Future<void> _deleteAccount() async {
    final lang = context.locale.languageCode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang == 'kk' ? 'Аккаунтты жою?' : 'Удалить аккаунт?'),
        content: Text(lang == 'kk'
            ? 'Барлық деректер жойылады. Бұл әрекетті қайтаруға болмайды.'
            : 'Все данные будут удалены. Это действие необратимо.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang == 'kk' ? 'Бас тарту' : 'Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              lang == 'kk' ? 'Иә, жою' : 'Да, удалить',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await _supabase.rpc('delete_user');
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        _showSnack('Ошибка: $e', Colors.red);
        setState(() => _deletingAccount = false);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String _subtypeName(String lang) {
    switch (_lawyerSubtype) {
      case 'advocate':
        return lang == 'kk' ? 'Адвокат' : 'Адвокат';
      case 'private_court_executor':
        return lang == 'kk' ? 'Жеке сот орындаушысы (ЖСО)' : 'Частный судебный исполнитель (ЧСИ)';
      default:
        return lang == 'kk' ? 'Заңгер' : 'Юрист';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang == 'kk' ? 'Профиль' : 'Профиль'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Аватар
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.red,
                            child: Text(
                              _nameCtrl.text.isNotEmpty
                                  ? _nameCtrl.text.trim()[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 34,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_isLawyer) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _subtypeName(lang),
                                style: TextStyle(
                                  color: Colors.red[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    _sectionHeader(lang == 'kk' ? 'Жеке деректер' : 'Личные данные'),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: lang == 'kk' ? 'Аты-жөні' : 'Имя и фамилия',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v!.trim().isEmpty
                          ? (lang == 'kk' ? 'Өрісті толтырыңыз' : 'Заполните поле')
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]'))],
                      decoration: InputDecoration(
                        labelText: lang == 'kk' ? 'Телефон' : 'Телефон',
                        hintText: '+7 777 000 00 00',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    // Поля только для юристов/адвокатов/ЧСИ
                    if (_isLawyer) ...[
                      const SizedBox(height: 12),

                      // ИИН
                      TextFormField(
                        controller: _iinCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        decoration: InputDecoration(
                          labelText: lang == 'kk' ? 'ЖСН (ИИН)*' : 'ИИН*',
                          hintText: '000000000000',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return lang == 'kk' ? 'ЖСН міндетті' : 'ИИН обязателен';
                          }
                          if (v.trim().length != 12) {
                            return lang == 'kk' ? 'ЖСН 12 цифр болуы керек' : 'ИИН должен содержать 12 цифр';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Регион — пикер
                      InkWell(
                        onTap: _pickRegion,
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: lang == 'kk' ? 'Қала / Аймақ' : 'Город / Регион',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                            border: const OutlineInputBorder(),
                          ),
                          child: Text(
                            _selectedRegion.isNotEmpty
                                ? _selectedRegion
                                : (lang == 'kk' ? 'Таңдаңыз...' : 'Выбрать...'),
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedRegion.isNotEmpty ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _expCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: lang == 'kk' ? 'Тәжірибе (жыл)' : 'Опыт работы (лет)',
                          prefixIcon: const Icon(Icons.work_history_outlined),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _aboutCtrl,
                        maxLines: 5,
                        maxLength: 600,
                        decoration: InputDecoration(
                          labelText: lang == 'kk' ? 'Өзіңіз туралы' : 'О себе',
                          hintText: lang == 'kk'
                              ? 'Мамандану, жетістіктер, жұмыс тәсілі...'
                              : 'Специализация, достижения, подход к работе...',
                          prefixIcon: const Icon(Icons.description_outlined),
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saving ? null : _saveProfile,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              lang == 'kk' ? 'Сақтау' : 'Сохранить',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),

                    const SizedBox(height: 32),
                    _sectionHeader(lang == 'kk' ? 'Құпия сөзді өзгерту' : 'Смена пароля'),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _newPassCtrl,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        labelText: lang == 'kk' ? 'Жаңа құпия сөз' : 'Новый пароль',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPassCtrl,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: lang == 'kk' ? 'Растау' : 'Подтвердить пароль',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _changingPass ? null : _changePassword,
                      child: _changingPass
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                            )
                          : Text(
                              lang == 'kk' ? 'Құпия сөзді өзгерту' : 'Изменить пароль',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),

                    const SizedBox(height: 32),
                    _sectionHeader(lang == 'kk' ? 'Құжаттар' : lang == 'en' ? 'Documents' : 'Документы'),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.shield_outlined, color: Colors.red),
                      title: Text(lang == 'kk' ? 'Құпиялылық саясаты' : lang == 'en' ? 'Privacy Policy' : 'Политика конфиденциальности'),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined, color: Colors.red),
                      title: Text(lang == 'kk' ? 'Пайдаланушы келісімі' : lang == 'en' ? 'Terms of Service' : 'Пользовательское соглашение'),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen())),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader(lang == 'kk' ? 'Қауіпті аймақ' : lang == 'en' ? 'Danger zone' : 'Опасная зона'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        foregroundColor: Colors.grey[700],
                      ),
                      onPressed: _deletingAccount ? null : _deleteAccount,
                      icon: _deletingAccount
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_forever_outlined),
                      label: Text(
                        lang == 'kk' ? 'Аккаунтты жою' : 'Удалить аккаунт',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionHeader(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const Divider(height: 16),
      ],
    );
  }
}
