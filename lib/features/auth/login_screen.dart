import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_client.dart';
import '../../core/session/session_store.dart';
import '../../core/utils/validation_utils.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/primary_button.dart';
import '../home/home_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

// Anmeldung über POST /api/users/login (booin-Backend).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isLoading = false;
  String? _errorMessage;

  bool get _canSubmit =>
      ValidationUtils.isValidEmail(_emailController.text) &&
      _passwordController.text.isNotEmpty &&
      !_isLoading;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = await ApiClient.postJson(
        '/users/login',
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      );
      // Angemeldet bleiben: Token auf dem Gerät speichern.
      await SessionStore.save(user['token'] as String);
      // Zeigt dem Passwortmanager, dass die Eingabe fertig ist.
      TextInput.finishAutofillContext();
      if (!mounted) return;
      // Login-Seite durch die Startseite ersetzen (Zurück führt nicht
      // wieder zum Login).
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
        (_) => false,
      );
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    children: const [
                      TextSpan(
                        text: 'Boo',
                        style: TextStyle(color: Colors.blue),
                      ),
                      TextSpan(text: 'king '),
                      TextSpan(
                        text: 'In',
                        style: TextStyle(color: Colors.blue),
                      ),
                      TextSpan(text: 'terpreter'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _emailController,
                        label: 'E-Mail',
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                      ),
                      AppTextField(
                        controller: _passwordController,
                        label: 'Passwort',
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Anmelden',
                  isLoading: _isLoading,
                  onPressed: _canSubmit ? _handleLogin : null,
                ),
                ErrorText(message: _errorMessage),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ForgotPasswordScreen(
                        initialEmail: _emailController.text.trim(),
                      ),
                    ),
                  ),
                  child: const Text('Passwort vergessen?'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: const Text('Neues Konto anlegen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
