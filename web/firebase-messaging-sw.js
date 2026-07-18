importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// 🛡️ Web Background Alerts for the Zikrint customer app.
// Lets web/PWA users receive push notifications even when the tab is closed.
firebase.initializeApp({
  apiKey: 'AIzaSyDhrCs4sKAYt7jr9OQMB1jt22CuOOsGi4E',
  authDomain: 'psfc-43b5a.firebaseapp.com',
  projectId: 'psfc-43b5a',
  storageBucket: 'psfc-43b5a.firebasestorage.app',
  messagingSenderId: '52763236709',
  appId: '1:52763236709:web:ccc19f87fcfdc4dc37e98c',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background message: ', payload);

  // Messages WITH a `notification` block are displayed automatically by the
  // Firebase SDK — showing them here too would create duplicates.
  if (payload.notification) return;

  // Data-only messages: build the notification ourselves.
  const data = payload.data || {};
  const title = data.title || 'Zikrint Order Update';
  const options = {
    body: data.body || 'Check your orders for the latest status.',
    icon: '/icons/Icon-192.png',
    badge: '/favicon.png',
    data: data,
  };
  return self.registration.showNotification(title, options);
});

// 🎯 Focus/open the app when the user taps the notification
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ('focus' in client) return client.focus();
      }
      if (clients.openWindow) return clients.openWindow('/');
    })
  );
});
