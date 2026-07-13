import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    final title = lang == 'kk'
        ? 'Құпиялылық саясаты'
        : lang == 'en'
            ? 'Privacy Policy'
            : 'Политика конфиденциальности';

    final body = lang == 'kk'
        ? 'Мәтін дайындалуда...'
        : lang == 'en'
            ? 'Text is being prepared...'
            : 'Текст готовится...';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          body,
          style: const TextStyle(fontSize: 14, height: 1.7, color: Colors.black87),
        ),
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    final title = lang == 'kk'
        ? 'Пайдаланушы келісімі'
        : lang == 'en'
            ? 'Terms of Service'
            : 'Пользовательское соглашение';

    final body = lang == 'kk'
        ? 'Мәтін дайындалуда...'
        : lang == 'en'
            ? 'Text is being prepared...'
            : 'Текст готовится...';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          body,
          style: const TextStyle(fontSize: 14, height: 1.7, color: Colors.black87),
        ),
      ),
    );
  }
}

class PersonalDataConsentScreen extends StatelessWidget {
  const PersonalDataConsentScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    final title = lang == 'kk'
        ? 'Дербес деректерді өңдеуге келісім'
        : lang == 'en'
            ? 'Personal Data Processing Consent'
            : 'Согласие на обработку персональных данных';

    final body = lang == 'kk'
        ? 'Мәтін дайындалуда...'
        : lang == 'en'
            ? 'Text is being prepared...'
            : 'Текст готовится...';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          body,
          style: const TextStyle(fontSize: 14, height: 1.7, color: Colors.black87),
        ),
      ),
    );
  }
}
