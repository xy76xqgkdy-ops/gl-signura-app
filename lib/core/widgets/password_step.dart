import 'package:flutter/material.dart';

import 'app_text_field.dart';
import 'primary_button.dart';

// Gemeinsamer "Passwort wählen"-Schritt für Register- und
// ForgotPassword-Flow (rein lokal, kein API-Call).
class PasswordStep extends StatelessWidget {
  final String description;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final String passwordLabel;
  final String buttonLabel;
  final bool canSubmit;
  final VoidCallback onSubmit;
  final ValueChanged<String> onChanged;

  const PasswordStep({
    super.key,
    required this.description,
    required this.passwordController,
    required this.confirmController,
    this.passwordLabel = 'Passwort',
    this.buttonLabel = 'Weiter',
    required this.canSubmit,
    required this.onSubmit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(description, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 24),
        AppTextField(
          controller: passwordController,
          label: passwordLabel,
          obscureText: true,
          onChanged: onChanged,
        ),
        AppTextField(
          controller: confirmController,
          label: 'Passwort bestätigen',
          obscureText: true,
          onChanged: onChanged,
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: buttonLabel,
          onPressed: canSubmit ? onSubmit : null,
        ),
      ],
    );
  }
}
