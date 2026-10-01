// Firebase Cloud Messaging Service Worker for Flutter Web
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyBQtEjqDJl1GPnmIx7aumSs2XnbUT_-3to",
  authDomain: "taskmate-9ffed.firebaseapp.com",
  projectId: "taskmate-9ffed",
  storageBucket: "taskmate-9ffed.firebasestorage.app",
  messagingSenderId: "11133951879",
  appId: "1:11133951879:web:eb3b245051f058cedf3d22"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);

  const notificationTitle = payload.notification?.title ?? 'TaskMate';
  const notificationOptions = {
    body: payload.notification?.body ?? 'You have a new notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
    actions: [
      { action: 'open', title: 'Open App' },
      { action: 'dismiss', title: 'Dismiss' },
    ],
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification click received.');
  event.notification.close();

  if (event.action === 'open' || !event.action) {
    event.waitUntil(
      clients.openWindow('/')
    );
  }
});