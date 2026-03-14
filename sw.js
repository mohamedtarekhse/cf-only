self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (_) {
    payload = { body: event.data ? event.data.text() : '' };
  }

  const title = payload.title || 'Asset Management';
  const options = {
    body: payload.body || 'You have a new update.',
    icon: '/favicon.ico',
    badge: '/favicon.ico',
    tag: payload.tag || 'asset-management-notification',
    renotify: true,
    data: {
      url: payload.url || '/',
      transfer_id: payload.transfer_id || null,
      event_type: payload.event_type || null
    }
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = event.notification?.data?.url || '/';

  event.waitUntil((async () => {
    const clients = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of clients) {
      if ('focus' in client) {
        client.postMessage({ type: 'open-url', url: targetUrl });
        return client.focus();
      }
    }
    if (self.clients.openWindow) {
      return self.clients.openWindow(targetUrl);
    }
    return null;
  })());
});
