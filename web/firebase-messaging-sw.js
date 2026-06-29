// Firebase Service Worker для фоновых push-уведомлений
// TODO: Заменить значения на реальные из Firebase Console → Project Settings → Your apps → Web app

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'TODO_API_KEY',
  authDomain: 'TODO_PROJECT_ID.firebaseapp.com',
  projectId: 'TODO_PROJECT_ID',
  storageBucket: 'TODO_PROJECT_ID.appspot.com',
  messagingSenderId: 'TODO_SENDER_ID',
  appId: 'TODO_APP_ID',
});

const messaging = firebase.messaging();

// Показывает уведомление когда вкладка закрыта или приложение в фоне
messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification ?? {};
  if (!title) return;

  self.registration.showNotification(title, {
    body: body ?? '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data ?? {},
  });
});

// Клик по уведомлению — открыть/сфокусировать вкладку приложения
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes('applawyer.online') && 'focus' in client) {
          return client.focus();
        }
      }
      return clients.openWindow('https://applawyer.online');
    }),
  );
});
