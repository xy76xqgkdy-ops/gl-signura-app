import 'package:flutter/material.dart';

import 'request_data.dart';

// Status einer Anfrage: farbiger Punkt plus Text, damit er auch ohne
// Farbunterscheidung lesbar ist. Bewusst ohne Rahmen und Hintergrund,
// damit er nicht wie ein Knopf aussieht. Gleich in der Liste auf der
// Startseite und oben rechts im Anfrage-Formular.
class StatusChip extends StatelessWidget {
  final RequestStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: status.color),
        const SizedBox(width: 6),
        Text(status.text, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}
