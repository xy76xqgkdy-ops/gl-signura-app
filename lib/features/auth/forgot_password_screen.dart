import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/validation_utils.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/code_step.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/password_step.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/success_screen.dart';
import 'register_screen.dart';

enum _Step { email, password, code, success }

// Passwort vergessen:
//
//   E-Mail   → POST /users/password/code   (schickt Code, falls es das Konto gibt)
//   Passwort → nur lokal
//   Code     → POST /users/password/reset  (setzt das neue Passwort)
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, required this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _Step _step = _Step.email;
  bool _isLoading = false;
  String? _errorMessage;
  // Zur E-Mail gibt es kein Konto (Backend 404) → Hinweis auf Registrierung.
  bool _noAccount = false;

  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _canSubmitEmail =>
      ValidationUtils.isValidEmail(_emailController.text) && !_isLoading;

  bool get _canSubmitPassword =>
      _passwordController.text.length >= 8 &&
      _passwordController.text == _confirmPasswordController.text;

  bool get _canSubmitCode => _codeController.text.length == 5 && !_isLoading;

  // Ruft das Backend auf; bei Erfolg geht es zum nächsten Schritt.
  Future<void> _call(String path, Map<String, dynamic> body, _Step next) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _noAccount = false;
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
        if (next == _Step.password && e.statusCode == 404) {
          _noAccount = true;
        } else {
          _errorMessage = e.message;
        }
        _isLoading = false;
      });
    }
  }

  void _toRegister() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            RegisterScreen(initialEmail: _emailController.text.trim()),
      ),
    );
  }

  // Legt noch nichts fest: verschickt nur den Code per E-Mail.
  Future<void> _submitEmail() => _call('/users/password/code', {
    'email': _emailController.text.trim(),
  }, _Step.password);

  // Erst jetzt wird das Passwort geändert; das Backend prüft den Code.
  Future<void> _submitReset() => _call('/users/password/reset', {
    'email': _emailController.text.trim(),
    'code': _codeController.text.trim(),
    'password': _passwordController.text,
  }, _Step.success);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passwort vergessen')),
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
      case _Step.email:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Geben Sie Ihre E-Mail-Adresse ein. Wir senden Ihnen einen Code. Mit diesem Code können Sie ein neues Passwort festlegen.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: _emailController,
              label: 'E-Mail',
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() => _noAccount = false),
            ),
            // Kein Konto zu dieser E-Mail: Hinweis, "Weiter" führt zur Registrierung.
            if (_noAccount)
              Card(
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Mit dieser E-Mail-Adresse gibt es kein Konto.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4),
                      Text('Klicken Sie auf Weiter.'),
                      Text('Dann können Sie ein neues Konto anlegen.'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Weiter',
              isLoading: _isLoading,
              onPressed: _canSubmitEmail
                  ? (_noAccount ? _toRegister : _submitEmail)
                  : null,
            ),
            ErrorText(message: _errorMessage),
          ],
        );
      case _Step.password:
        return PasswordStep(
          description: 'Wählen Sie ein Passwort. Das Passwort muss mindestens 8 Zeichen haben.',
          passwordController: _passwordController,
          confirmController: _confirmPasswordController,
          passwordLabel: 'Neues Passwort',
          canSubmit: _canSubmitPassword,
          onSubmit: () => setState(() => _step = _Step.code),
          onChanged: (_) => setState(() {}),
        );
      case _Step.code:
        return CodeStep(
          codeController: _codeController,
          buttonLabel: 'Passwort speichern',
          isLoading: _isLoading,
          canSubmit: _canSubmitCode,
          onSubmit: _submitReset,
          onChanged: (_) => setState(() {}),
          errorMessage: _errorMessage,
        );
      case _Step.success:
        return SuccessScreen(
          title: 'Passwort wurde geändert.',
          subtitle:
              'Ihr neues Passwort ist jetzt gültig. Sie können sich anmelden.',
          buttonLabel: 'Zur Anmeldung',
          onPressed: () => Navigator.of(context).pop(),
        );
    }
  }
}
