import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'region_picker_screen.dart';
import 'auth_screen.dart';
import 'privacy_policy_screen.dart';
import 'widgets.dart';

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
  String _preferredLang = 'kk';
  String? _avatarUrl;
  bool _loading = true;
  bool _saving = false;
  bool _changingPass = false;
  bool _deletingAccount = false;
  bool _uploadingAvatar = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  int _completedCases = 0;
  int _activeCases = 0;

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
          .select('full_name, phone, city, experience_years, about, role, lawyer_subtype, iin, preferred_language, avatar_url')
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
          _preferredLang = data['preferred_language'] ?? 'kk';
          _avatarUrl = data['avatar_url'];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
    if (_isLawyer) _loadCaseStats();
  }

  // Счётчик завершённых/незавершённых дел юриста: считаем по заявкам,
  // где отклик юриста был принят клиентом (conversations.status == accepted).
  Future<void> _loadCaseStats() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final convRaw = await _supabase
          .from('conversations')
          .select('case_id')
          .eq('lawyer_id', user.id)
          .eq('status', 'accepted');
      final caseIds = List<Map<String, dynamic>>.from(convRaw as List)
          .map((c) => c['case_id'].toString())
          .toList();

      if (caseIds.isEmpty) {
        if (mounted) setState(() { _completedCases = 0; _activeCases = 0; });
        return;
      }

      final casesRaw = await _supabase.from('cases').select('status').inFilter('id', caseIds);
      final cases = List<Map<String, dynamic>>.from(casesRaw as List);
      final completed = cases.where((c) => c['status'] == 'completed').length;
      if (mounted) {
        setState(() {
          _completedCases = completed;
          _activeCases = cases.length - completed;
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
        'preferred_language': _preferredLang,
        if (_isLawyer) 'city': _selectedRegion,
        if (_isLawyer) 'experience_years': int.tryParse(_expCtrl.text) ?? 0,
        if (_isLawyer) 'about': _aboutCtrl.text.trim(),
        if (_isLawyer) 'iin': _iinCtrl.text.trim(),
      });

      if (mounted) {
        context.setLocale(Locale(_preferredLang));
      }

      if (mounted) {
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

  Future<void> _changePassword() async {
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (newPass.length < 6) {
      _showSnack('profile.password_min'.tr(), Colors.orange);
      return;
    }
    if (newPass != confirmPass) {
      _showSnack('profile.password_mismatch'.tr(), Colors.orange);
      return;
    }

    setState(() => _changingPass = true);
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPass));
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (mounted) {
        _showSnack('profile.password_changed'.tr(), Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('Ошибка: $e', const Color(0xFFA6192E));
    } finally {
      if (mounted) setState(() => _changingPass = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile.delete_confirm_title'.tr()),
        content: Text('profile.delete_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.yes_delete'.tr(), style: const TextStyle(color: const Color(0xFFA6192E))),
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
        _showSnack('Ошибка: $e', const Color(0xFFA6192E));
        setState(() => _deletingAccount = false);
      }
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
                          Expanded(child: _statCard('profile.completed_cases'.tr(), _completedCases, Colors.green)),
                          const SizedBox(width: 10),
                          Expanded(child: _statCard('profile.active_cases'.tr(), _activeCases, Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    _sectionHeader('profile.personal_data'.tr()),
                    const SizedBox(height: 12),

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

                    const SizedBox(height: 20),
                    _sectionHeader('profile.preferred_language'.tr()),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final entry in [('kk', 'Қазақша'), ('ru', 'Русский'), ('en', 'English')])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => setState(() => _preferredLang = entry.$1),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _preferredLang == entry.$1 ? const Color(0xFFA6192E) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _preferredLang == entry.$1 ? const Color(0xFFA6192E) : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    entry.$2,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _preferredLang == entry.$1 ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

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

                    const SizedBox(height: 32),
                    _sectionHeader('profile.change_password'.tr()),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _newPassCtrl,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        labelText: 'profile.new_password'.tr(),
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
                        labelText: 'profile.confirm_password'.tr(),
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
                        side: const BorderSide(color: const Color(0xFFA6192E)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _changingPass ? null : _changePassword,
                      child: _changingPass
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFFA6192E)),
                            )
                          : Text('profile.change_password_btn'.tr(),
                              style: const TextStyle(
                                color: const Color(0xFFA6192E),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),

                    const SizedBox(height: 32),
                    _sectionHeader('profile.documents'.tr()),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.shield_outlined, color: const Color(0xFFA6192E)),
                      title: Text('profile.privacy_policy'.tr()),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined, color: const Color(0xFFA6192E)),
                      title: Text('profile.terms_of_service'.tr()),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen())),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader('profile.danger_zone'.tr()),
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
                        'profile.delete_account'.tr(),
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

  Widget _statCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
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
