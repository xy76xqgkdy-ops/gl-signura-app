import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/primary_button.dart';

// Benachrichtigungen: auf welchem Weg man informiert werden möchte
// (PUT /me: notify_email, notify_sms, notify_messenger). Gespeichert wird
// vorerst nur die Wahl; der Versand kommt später.
// Gibt das gespeicherte Profil per pop zurück.
class NotificationsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const NotificationsScreen({super.key, required this.user});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late bool _email = widget.user['notify_email'] as bool? ?? true;
  late bool _sms = widget.user['notify_sms'] as bool? ?? false;
  late bool _messenger = widget.user['notify_messenger'] as bool? ?? false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _hasMobile =>
      (widget.user['mobile'] as String? ?? '').trim().isNotEmpty;

  Future<void> _save() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = await ApiClient.putJson(
        '/me',
        body: {
          'notify_email': _email,
          'notify_sms': _sms,
          'notify_messenger': _messenger,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(user);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
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
              'Wie möchten Sie über Ihre Anfragen informiert werden?',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              secondary: const Icon(Icons.email_outlined),
              title: const Text('per E-Mail'),
              value: _email,
              onChanged: (v) => setState(() => _email = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.sms_outlined),
              title: const Text('per SMS'),
              value: _sms,
              onChanged: (v) => setState(() => _sms = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.chat_outlined),
              title: const Text('per Messenger'),
              value: _messenger,
              onChanged: (v) => setState(() => _messenger = v),
            ),
            if ((_sms || _messenger) && !_hasMobile)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  'Für SMS und Messenger brauchen wir Ihre Mobilnummer. '
                  'Tragen Sie sie unter „Person bearbeiten“ ein.',
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
