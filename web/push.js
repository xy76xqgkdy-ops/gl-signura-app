// Web-Push für die Signura-Web-App (aufgerufen aus Dart, lib/core/push/).
// Der Service Worker push-sw.js zeigt die Mitteilungen an. Eigener Bereich
// (scope /push/), damit er Flutters eigenen Service Worker nicht stört.
//
//   signuraPush.enable(key)  nach Antippen: Erlaubnis fragen, abonnieren
//   signuraPush.sync(key)    beim Start: abonnieren, nur wenn schon erlaubt
//   signuraPush.disable()    Abo beenden
// Antwort als JSON-Text: {"status":"ok","endpoint","p256dh","auth"} oder
// {"status":"denied"|"unsupported"|"skip"}.
(function () {
  var supported = 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;

  function bytes(b64) {
    var pad = '='.repeat((4 - (b64.length % 4)) % 4);
    var s = atob((b64 + pad).replace(/-/g, '+').replace(/_/g, '/'));
    return Uint8Array.from(s, function (c) { return c.charCodeAt(0); });
  }

  async function registration() {
    var reg = await navigator.serviceWorker.register('push-sw.js', { scope: './push/' });
    var w = reg.installing || reg.waiting || reg.active;
    if (w && w.state !== 'activated') {
      await new Promise(function (done) {
        w.addEventListener('statechange', function () { if (w.state === 'activated') done(); });
      });
    }
    return reg;
  }

  async function subscribe(key) {
    var reg = await registration();
    var opts = { userVisibleOnly: true, applicationServerKey: bytes(key) };
    var sub;
    try {
      sub = (await reg.pushManager.getSubscription()) || (await reg.pushManager.subscribe(opts));
    } catch (e) {
      // z. B. altes Abo mit anderem Schlüssel: neu abonnieren
      var old = await reg.pushManager.getSubscription();
      if (old) await old.unsubscribe();
      sub = await reg.pushManager.subscribe(opts);
    }
    var j = sub.toJSON();
    return JSON.stringify({ status: 'ok', endpoint: j.endpoint, p256dh: j.keys.p256dh, auth: j.keys.auth });
  }

  window.signuraPush = {
    enable: async function (key) {
      if (!supported) return JSON.stringify({ status: 'unsupported' });
      var p = await Notification.requestPermission();
      if (p !== 'granted') return JSON.stringify({ status: 'denied' });
      return subscribe(key);
    },
    sync: async function (key) {
      if (!supported || Notification.permission !== 'granted') return JSON.stringify({ status: 'skip' });
      return subscribe(key);
    },
    disable: async function () {
      if (!supported) return '';
      var reg = await navigator.serviceWorker.getRegistration('./push/');
      var sub = reg && (await reg.pushManager.getSubscription());
      if (sub) await sub.unsubscribe();
      return '';
    },
  };
})();
