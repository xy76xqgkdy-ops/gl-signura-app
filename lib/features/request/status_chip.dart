import 'package:flutter/material.dart';

import 'request_data.dart';

// Status einer Anfrage als kleines Feld: farbiger Punkt plus Text, damit
// er auch ohne Farbunterscheidung lesbar ist. Gleich in der Liste auf der
// Startseite und oben rechts im Anfrage-Formular.
class StatusChip extends StatelessWidget {
  final RequestStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(Icons.circle, size: 10, color: status.color),
      label: Text(status.text),
      side: BorderSide(color: status.color),
      visualDensity: VisualDensity.compact,
    );
  }
}
