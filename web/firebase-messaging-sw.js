// Firebase Service Worker для фоновых push-уведомлений
// TODO: Заменить значения на реальные из Firebase Console → Project Settings → Your apps → Web app

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBm5LDp7Coxca6-5f_zBIaAKtk6EwichLg',
  authDomain: 'applawyer-1d3ef.firebaseapp.com',
  projectId: 'applawyer-1d3ef',
  storageBucket: 'applawyer-1d3ef.firebasestorage.app',
  messagingSenderId: '765945070709',
  appId: '1:765945070709:web:31d7a663cddd38e7b4e43c',
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
