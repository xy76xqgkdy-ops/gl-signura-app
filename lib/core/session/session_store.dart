import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

// Merkt sich das Login-Token auf dem Gerät (Web: localStorage), damit man
// nach dem Neuladen oder Neustart angemeldet bleibt.
//
//   Login    → save(token)
//   Start    → restore() und GET /users/me
//   Abmelden → logout()
class SessionStore {
  static const _key = 'session_token';

  // Lädt das gespeicherte Token und liefert den Benutzer, oder null,
  // wenn keins da ist oder es nicht mehr gilt.
  static Future<Map<String, dynamic>?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null || saved.isEmpty) return null;

    ApiClient.token = saved;
    try {
      return await ApiClient.getJson('/users/me');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await clear(); // abgelaufen oder abgemeldet
        return null;
      }
      rethrow; // Server nicht erreichbar: Token behalten
    }
  }

  static Future<void> save(String token) async {
    ApiClient.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  static Future<void> clear() async {
    ApiClient.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // Meldet beim Server ab (Token wird dort ungültig) und vergisst es hier.
  static Future<void> logout() async {
    try {
      await ApiClient.postJson('/users/logout');
    } on ApiException {
      // Lokal trotzdem abmelden.
    }
    await clear();
  }
}
