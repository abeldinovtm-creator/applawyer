import 'package:firebase_core/firebase_core.dart';

// TODO: Заменить на реальные значения из Firebase Console
// Шаги:
// 1. Зайди на console.firebase.google.com
// 2. Создай проект → добавь Web app
// 3. Скопируй конфиг (firebaseConfig) и вставь сюда
// 4. В Project Settings → Cloud Messaging → Web Push certificates → скопируй VAPID key
const firebaseOptions = FirebaseOptions(
  apiKey: 'TODO_API_KEY',
  appId: 'TODO_APP_ID',
  messagingSenderId: 'TODO_SENDER_ID',
  projectId: 'TODO_PROJECT_ID',
  authDomain: 'TODO_PROJECT_ID.firebaseapp.com',
  storageBucket: 'TODO_PROJECT_ID.appspot.com',
);

// TODO: VAPID key из Firebase Console → Project Settings → Cloud Messaging → Web Push certificates
const fcmVapidKey = 'TODO_VAPID_KEY';

bool get isFirebaseConfigured =>
    !firebaseOptions.apiKey.startsWith('TODO') &&
    !fcmVapidKey.startsWith('TODO');
