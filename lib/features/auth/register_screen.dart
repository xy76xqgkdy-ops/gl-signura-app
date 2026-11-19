import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/validation_utils.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/code_step.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/password_step.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/success_screen.dart';

enum _Step { details, password, code, success }

// Registrierung als Auftraggeber (Rolle CLIENT). Eine Rollenwahl (Dolmetscher:in,
// Dienstleister/Agentur) gibt es nicht; die Rolle setzt das Backend.
//
//   Angaben  → POST /users/register/code  (prüft E-Mail, schickt Code)
//   Passwort → nur lokal
//   Code     → POST /users/register       (legt den Benutzer an)
class RegisterScreen extends StatefulWidget {
  final String initialEmail; // z. B. aus "Passwort vergessen" übernommen

  const RegisterScreen({super.key, this.initialEmail = ''});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  _Step _step = _Step.details;
  bool _isLoading = false;
  String? _errorMessage;

  final _nameController = TextEditingController();
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _canSubmitDetails =>
      _nameController.text.trim().length >= 2 &&
      ValidationUtils.isValidEmail(_emailController.text) &&
      !_isLoading;

  bool get _canSubmitCode => _codeController.text.length == 5 && !_isLoading;

  bool get _canSubmitPassword =>
      _passwordController.text.length >= 8 &&
      _passwordController.text == _confirmPasswordController.text;

  // Ruft das Backend auf; bei Erfolg geht es zum nächsten Schritt.
  Future<void> _call(String path, Map<String, dynamic> body, _Step next) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ApiClient.postJson(path, body: body);
      if (!mounted) return;
      setState(() {
        _step = next;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  // Legt noch kein Konto an: prüft nur die E-Mail und verschickt den Code.
  Future<void> _submitDetails() => _call('/users/register/code', {
    'name': _nameController.text.trim(),
    'email': _emailController.text.trim(),
  }, _Step.password);

  // Erst jetzt wird das Konto angelegt.
  Future<void> _submitRegister() => _call('/users/register', {
    'name': _nameController.text.trim(),
    'email': _emailController.text.trim(),
    'code': _codeController.text.trim(),
    'password': _passwordController.text,
  }, _Step.success);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neues Konto')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: _buildStep(context),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case _Step.details:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Bitte geben Sie Ihren Namen und Ihre E-Mail-Adresse ein.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _nameController,
              label: 'Vor- und Nachname',
              onChanged: (_) => setState(() {}),
            ),
            AppTextField(
              controller: _emailController,
              label: 'E-Mail',
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Weiter',
              isLoading: _isLoading,
              onPressed: _canSubmitDetails ? _submitDetails : null,
            ),
            ErrorText(message: _errorMessage),
          ],
        );
      case _Step.password:
        return PasswordStep(
          description: 'Wählen Sie ein Passwort.\nDas Passwort muss mindestens 8 Zeichen haben.',
          passwordController: _passwordController,
          confirmController: _confirmPasswordController,
          canSubmit: _canSubmitPassword,
          onSubmit: () => setState(() => _step = _Step.code),
          onChanged: (_) => setState(() {}),
        );
      case _Step.code:
        return CodeStep(
          codeController: _codeController,
          buttonLabel: 'Konto anlegen',
          isLoading: _isLoading,
          canSubmit: _canSubmitCode,
          onSubmit: _submitRegister,
          onChanged: (_) => setState(() {}),
          errorMessage: _errorMessage,
        );
      case _Step.success:
        return SuccessScreen(
          title: 'Ihr Konto ist fertig.',
          subtitle: 'Sie können sich jetzt anmelden.',
          buttonLabel: 'Zur Anmeldung',
          onPressed: () => Navigator.of(context).pop(),
        );
    }
  }
}
