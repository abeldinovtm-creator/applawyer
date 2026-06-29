import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../firebase_options.dart';

class PushService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (!isFirebaseConfigured) return;
    if (_initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: firebaseOptions);
      }

      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _saveToken();
        messaging.onTokenRefresh.listen(_saveTokenValue);
      }

      // Foreground сообщения (пока вкладка открыта) — сервис-воркер уже их обрабатывает
      FirebaseMessaging.onMessage.listen((_) {});

      _initialized = true;
    } catch (_) {
      // Не блокируем приложение если Firebase не настроен
    }
  }

  static Future<void> _saveToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken(vapidKey: fcmVapidKey);
      if (token != null) await _saveTokenValue(token);
    } catch (_) {}
  }

  static Future<void> _saveTokenValue(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', user.id);
    } catch (_) {}
  }

  static Future<void> clearToken() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': null})
          .eq('id', user.id);
      if (isFirebaseConfigured) {
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (_) {}
  }
}
