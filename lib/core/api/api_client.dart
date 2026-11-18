import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Fehler mit einer Meldung, die man dem Benutzer zeigen kann.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  // Adresse der booin-API:
  //   Web-App auf gl.signura.de → "/api" (gleiche Adresse, kein CORS nötig)
  //   sonst (lokal, Handy)      → https://gl.signura.de/api
  // nginx auf signura-booin leitet /api/ über das private Hetzner-Netz an
  // signura-database (10.0.1.20:8080) weiter.
  // Überschreibbar mit --dart-define=API_BASE=https://…
  static const _override = String.fromEnvironment('API_BASE');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb && Uri.base.host == 'gl.signura.de') return '/api';
    return 'https://gl.signura.de/api';
  }

  // Token der Sitzung (siehe SessionStore). Ist es gesetzt, geht es bei
  // jeder Anfrage als "Authorization: Bearer …" mit.
  static String? token;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    final data = await _send(
      () => http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    return data is Map<String, dynamic> ? data : const {};
  }

  static Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    final data = await _send(
      () => http.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    return data is Map<String, dynamic> ? data : const {};
  }

  static Future<void> deleteJson(String path) =>
      _send(() => http.delete(Uri.parse('$baseUrl$path'), headers: _headers));

  static Future<Map<String, dynamic>> getJson(String path) async {
    final data = await _send(
      () => http.get(Uri.parse('$baseUrl$path'), headers: _headers),
    );
    return data is Map<String, dynamic> ? data : const {};
  }

  // Für Endpunkte, die eine Liste liefern (z. B. GET /me/requests).
  static Future<List<Map<String, dynamic>>> getJsonList(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path')
        .replace(queryParameters: query?.isEmpty ?? true ? null : query);
    final data = await _send(() => http.get(uri, headers: _headers));
    return data is List ? data.whereType<Map<String, dynamic>>().toList() : [];
  }

  static Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response res;
    try {
      res = await request().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ApiException('Server antwortet nicht.');
    } catch (_) {
      throw const ApiException('Server nicht erreichbar.');
    }

    dynamic data;
    try {
      if (res.bodyBytes.isNotEmpty) {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      }
    } catch (_) {
      // Kein JSON (z. B. 502/504 von nginx) → allgemeine Meldung unten.
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    final error = data is Map<String, dynamic> ? data['error'] : null;
    throw ApiException(
      error is String ? error : 'Fehler (HTTP ${res.statusCode})',
      statusCode: res.statusCode,
    );
  }
}
