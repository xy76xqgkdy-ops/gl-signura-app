import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const int _codeLength = 5;

class CodeInputField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const CodeInputField({super.key, required this.controller, this.onChanged});

  @override
  State<CodeInputField> createState() => _CodeInputFieldState();
}

class _CodeInputFieldState extends State<CodeInputField> {
  late final List<TextEditingController> _digitControllers;
  late final List<FocusNode> _focusNodes;
  late final List<FocusNode> _keyboardListenerNodes;

  @override
  void initState() {
    super.initState();
    _digitControllers = List.generate(
      _codeLength,
      (_) => TextEditingController(),
    );
    _focusNodes = List.generate(_codeLength, (_) => FocusNode());
    _keyboardListenerNodes = List.generate(
      _codeLength,
      (_) => FocusNode(skipTraversal: true),
    );
    _applyExternalValue(widget.controller.text);
    widget.controller.addListener(_handleExternalChange);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNodes[0].requestFocus(),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleExternalChange);
    for (final controller in _digitControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    for (final node in _keyboardListenerNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Hält die einzelnen Kästchen synchron, wenn der Controller von
  // außen verändert wird (z. B. beim Zurücksetzen des Formulars).
  void _handleExternalChange() {
    final value = widget.controller.text;
    if (value == _combinedValue()) return;
    _applyExternalValue(value);
  }

  void _applyExternalValue(String value) {
    for (var i = 0; i < _codeLength; i++) {
      _digitControllers[i].text = i < value.length ? value[i] : '';
    }
  }

  String _combinedValue() => _digitControllers.map((c) => c.text).join();

  void _updateCombinedValue() {
    final value = _combinedValue();
    widget.controller.text = value;
    widget.onChanged?.call(value);
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Eingefügter Text (z. B. kompletter Code) auf die Kästchen verteilen.
      final digits = value.replaceAll(RegExp(r'\D'), '');
      _applyExternalValue(digits);
      _updateCombinedValue();
      final nextIndex = digits.length.clamp(0, _codeLength - 1);
      _focusNodes[nextIndex].requestFocus();
      return;
    }

    _updateCombinedValue();
    if (value.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _digitControllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_codeLength, (index) {
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
          child: SizedBox(
            width: 52,
            height: 60,
            child: KeyboardListener(
              focusNode: _keyboardListenerNodes[index],
              onKeyEvent: (event) => _onKeyEvent(index, event),
              child: TextField(
                controller: _digitControllers[index],
                focusNode: _focusNodes[index],
                onChanged: (value) => _onDigitChanged(index, value),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
