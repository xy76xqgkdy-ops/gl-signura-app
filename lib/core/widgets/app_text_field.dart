import 'package:flutter/material.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;
  final bool readOnly;
  final bool autofocus;
  final int maxLines;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.autofillHints,
    this.suffixIcon,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;
  late final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: widget.controller,
        obscureText: _obscured,
        keyboardType: widget.keyboardType,
        onChanged: widget.onChanged,
        validator: widget.validator,
        autofillHints: widget.autofillHints,
        readOnly: widget.readOnly,
        autofocus: widget.autofocus,
        focusNode: _focusNode,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.label,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          // Ein-/Ausblenden nur bei Passwortfeldern (obscureText: true) anbieten,
          // sonst ein optional übergebenes Icon (z.B. Face ID im E-Mail-Feld).
          suffixIcon: widget.obscureText
              ? IconButton(
                  icon: Icon(
                    _obscured ? Icons.visibility_off : Icons.visibility,
                  ),
                  tooltip: _obscured
                      ? 'Passwort anzeigen'
                      : 'Passwort verbergen',
                  onPressed: () => setState(() => _obscured = !_obscured),
                )
              : widget.suffixIcon,
        ),
      ),
    );
  }
}
