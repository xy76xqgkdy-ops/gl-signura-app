/// Gemeinsame Datums-Helfer — ersetzt die zuvor in mehreren Dateien
/// kopierten `_pad2`/`_isoDate`/`_isoMonth`/`_today`-Funktionen.
String pad2(int n) => n.toString().padLeft(2, '0');

/// Heutiger Kalendertag ohne Uhrzeit.
DateTime today() => DateTime.now().dateOnly;

extension DateTimeFormat on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);

  /// yyyy-MM — Monatsfilter der Kalender-Endpunkte.
  String get isoMonth => '$year-${pad2(month)}';

  /// yyyy-MM-dd — Tagesfilter und Datumsfelder im Backend.
  String get isoDate => '$isoMonth-${pad2(day)}';

  /// yyyy-MM-dd HH:mm:ss — Zeitstempel im Backend.
  String get isoDateTime => '$isoDate $formattedTime:${pad2(second)}';

  /// HH:mm
  String get formattedTime => '${pad2(hour)}:${pad2(minute)}';

  /// dd.MM.yyyy
  String get formattedDate => '${pad2(day)}.${pad2(month)}.$year';

  /// dd.MM.yyyy HH:mm
  String get formattedDateTime => '$formattedDate $formattedTime';
}
