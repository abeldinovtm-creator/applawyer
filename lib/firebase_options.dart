import 'package:firebase_core/firebase_core.dart';

// TODO: Заменить на реальные значения из Firebase Console
// Шаги:
// 1. Зайди на console.firebase.google.com
// 2. Создай проект → добавь Web app
// 3. Скопируй конфиг (firebaseConfig) и вставь сюда
// 4. В Project Settings → Cloud Messaging → Web Push certificates → скопируй VAPID key
const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyBm5LDp7Coxca6-5f_zBIaAKtk6EwichLg',
  appId: '1:765945070709:web:31d7a663cddd38e7b4e43c',
  messagingSenderId: '765945070709',
  projectId: 'applawyer-1d3ef',
  authDomain: 'applawyer-1d3ef.firebaseapp.com',
  storageBucket: 'applawyer-1d3ef.firebasestorage.app',
);

// TODO: VAPID key из Firebase Console → Project Settings → Cloud Messaging → Web Push certificates
const fcmVapidKey =
    'BljlvIBwyuMkA_ehEcTL-hIZyAixL135JWhw1bd_A-C2yL1tV3gXjpz5HWzHI6kVgDhbM0RDyG4agOB70y4kdhM';

bool get isFirebaseConfigured =>
    !firebaseOptions.apiKey.startsWith('TODO') &&
    !fcmVapidKey.startsWith('TODO');
