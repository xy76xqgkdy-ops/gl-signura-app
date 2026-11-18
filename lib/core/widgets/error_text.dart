import 'package:flutter/material.dart';

class ErrorText extends StatelessWidget {
  final String? message;
  final TextAlign textAlign;

  const ErrorText({
    super.key,
    required this.message,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 20),
      child: Text(
        message!,
        textAlign: textAlign,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 13,
        ),
      ),
    );
  }
}
