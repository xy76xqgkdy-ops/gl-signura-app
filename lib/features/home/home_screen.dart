import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/session/session_store.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/day_list_card.dart';
import '../../core/widgets/month_calendar.dart';
import '../auth/login_screen.dart';
import '../location/location_list_screen.dart';
import '../request/request_data.dart';
import '../request/request_form_screen.dart';
import '../request/status_chip.dart';

// Startseite: Monatskalender mit den eigenen Anfragen (farbige Zähler je
// Status), darunter die Anfragen des gewählten Tages. "+" legt eine neue an.
// Daten: GET /me/requests für den angezeigten Monat.
class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = today();
  // UTC wie in dolmi, passend zu table_calendar (siehe month_calendar.dart).
  late DateTime _focusedMonth = DateTime.utc(
    _selectedDate.year,
    _selectedDate.month,
  );

  List<RequestData> _requests = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final from = DateTime(_focusedMonth.year, _focusedMonth.month);
    final to = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await ApiClient.getJsonList(
        '/me/requests',
        query: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
      );
      if (!mounted) return;
      setState(() {
        _requests = list.map(RequestData.fromJson).toList();
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) return _toLogin(); // Sitzung abgelaufen
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  List<CalendarBadge> _badgesFor(int day) {
    final ofDay = _requests.where(
      (r) =>
          r.start.year == _focusedMonth.year &&
          r.start.month == _focusedMonth.month &&
          r.start.day == day,
    );
    return [
      for (final status in RequestStatus.values)
        CalendarBadge(
          status.color,
          ofDay.where((r) => r.status == status).length,
        ),
    ];
  }

  List<RequestData> get _requestsOfSelectedDay => _requests
      .where((r) => r.start.dateOnly == _selectedDate.dateOnly)
      .toList();

  Future<void> _newRequest() async {
    final initial = _selectedDate.isBefore(today()) ? today() : _selectedDate;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RequestFormScreen(initialDate: initial),
      ),
    );
    if (created == true && mounted) _load();
  }

  // Anfrage öffnen: bearbeiten, solange offen; sonst ansehen und ggf. absagen.
  Future<void> _openRequest(RequestData request) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            RequestFormScreen(initialDate: request.start, existing: request),
      ),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _logout() async {
    await SessionStore.logout();
    if (!mounted) return;
    _toLogin();
  }

  void _toLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.user['first_name'] as String? ?? '';
    final ofDay = _requestsOfSelectedDay;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMM('de_DE').format(_focusedMonth)),
        actions: [
          IconButton(
            tooltip: 'Neue Anfrage',
            icon: const Icon(Icons.add, size: 32),
            onPressed: _newRequest,
          ),
          IconButton(
            tooltip: 'Einsatzorte',
            icon: const Icon(Icons.place_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LocationListScreen()),
              );
              if (mounted) _load(); // geänderte Ortsnamen in den Anfragen
            },
          ),
          IconButton(
            tooltip: 'Abmelden',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    'Hallo $firstName',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                MonthCalendar(
                  selectedDate: _selectedDate,
                  onDateSelected: (d) => setState(() => _selectedDate = d),
                  focusedMonth: _focusedMonth,
                  onMonthChanged: (month) {
                    setState(() => _focusedMonth = month);
                    _load();
                  },
                  badgesFor: _badgesFor,
                  isLoading: _isLoading,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    DateFormat.yMMMMEEEEd('de_DE').format(_selectedDate),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                DayListCard(
                  isLoading: false,
                  errorMessage: _errorMessage,
                  emptyText: 'Keine Anfragen an diesem Tag',
                  children: [
                    for (final r in ofDay)
                      _RequestTile(request: r, onTap: () => _openRequest(r)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final RequestData request;
  final VoidCallback onTap;

  const _RequestTile({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      onTap: onTap,
      leading: Icon(
        request.remote ? Icons.videocam : Icons.place,
        color: request.status.color,
        size: 32,
      ),
      title: Text(
        '${request.timeRange}  ·  ${request.purpose}',
        style: request.status == RequestStatus.cancelled
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(request.placeText, style: TextStyle(color: muted)),
      trailing: StatusChip(status: request.status),
    );
  }
}
