import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/push/push.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/primary_button.dart';

// Benachrichtigungen: Push-Mitteilungen ein/aus (PUT /me notify_push).
// Eingeschaltet meldet sich dieser Browser beim Backend an (Web-Push,
// POST /me/push-tokens). Gibt das gespeicherte Profil per pop zurück.
class NotificationsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const NotificationsScreen({super.key, required this.user});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late bool _push = widget.user['notify_push'] as bool? ?? true;
  bool _isLoading = false;
  bool _denied = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Push.loadKey(); // vorab, siehe Push.loadKey
  }

  Future<void> _save() async {
    // Zuerst (ohne vorheriges Warten) nach der Erlaubnis fragen: Safari
    // erlaubt das nur direkt nach dem Antippen.
    final permission = _push ? Push.enable() : null;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _denied = false;
    });
    try {
      if (permission != null) {
        final res = await permission;
        if (res != 'ok') {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            if (res == 'denied') {
              _denied = true;
            } else {
              _errorMessage =
                  'Dieser Browser kann keine Push-Mitteilungen. Auf dem iPhone: '
                  'Seite zuerst mit „Teilen“ → „Zum Home-Bildschirm“ hinzufügen '
                  'und von dort öffnen.';
            }
          });
          return;
        }
      } else {
        await Push.disable();
      }
      final user = await ApiClient.putJson('/me', body: {'notify_push': _push});
      if (!mounted) return;
      Navigator.of(context).pop(user);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Push-Mitteilungen konnten nicht eingeschaltet werden.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Benachrichtigungen')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text(
              'Wir schicken Ihnen eine Mitteilung, wenn sich bei Ihren Anfragen '
              'etwas ändert. Zum Beispiel bei einer neuen Zusage.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_none),
              title: const Text('Push-Mitteilungen'),
              value: _push,
              onChanged: (v) => setState(() => _push = v),
            ),
            if (_denied)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  'Mitteilungen sind für diese Seite ausgeschaltet. Bitte erlauben '
                  'Sie sie in den Einstellungen des Browsers.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'speichern',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _save,
            ),
            ErrorText(message: _errorMessage),
          ],
        ),
      ),
    );
  }
}
