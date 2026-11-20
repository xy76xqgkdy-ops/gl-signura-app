import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/validation_utils.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/code_input_field.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/flag_check_list.dart';
import '../../core/widgets/primary_button.dart';

// Person bearbeiten (GET/PUT /me): Name, E-Mail, Mobilnummer, Sprache der
// App und Sprachen für die Übersetzung.
//
// "speichern": Ist die E-Mail und/oder die Mobilnummer neu, schickt das
// Backend zuerst Codes (POST /me/verify/code: E-Mail per Mail, Mobilnummer
// per SMS). Erst mit den Codes wird gespeichert. Gibt das gespeicherte
// Profil per pop zurück.
class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Map<String, dynamic> _user = widget.user;
  late final _firstName = TextEditingController(text: _s('first_name'));
  late final _lastName = TextEditingController(text: _s('last_name'));
  late final _email = TextEditingController(text: _s('email'));
  late final _mobile = TextEditingController(text: _s('mobile'));
  final _emailCode = TextEditingController();
  final _mobileCode = TextEditingController();
  // Gespeicherte Sprache, wenn es sie (noch) gibt, sonst Deutsch.
  late String _language = _appLanguages.any((l) => l.value == _s('language'))
      ? _s('language')
      : 'de_DE';
  // Sprache für die Übersetzung: genau eine (Pflicht, Standard DGS).
  late String _translation =
      (_user['translation_languages'] as List? ?? [])
          .whereType<String>()
          .firstOrNull ??
      'dgs';

  List<({String code, String name, String flag})> _allLanguages = [];

  // Nach "speichern" mit neuer E-Mail/Mobilnummer: Codes eingeben.
  bool _awaitingCodes = false;
  bool _emailCodeSent = false;
  bool _mobileCodeSent = false;

  bool _isLoading = false;
  String? _errorMessage;

  // Sprache der App (Anzeige, E-Mails). Zurzeit nur Deutsch, Englisch kommt später:
  // (value: 'en_US', name: 'English', flag: '🇬🇧'),
  static const List<FlagItem> _appLanguages = [
    (value: 'de_DE', name: 'Deutsch', flag: '🇩🇪'),
  ];

  String _s(String key) => _user[key] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _lastName,
      _email,
      _mobile,
      _emailCode,
      _mobileCode,
    ]) {
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
            (
              code: l['code'] as String,
              name: l['name'] as String,
              flag: l['flag'] as String? ?? '',
            ),
        ];
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    }
  }

  // Wie das Backend: +49… ohne Leerzeichen, damit "0170 1" = "+491701" ist.
  static String _normMobile(String m) {
    var n = m.replaceAll(RegExp(r'[\s\-/().]'), '');
    if (n.startsWith('00')) n = '+${n.substring(2)}';
    if (n.startsWith('0')) n = '+49${n.substring(1)}';
    if (n.isNotEmpty && !n.startsWith('+')) n = '+$n';
    return n;
  }

  bool get _emailChanged =>
      _email.text.trim().toLowerCase() != _s('email').toLowerCase();

  bool get _mobileChanged =>
      _mobile.text.trim().isNotEmpty &&
      _normMobile(_mobile.text) != _normMobile(_s('mobile'));

  bool get _canSave =>
      _firstName.text.trim().isNotEmpty &&
      _lastName.text.trim().isNotEmpty &&
      ValidationUtils.isValidEmail(_email.text) &&
      !_isLoading;

  bool get _canConfirm =>
      (!_emailCodeSent || _emailCode.text.length == 5) &&
      (!_mobileCodeSent || _mobileCode.text.length == 5) &&
      !_isLoading;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // "speichern": bei neuer E-Mail/Mobilnummer erst Codes schicken.
  Future<void> _save() => _run(() async {
    if (_emailChanged || _mobileChanged) {
      final res = await ApiClient.postJson(
        '/me/verify/code',
        body: {
          'email': _emailChanged ? _email.text.trim() : '',
          'mobile': _mobileChanged ? _mobile.text.trim() : '',
        },
      );
      if (!mounted) return;
      setState(() {
        _emailCodeSent = res['email_sent'] == true;
        _mobileCodeSent = res['mobile_sent'] == true;
        _emailCode.clear();
        _mobileCode.clear();
        _awaitingCodes = _emailCodeSent || _mobileCodeSent;
      });
      if (_awaitingCodes) return;
    }
    await _submit();
  });

  Future<void> _confirm() => _run(_submit);

  Future<void> _submit() async {
    final user = await ApiClient.putJson(
      '/me',
      body: {
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'email': _email.text.trim(),
        'mobile': _mobile.text.trim(),
        'language': _language,
        'translation_languages': [_translation],
        if (_emailCodeSent) 'email_code': _emailCode.text.trim(),
        if (_mobileCodeSent) 'mobile_code': _mobileCode.text.trim(),
      },
    );
    if (mounted) Navigator.of(context).pop(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Daten')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: _awaitingCodes ? _codesStep(context) : _form(context),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    void changed(String _) => setState(() {});

    return Column(
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
        AppTextField(
          controller: _email,
          label: 'E-Mail',
          keyboardType: TextInputType.emailAddress,
          onChanged: changed,
        ),
        AppTextField(
          controller: _mobile,
          label: 'Handynummer',
          keyboardType: TextInputType.phone,
          onChanged: changed,
        ),
        // Sprache der App: genau eine; Antippen setzt das Häkchen um.
        FlagCheckList(
          label: 'Sprache der App',
          items: _appLanguages,
          selected: [_language],
          onChanged: (value, _) => setState(() => _language = value),
        ),
        const SizedBox(height: 16),
        // Sprache für die Übersetzung: genau eine; Antippen setzt das Häkchen um.
        if (_allLanguages.isEmpty)
          const Center(child: CircularProgressIndicator())
        else
          FlagCheckList(
            label: 'Welche Sprache brauchen Sie?',
            items: [
              for (final l in _allLanguages)
                (value: l.code, name: l.name, flag: l.flag),
            ],
            selected: [_translation],
            onChanged: (value, _) => setState(() => _translation = value),
          ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'speichern',
          isLoading: _isLoading,
          onPressed: _canSave ? _save : null,
        ),
        ErrorText(message: _errorMessage),
      ],
    );
  }

  Widget _codesStep(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget codeBlock(String text, TextEditingController c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text, style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 12),
        CodeInputField(controller: c, onChanged: (_) => setState(() {})),
        const SizedBox(height: 24),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_emailCodeSent)
          codeBlock(
            'Wir haben einen 5-stelligen Code an ${_email.text.trim()} '
            'geschickt. Bitte geben Sie ihn hier ein.',
            _emailCode,
          ),
        if (_mobileCodeSent)
          codeBlock(
            'Wir haben einen 5-stelligen Code per SMS an '
            '${_mobile.text.trim()} geschickt. Bitte geben Sie ihn hier ein.',
            _mobileCode,
          ),
        Text(
          'Die Codes gelten 10 Minuten.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                      _awaitingCodes = false;
                      _errorMessage = null;
                    }),
              child: const Text('zurück'),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'bestätigen',
              isLoading: _isLoading,
              onPressed: _canConfirm ? _confirm : null,
            ),
          ],
        ),
        ErrorText(message: _errorMessage),
      ],
    );
  }
}
