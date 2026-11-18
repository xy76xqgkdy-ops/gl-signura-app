import 'package:flutter/material.dart';

import 'error_text.dart';

/// Tagesliste unter dem Kalender (Termine, Anfragen, Anfragemarkt): Fehler-
/// oder Leer-Hinweis, sonst die Kacheln mit Trennlinien, dazu ein
/// Lade-Overlay. [emptyText] null = bei leerer Liste komplett ausblenden.
class DayListCard extends StatelessWidget {
  const DayListCard({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.children,
    this.emptyText,
    this.trailingDivider = false,
  });

  final bool isLoading;
  final String? errorMessage;
  final List<Widget> children;
  final String? emptyText;
  final bool trailingDivider;

  @override
  Widget build(BuildContext context) {
    if (emptyText == null &&
        errorMessage == null &&
        !isLoading &&
        children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ErrorText(message: errorMessage),
                )
              else if (children.isEmpty && emptyText != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ErrorText(message: emptyText),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: children.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => children[i],
                ),
              if (trailingDivider) const Divider(height: 1),
            ],
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
