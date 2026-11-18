import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/primary_button.dart';
import 'email_change_screen.dart';

// Person bearbeiten (GET/PUT /me): Name, App-Sprache, Mobilnummer und
// Sprachen für die Übersetzung (mehrere). Die E-Mail ändert man mit Code
// (EmailChangeScreen). Gibt das gespeicherte Profil per pop zurück.
class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Map<String, dynamic> _user = widget.user;
  late final _firstName = TextEditingController(text: _s('first_name'));
  late final _lastName = TextEditingController(text: _s('last_name'));
  late final _mobile = TextEditingController(text: _s('mobile'));
  late final _email = TextEditingController(text: _s('email'));
  late String _language = _s('language').isEmpty ? 'de_DE' : _s('language');
  late final Set<String> _translation = {
    ...(_user['translation_languages'] as List? ?? []).whereType<String>(),
  };

  List<({String code, String name})> _allLanguages = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Sprache der App (Anzeige, E-Mails).
  static const _appLanguages = {'de_DE': 'Deutsch', 'en_US': 'English'};

  String _s(String key) => _user[key] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _mobile, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLanguages() async {
    try {
      final list = await ApiClient.getJsonList('/translation-languages');
      if (!mounted) return;
      setState(() {
        _allLanguages = [
          for (final l in list)
            (code: l['code'] as String, name: l['name'] as String),
        ];
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    }
  }

  bool get _canSave =>
      _firstName.text.trim().isNotEmpty &&
      _lastName.text.trim().isNotEmpty &&
      !_isLoading;

  Future<void> _save() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = await ApiClient.putJson(
        '/me',
        body: {
          'first_name': _firstName.text.trim(),
          'last_name': _lastName.text.trim(),
          'mobile': _mobile.text.trim(),
          'language': _language,
          'translation_languages': _translation.toList(),
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

  Future<void> _changeEmail() async {
    final user = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => EmailChangeScreen(current: _s('email')),
      ),
    );
    if (user != null && mounted) {
      setState(() {
        _user = user;
        _email.text = _s('email');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    void changed(String _) => setState(() {});
    final languageOptions = {
      ..._appLanguages,
      if (!_appLanguages.containsKey(_language)) _language: _language,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Person bearbeiten')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _firstName,
                      label: 'Vorname',
                      onChanged: changed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _lastName,
                      label: 'Nachname',
                      onChanged: changed,
                    ),
                  ),
                ],
              ),
              // E-Mail ist die Anmeldung: nur mit Code an die neue Adresse.
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _email,
                      label: 'E-Mail',
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextButton(
                      onPressed: _changeEmail,
                      child: const Text('ändern'),
                    ),
                  ),
                ],
              ),
              AppTextField(
                controller: _mobile,
                label: 'Mobilnummer',
                keyboardType: TextInputType.phone,
                onChanged: changed,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration: const InputDecoration(
                    labelText: 'Sprache der App',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final e in languageOptions.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _language = v ?? _language),
                ),
              ),
              Text(
                'Sprachen für die Übersetzung',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (_allLanguages.isEmpty)
                const Center(child: CircularProgressIndicator())
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final l in _allLanguages)
                      FilterChip(
                        label: Text(l.name),
                        selected: _translation.contains(l.code),
                        onSelected: (on) => setState(
                          () => on
                              ? _translation.add(l.code)
                              : _translation.remove(l.code),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'speichern',
                isLoading: _isLoading,
                onPressed: _canSave ? _save : null,
              ),
              ErrorText(message: _errorMessage),
            ],
          ),
        ),
      ),
    );
  }
}
