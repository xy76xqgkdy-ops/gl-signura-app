import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../utils/date_utils.dart';
import 'error_text.dart';

/// Farbiger Zähler unter einem Kalendertag.
class CalendarBadge {
  final Color color;
  final int count;
  final Color? borderColor;

  const CalendarBadge(this.color, this.count, {this.borderColor});
}

/// Monatskalender (table_calendar) zur Auswahl eines Tages mit Status-Badges
/// je Tag — gemeinsame Darstellung für features/invoice/calendar_card.dart
/// und features/request/calendar_card.dart, die nur noch ihre Zähler laden.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.focusedMonth,
    required this.onMonthChanged,
    required this.badgesFor,
    this.isLoading = false,
    this.errorMessage,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  /// Aktuell angezeigter Monat, wird vom Elternwidget vorgegeben (Kopfzeile
  /// mit Monatsname + Blättern liegt in appointments_screen.dart).
  final DateTime focusedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  /// Badges für einen Tag des angezeigten Monats (1..31).
  final List<CalendarBadge> Function(int day) badgesFor;
  final bool isLoading;
  final String? errorMessage;

  void _onPageChanged(DateTime focusedDay) {
    // UTC statt lokal, damit es exakt zum intern von table_calendar
    // verwendeten UTC-Datum passt (sonst löst jeder Seitenwechsel einen
    // unnötigen Resync aus, siehe appointments_screen.dart).
    onMonthChanged(DateTime.utc(focusedDay.year, focusedDay.month));
  }

  Widget _badge(CalendarBadge badge) {
    if (badge.count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: badge.color,
        shape: BoxShape.circle,
        border: badge.borderColor == null
            ? null
            : Border.all(color: badge.borderColor!),
      ),
      alignment: Alignment.center,
      child: Text(
        '${badge.count}',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _dayCell(
    BuildContext context,
    DateTime day, {
    required bool isSelected,
    required bool isToday,
  }) {
    final theme = Theme.of(context);
    final badges = day.month == focusedMonth.month
        ? badgesFor(day.day)
        : const <CalendarBadge>[];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : null,
            border: isToday && !isSelected
                ? Border.all(color: theme.colorScheme.primary)
                : null,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${day.day}',
            style: TextStyle(color: isSelected ? Colors.white : null),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [for (final badge in badges) _badge(badge)],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            TableCalendar(
              locale: 'de_DE',
              firstDay: DateTime.utc(2015, 1, 1),
              lastDay: DateTime.utc(2035, 12, 31),
              focusedDay: focusedMonth,
              currentDay: today(),
              startingDayOfWeek: StartingDayOfWeek.monday,
              rowHeight: 56,
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: 'Monat'},
              // Aus: der eingebaute Chevron-Header kann bei schnellem
              // Antippen die PageController-Animation unterbrechen und den
              // Monat "hängen bleiben" lassen (z.B. Dez 2025 -> Jan 2026).
              // Blättern erfolgt daher nur per Wischgeste; Monatsname wird
              // in der AppBar dargestellt.
              headerVisible: false,
              calendarStyle: const CalendarStyle(outsideDaysVisible: false),
              selectedDayPredicate: (day) => isSameDay(day, selectedDate),
              onDaySelected: (selectedDay, focusedDay) =>
                  onDateSelected(selectedDay),
              onPageChanged: _onPageChanged,
              calendarBuilders: CalendarBuilders(
                selectedBuilder: (context, day, focusedDay) =>
                    _dayCell(context, day, isSelected: true, isToday: false),
                todayBuilder: (context, day, focusedDay) =>
                    _dayCell(context, day, isSelected: false, isToday: true),
                defaultBuilder: (context, day, focusedDay) =>
                    _dayCell(context, day, isSelected: false, isToday: false),
              ),
            ),
          ],
        ),
        if (isLoading) const CircularProgressIndicator(),
        if (errorMessage != null) ErrorText(message: errorMessage),
      ],
    );
  }
}
