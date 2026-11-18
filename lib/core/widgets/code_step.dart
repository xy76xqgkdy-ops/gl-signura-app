import 'dart:async';

import 'package:flutter/material.dart';

import 'code_input_field.dart';
import 'error_text.dart';
import 'primary_button.dart';

// So lange gilt der Code im Backend (service/email_code.go: codeValidity).
const int _codeValiditySeconds = 10 * 60;

// Gemeinsamer "Code eingeben"-Schritt für Register- und
// ForgotPassword-Flow — löst hier jeweils den finalen API-Call aus
// (register bzw. reset).
class CodeStep extends StatefulWidget {
  final TextEditingController codeController;
  final String buttonLabel;
  final bool isLoading;
  final bool canSubmit;
  final VoidCallback onSubmit;
  final ValueChanged<String> onChanged;
  final String? errorMessage;

  const CodeStep({
    super.key,
    required this.codeController,
    required this.buttonLabel,
    required this.isLoading,
    required this.canSubmit,
    required this.onSubmit,
    required this.onChanged,
    this.errorMessage,
  });

  @override
  State<CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends State<CodeStep> {
  int _secondsLeft = _codeValiditySeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), _handleTick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleTick(Timer timer) {
    if (_secondsLeft <= 1) {
      timer.cancel();
      // Code abgelaufen — zurück zur Anmeldung, ohne den finalen Call
      // (register/reset) auszulösen.
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _secondsLeft--);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Wir haben Ihnen einen Code per E-Mail geschickt.\nDer Code hat 5 Stellen.\nBitte schauen Sie in Ihr E-Mail-Postfach.\nGeben Sie den Code hier ein.',
          style: TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 24),
        CodeInputField(
          controller: widget.codeController,
          onChanged: widget.onChanged,
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Noch ${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')} Minuten',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: widget.buttonLabel,
          isLoading: widget.isLoading,
          onPressed: widget.canSubmit ? widget.onSubmit : null,
        ),
        ErrorText(message: widget.errorMessage),
      ],
    );
  }
}
