// Service Worker nur für Push-Mitteilungen (siehe push.js).
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (e) { e.waitUntil(self.clients.claim()); });

self.addEventListener('push', function (e) {
  var d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) {}
  e.waitUntil(self.registration.showNotification(d.title || 'Signura', {
    body: d.body || '',
    icon: '/icons/Icon-192.png',
    tag: d.request_id || undefined,
    data: d,
  }));
});

// Antippen: offene Signura-Seite nach vorn holen, sonst öffnen.
self.addEventListener('notificationclick', function (e) {
  e.notification.close();
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
    for (var i = 0; i < list.length; i++) {
      if ('focus' in list[i]) return list[i].focus();
    }
    return self.clients.openWindow('/');
  }));
});
