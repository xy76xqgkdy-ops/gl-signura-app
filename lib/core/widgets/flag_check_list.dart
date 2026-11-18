import 'package:flutter/material.dart';

// Ein Eintrag der Liste: Wert, Name und Flaggen-Emoji. Für einige Codes
// gibt es statt der Flagge ein Logo (siehe [logoFor]).
typedef FlagItem = ({String value, String name, String flag});

// Logo statt Flagge, z. B. das offizielle DGS-Logo.
const _logos = {'dgs': 'assets/images/dgs.png'};

String? logoFor(String value) => _logos[value];

// Liste mit Flagge, Name und Häkchen in einem Rahmen. Gewählte Einträge
// stehen oben (in der Reihenfolge von [selected]). Höchstens [maxRows]
// Zeilen sichtbar, der Rest scrollt (Scrollbalken sichtbar).
// Für eine Einfachauswahl (z. B. Sprache der App) [selected] mit genau
// einem Wert übergeben und in [onChanged] ersetzen statt ergänzen.
class FlagCheckList extends StatefulWidget {
  final String label;
  final List<FlagItem> items;
  final List<String> selected;
  final void Function(String value, bool checked) onChanged;
  final int maxRows;

  const FlagCheckList({
    super.key,
    required this.label,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.maxRows = 3,
  });

  @override
  State<FlagCheckList> createState() => _FlagCheckListState();
}

class _FlagCheckListState extends State<FlagCheckList> {
  static const double _rowHeight = 48;
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final selected = widget.selected;
    final maxRows = widget.maxRows;
    final sorted = [
      for (final v in selected) ...items.where((i) => i.value == v),
      ...items.where((i) => !selected.contains(i.value)),
    ];
    final rows = sorted.length.clamp(1, maxRows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: rows * _rowHeight,
            child: Scrollbar(
              controller: _controller,
              thumbVisibility: sorted.length > maxRows,
              child: ListView.builder(
                controller: _controller,
                itemExtent: _rowHeight,
                itemCount: sorted.length,
                itemBuilder: (_, i) {
                  final item = sorted[i];
                  return CheckboxListTile(
                    key: ValueKey(item.value),
                    value: selected.contains(item.value),
                    onChanged: (on) =>
                        widget.onChanged(item.value, on ?? false),
                    secondary: SizedBox(
                      width: 40,
                      child: logoFor(item.value) != null
                          ? Image.asset(
                              logoFor(item.value)!,
                              height: 22,
                              fit: BoxFit.contain,
                              semanticLabel: item.name,
                            )
                          : Text(
                              item.flag,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 22),
                            ),
                    ),
                    title: Text(item.name, overflow: TextOverflow.ellipsis),
                    dense: true,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
