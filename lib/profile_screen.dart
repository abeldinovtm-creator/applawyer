import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'region_picker_screen.dart';
import 'main.dart';
import 'widgets.dart';
import 'services/route_persistence.dart';
import 'services/lawyer_stats_service.dart';

String _trCategory(String cat) {
  const map = {
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
  final _emailCtrl = TextEditingController();
  final _backupEmailCtrl = TextEditingController();

  String _role = 'client';
  String _lawyerSubtype = 'lawyer';
  String _loadedLawyerSubtype = 'lawyer';
  String _selectedRegion = '';
  String? _avatarUrl;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _changingEmail = false;
  bool _editing = false;
  int _completedCases = 0;
  int _activeCases = 0;
  List<LawyerCategoryStat> _categoryStats = [];

  bool get _isLawyer => _role == 'lawyer';

  @override
  void initState() {
    super.initState();
    setLastRoute('/profile');
    _loadProfile();
  }

  @override
  void dispose() {
    setLastRoute(null);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _expCtrl.dispose();
    _aboutCtrl.dispose();
    _iinCtrl.dispose();
    _emailCtrl.dispose();
    _backupEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await _supabase
          .from('profiles')
          .select('full_name, phone, city, experience_years, about, role, lawyer_subtype, iin, avatar_url, backup_email')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _emailCtrl.text = user.email ?? '';
          if (data != null) {
            _role = data['role'] ?? 'client';
            _lawyerSubtype = data['lawyer_subtype'] ?? 'lawyer';
            _loadedLawyerSubtype = _lawyerSubtype;
            _nameCtrl.text = data['full_name'] ?? '';
            _phoneCtrl.text = data['phone'] ?? '';
            _selectedRegion = data['city'] ?? '';
            _expCtrl.text = (data['experience_years'] ?? 0).toString();
            _aboutCtrl.text = data['about'] ?? '';
            _iinCtrl.text = data['iin'] ?? '';
            _avatarUrl = data['avatar_url'];
            _backupEmailCtrl.text = data['backup_email'] ?? '';
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
    if (_isLawyer) {
      _loadCaseStats();
      _loadCategoryStats();
    }
  }

  // Сколько завершённых дел у юриста в каждой категории — помогает
  // самому юристу видеть свою фактическую специализацию по истории дел.
  Future<void> _loadCategoryStats() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final stats = await LawyerStatsService.fetchCategoryStats(user.id);
      if (mounted) setState(() => _categoryStats = stats);
    } catch (_) {}
  }

  // Счётчик завершённых/незавершённых дел юриста.
  Future<void> _loadCaseStats() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final counts = await LawyerStatsService.fetchCaseCounts(user.id);
      if (mounted) {
        setState(() {
          _completedCases = counts.completed;
          _activeCases = counts.active;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final path = '${user.id}.jpg';
      await _supabase.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      final bustedUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      await _supabase.from('profiles').update({'avatar_url': bustedUrl}).eq('id', user.id);
      if (mounted) setState(() => _avatarUrl = bustedUrl);
    } catch (e) {
      if (mounted) _showSnack('Ошибка: $e', const Color(0xFFA6192E));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
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
        'backup_email': _backupEmailCtrl.text.trim(),
        'city': _selectedRegion,
        if (_isLawyer) 'lawyer_subtype': _lawyerSubtype,
        if (_isLawyer) 'experience_years': int.tryParse(_expCtrl.text) ?? 0,
        if (_isLawyer) 'about': _aboutCtrl.text.trim(),
        if (_isLawyer) 'iin': _iinCtrl.text.trim(),
      });

      // Смена специализации меняет доступные категории заявок в дашборде юриста —
      // он кеширует lawyerSubtype в конструкторе, поэтому нужен полный перезаход
      // через AuthRouter, чтобы дашборд перечитал профиль из БД.
      final subtypeChanged = _isLawyer && _lawyerSubtype != _loadedLawyerSubtype;
      if (mounted && subtypeChanged) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthRouter()),
          (_) => false,
        );
        return;
      }

      if (mounted) {
        setState(() => _editing = false);
        _showSnack('profile.saved'.tr(), Colors.green);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('profiles_iin_unique')
            ? 'profile.iin_duplicate'.tr()
            : 'Ошибка: $e';
        _showSnack(msg, const Color(0xFFA6192E));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Отмена редактирования — перечитываем профиль из БД, чтобы отбросить
  // непосохранённые изменения в полях, и возвращаемся в режим просмотра.
  Future<void> _cancelEditing() async {
    setState(() => _loading = true);
    await _loadProfile();
    if (mounted) setState(() => _editing = false);
  }

  // Смена основного email через Supabase Auth — не мгновенная: письмо со
  // ссылкой подтверждения уходит на новый адрес, сам email в auth.users
  // меняется только после перехода по ссылке.
  Future<void> _changeEmail() async {
    final newEmail = _emailCtrl.text.trim();
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      _showSnack('profile.email_invalid'.tr(), Colors.orange);
      return;
    }
    final currentEmail = _supabase.auth.currentUser?.email ?? '';
    if (newEmail == currentEmail) return;

    setState(() => _changingEmail = true);
    try {
      await _supabase.auth.updateUser(UserAttributes(email: newEmail));
      if (mounted) {
        _showSnack('profile.email_change_sent'.tr(), Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('Ошибка: $e', const Color(0xFFA6192E));
    } finally {
      if (mounted) setState(() => _changingEmail = false);
    }
  }

  void _showSnack(String msg, Color color) {
    final kind = color == Colors.green
        ? SnackKind.success
        : color == Colors.orange
            ? SnackKind.warning
            : SnackKind.error;
    showAppSnackBar(context, msg, kind: kind);
  }

  String _subtypeName() {
    switch (_lawyerSubtype) {
      case 'advocate': return 'specialist.advocate'.tr();
      case 'private_court_executor': return 'specialist.pce_full'.tr();
      case 'notary': return 'specialist.notary'.tr();
      default: return 'specialist.lawyer'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Читаем context.locale, чтобы экран подписался на смену языка —
    // иначе .tr() ниже не обновится сразу при смене языка в этом же экране.
    context.locale;

    return Scaffold(
      appBar: AppBar(
        title: Text('profile.title'.tr()),
        actions: [
          if (!_loading)
            IconButton(
              icon: Icon(_editing ? Icons.close : Icons.edit_outlined),
              tooltip: _editing ? 'common.cancel'.tr() : 'profile.edit'.tr(),
              onPressed: _editing ? _cancelEditing : () => setState(() => _editing = true),
            ),
        ],
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
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 42,
                                backgroundColor: const Color(0xFFA6192E),
                                backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                    ? NetworkImage(_avatarUrl!)
                                    : null,
                                child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                                    ? Text(
                                        _nameCtrl.text.isNotEmpty
                                            ? _nameCtrl.text.trim()[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 34,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              if (_editing)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFA6192E),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: _uploadingAvatar
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_isLawyer) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAE8EB),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFCF8A97)),
                              ),
                              child: Text(
                                _subtypeName(),
                                style: TextStyle(
                                  color: const Color(0xFF8A1525),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_isLawyer) ...[
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'profile.completed_cases'.tr(),
                              value: '$_completedCases',
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'profile.active_cases'.tr(),
                              value: '$_activeCases',
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      if (_categoryStats.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'profile_view.category_stats_title'.tr(),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categoryStats.map((s) {
                            return Chip(
                              label: Text('${_trCategory(s.category)} · ${s.completedCount}',
                                  style: const TextStyle(fontSize: 12)),
                              backgroundColor: const Color(0xFFFAE8EB),
                              labelStyle: const TextStyle(color: Color(0xFFA6192E)),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],

                    _sectionHeader('profile.personal_data'.tr()),
                    const SizedBox(height: 12),

                    if (!_editing) ...[
                      _infoRow(Icons.person_outline, 'profile.full_name'.tr(), _nameCtrl.text),
                      _infoRow(Icons.phone_outlined, 'profile.phone'.tr(), _phoneCtrl.text),
                      _infoRow(Icons.email_outlined, 'profile.email'.tr(), _emailCtrl.text),
                      _infoRow(Icons.alternate_email_rounded, 'profile.backup_email'.tr(), _backupEmailCtrl.text),
                      _infoRow(Icons.location_on_outlined, 'profile.city'.tr(), _selectedRegion),
                      if (_isLawyer) ...[
                        _infoRow(Icons.gavel_outlined, 'auth.specialization'.tr(), _subtypeName()),
                        _infoRow(Icons.badge_outlined, 'profile.iin'.tr(), _iinCtrl.text),
                        _infoRow(Icons.work_history_outlined, 'profile.experience'.tr(), _expCtrl.text),
                        _infoRow(Icons.description_outlined, 'profile.about'.tr(), _aboutCtrl.text),
                      ],
                    ] else ...[
                      TextFormField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'profile.full_name'.tr(),
                          prefixIcon: const Icon(Icons.person_outline),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v!.trim().isEmpty ? 'profile.required'.tr() : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]'))],
                        decoration: InputDecoration(
                          labelText: 'profile.phone'.tr(),
                          hintText: '+7 777 000 00 00',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'profile.email'.tr(),
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _changingEmail ? null : _changeEmail,
                          child: _changingEmail
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text('profile.change_email_btn'.tr(),
                                  style: const TextStyle(color: Color(0xFFA6192E), fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 4),

                      TextFormField(
                        controller: _backupEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'profile.backup_email'.tr(),
                          hintText: 'profile.backup_email_hint'.tr(),
                          prefixIcon: const Icon(Icons.alternate_email_rounded),
                          border: const OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Регион — пикер (доступен и клиенту, и юристу)
                      InkWell(
                        onTap: _pickRegion,
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'profile.city'.tr(),
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                            border: const OutlineInputBorder(),
                          ),
                          child: Text(
                            _selectedRegion.isNotEmpty
                                ? _selectedRegion
                                : 'profile.city_select'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedRegion.isNotEmpty ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                      ),

                      // Поля только для юристов/адвокатов/ЧСИ/нотариусов
                      if (_isLawyer) ...[
                        const SizedBox(height: 12),

                        // Специализация — можно сменить после регистрации
                        DropdownButtonFormField<String>(
                          initialValue: _lawyerSubtype,
                          decoration: InputDecoration(
                            labelText: 'auth.specialization'.tr(),
                            prefixIcon: const Icon(Icons.gavel_outlined),
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(value: 'lawyer', child: Text('specialist.lawyer'.tr())),
                            DropdownMenuItem(value: 'advocate', child: Text('specialist.advocate'.tr())),
                            DropdownMenuItem(value: 'private_court_executor', child: Text('specialist.pce_full'.tr())),
                            DropdownMenuItem(value: 'notary', child: Text('specialist.notary'.tr())),
                          ],
                          onChanged: (v) => setState(() => _lawyerSubtype = v!),
                        ),
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
                            labelText: 'profile.iin'.tr(),
                            hintText: '000000000000',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'profile.iin_required'.tr();
                            if (v.trim().length != 12) return 'profile.iin_length'.tr();
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
                              labelText: 'profile.city'.tr(),
                              prefixIcon: const Icon(Icons.location_on_outlined),
                              suffixIcon: const Icon(Icons.arrow_drop_down),
                              border: const OutlineInputBorder(),
                            ),
                            child: Text(
                              _selectedRegion.isNotEmpty
                                  ? _selectedRegion
                                  : 'profile.city_select'.tr(),
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
                            labelText: 'profile.experience'.tr(),
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
                            labelText: 'profile.about'.tr(),
                            hintText: 'profile.about_hint'.tr(),
                            prefixIcon: const Icon(Icons.description_outlined),
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA6192E),
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
                            : Text('profile.save'.tr(),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFFA6192E)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
