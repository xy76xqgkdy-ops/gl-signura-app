import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/validation_utils.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/code_step.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/primary_button.dart';

// E-Mail ändern: neue Adresse → Code an diese Adresse → bestätigen.
//   POST /me/email/code {"email"}, dann POST /me/email {"email","code"}
// Gibt das Profil mit neuer E-Mail per pop zurück.
class EmailChangeScreen extends StatefulWidget {
  final String current;

  const EmailChangeScreen({super.key, required this.current});

  @override
  State<EmailChangeScreen> createState() => _EmailChangeScreenState();
}

class _EmailChangeScreenState extends State<EmailChangeScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _canSend =>
      ValidationUtils.isValidEmail(_email.text) &&
      _email.text.trim().toLowerCase() != widget.current.toLowerCase() &&
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

  Future<void> _sendCode() => _run(() async {
    await ApiClient.postJson(
      '/me/email/code',
      body: {'email': _email.text.trim()},
    );
    if (mounted) setState(() => _codeSent = true);
  });

  Future<void> _confirm() => _run(() async {
    final user = await ApiClient.postJson(
      '/me/email',
      body: {'email': _email.text.trim(), 'code': _code.text.trim()},
    );
    if (mounted) Navigator.of(context).pop(user);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-Mail ändern')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: _codeSent
              ? CodeStep(
                  codeController: _code,
                  buttonLabel: 'E-Mail ändern',
                  isLoading: _isLoading,
                  canSubmit: _code.text.length == 5 && !_isLoading,
                  onSubmit: _confirm,
                  onChanged: (_) => setState(() {}),
                  errorMessage: _errorMessage,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Bisher: ${widget.current}\n\n'
                      'Geben Sie die neue E-Mail-Adresse ein. Wir schicken '
                      'einen Code an diese Adresse.',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _email,
                      label: 'Neue E-Mail',
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Code senden',
                      isLoading: _isLoading,
                      onPressed: _canSend ? _sendCode : null,
                    ),
                    ErrorText(message: _errorMessage),
                  ],
                ),
        ),
      ),
    );
  }
}
