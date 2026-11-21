import '../api/api_client.dart';
import 'web_push.dart';

// Push-Mitteilungen für die Web-App: Das Backend schickt sie bei Änderungen
// an Anfragen (neue Zusage, zurückgezogen …), ohne Gesundheitsdaten.
//
//   Einschalten (Benachrichtigungen) → Push.enable(): fragt nach der Erlaubnis
//   App-Start (angemeldet)          → Push.sync(): ohne Frage, nur wenn erlaubt
//   Ausschalten                     → Push.disable()
//   Abmelden                        → nichts: das Backend löscht den Empfänger mit der Sitzung
class Push {
  static String? _key;

  // Öffentlicher Schlüssel des Servers. Vorab laden: Safari erlaubt die
  // Frage nach der Erlaubnis nur direkt nach dem Antippen, ohne Warten.
  static Future<String?> loadKey() async {
    if (_key != null) return _key;
    try {
      _key =
          (await ApiClient.getJson('/push/web-key'))['public_key'] as String?;
    } on ApiException {
      _key = null; // Web-Push auf dem Server nicht eingerichtet
    }
    return _key;
  }

  // 'ok', 'denied' oder 'unsupported'.
  static Future<String> enable() async {
    final key = _key ?? await loadKey();
    if (key == null) return 'unsupported';
    final res = await webPushEnable(key);
    if (res['status'] == 'ok') await _save(res);
    return res['status'] ?? 'unsupported';
  }

  static Future<void> sync(bool notifyPush) async {
    if (!notifyPush) return;
    try {
      final key = await loadKey();
      if (key == null) return;
      final res = await webPushSync(key);
      if (res['status'] == 'ok') await _save(res);
    } catch (_) {
      // Kein Netz o. ä.: beim nächsten Start wieder.
    }
  }

  static Future<void> disable() async {
    try {
      await webPushDisable();
    } catch (_) {}
    await ApiClient.deleteJson('/me/push-tokens');
  }

  static Future<void> _save(Map<String, String> res) => ApiClient.postJson(
    '/me/push-tokens',
    body: {
      'kind': 'web',
      'endpoint': res['endpoint'],
      'p256dh': res['p256dh'],
      'auth': res['auth'],
    },
  );
}
