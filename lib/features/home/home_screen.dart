import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/session/session_store.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/day_list_card.dart';
import '../../core/widgets/month_calendar.dart';
import '../auth/login_screen.dart';
import '../location/location_list_screen.dart';
import '../profile/notifications_screen.dart';
import '../profile/picture_screen.dart';
import '../profile/profile_screen.dart';
import '../request/request_data.dart';
import '../request/request_form_screen.dart';
import '../request/status_chip.dart';

// Startseite: Monatskalender mit den eigenen Anfragen (farbige Zähler je
// Status, Monat per Wischen wechseln), darunter die Anfragen des gewählten
// Tages; "+" neben dem Datum legt eine neue an. Oben "⋮" für Profilbild,
// Person bearbeiten, Einsatzorte, Benachrichtigungen und Abmelden.
// Daten: GET /me/requests für den angezeigten Monat.
class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _Menu { picture, profile, locations, notifications, logout }

class _HomeScreenState extends State<HomeScreen> {
  late Map<String, dynamic> _user = widget.user;
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

  Future<void> _onMenu(_Menu item) async {
    switch (item) {
      case _Menu.profile:
        final user = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(builder: (_) => ProfileScreen(user: _user)),
        );
        if (user != null && mounted) setState(() => _user = user);
      case _Menu.picture:
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const PictureScreen()));
      case _Menu.locations:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const LocationListScreen()));
        if (mounted) _load(); // geänderte Ortsnamen in den Anfragen
      case _Menu.notifications:
        final user = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(builder: (_) => NotificationsScreen(user: _user)),
        );
        if (user != null && mounted) setState(() => _user = user);
      case _Menu.logout:
        await _logout();
    }
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
    final ofDay = _requestsOfSelectedDay;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMM('de_DE').format(_focusedMonth)),
        actions: [
          PopupMenuButton<_Menu>(
            tooltip: 'Menü',
            icon: const Icon(Icons.more_vert),
            onSelected: _onMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _Menu.picture,
                child: ListTile(
                  leading: Icon(Icons.account_circle_outlined),
                  title: Text('Profilbild'),
                ),
              ),
              PopupMenuItem(
                value: _Menu.profile,
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Person bearbeiten'),
                ),
              ),
              PopupMenuItem(
                value: _Menu.locations,
                child: ListTile(
                  leading: Icon(Icons.place_outlined),
                  title: Text('Einsatzorte'),
                ),
              ),
              PopupMenuItem(
                value: _Menu.notifications,
                child: ListTile(
                  leading: Icon(Icons.notifications_outlined),
                  title: Text('Benachrichtigungen'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _Menu.logout,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Abmelden'),
                ),
              ),
            ],
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
                // Datum des Tages, rechts "+" für eine neue Anfrage.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat.yMMMMEEEEd('de_DE').format(_selectedDate),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Neue Anfrage',
                        icon: const Icon(Icons.add),
                        onPressed: _newRequest,
                      ),
                    ],
                  ),
                ),
                if (ofDay.isEmpty && _errorMessage == null && !_isLoading)
                  _EmptyDay(onNew: _newRequest)
                else
                  DayListCard(
                    isLoading: false,
                    errorMessage: _errorMessage,
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

// Leerer Tag: Hinweis und Button "Neue Anfrage" in der Mitte.
class _EmptyDay extends StatelessWidget {
  final VoidCallback onNew;

  const _EmptyDay({required this.onNew});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, size: 48, color: muted),
          const SizedBox(height: 8),
          Text(
            'An diesem Tag haben Sie keine Anfragen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add),
            label: const Text('Neue Anfrage'),
          ),
        ],
      ),
    );
  }
}

// Eine Anfrage in der Liste:
//   links   Foto des Dolmetschers, sonst Symbol Video bzw. Ort
//   Zeile 1 fett: Beginn – Ende · Name des Einsatzorts
//   Zeile 2 klein: Video + Dolmetscher bzw. Karte + Straße, PLZ Ort
//   Zeile 3 klein (nur vor Ort): sprechende Person + Dolmetscher
//   rechts  Status
class _RequestTile extends StatelessWidget {
  final RequestData request;
  final VoidCallback onTap;

  const _RequestTile({required this.request, required this.onTap});

  static const _noInterpreter = 'noch keine Zusage';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final cancelled = request.status == RequestStatus.cancelled;
    // Beauftragt: Namen; offen: Zahl der Zusagen und Bedarf.
    final interpreter = (request.interpreterName ?? '').isNotEmpty
        ? request.interpreterName!
        : request.status == RequestStatus.newRequest && request.offerCount > 0
        ? '${request.offerCount} ${request.offerCount == 1 ? 'Zusage' : 'Zusagen'}'
              ' · ${request.interpretersNeeded} benötigt'
        : request.interpretersNeeded > 1
        ? 'noch keine Zusage · ${request.interpretersNeeded} benötigt'
        : _noInterpreter;
    final place = request.locationName.isNotEmpty
        ? request.locationName
        : request.purpose;

    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: muted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        ],
      ),
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(context),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${request.timeRange}  ·  $place',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (request.remote)
                    line(Icons.videocam_outlined, interpreter)
                  else ...[
                    line(Icons.map_outlined, request.addressText),
                    line(Icons.record_voice_over_outlined, interpreter),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(status: request.status),
          ],
        ),
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    final picture = request.interpreterPicture;
    final color = request.status.color;
    if (picture != null) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(picture),
        onBackgroundImageError: (_, _) {}, // Bild fehlt → Hintergrundfarbe
        backgroundColor: color.withValues(alpha: 0.15),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(request.remote ? Icons.videocam : Icons.place, color: color),
    );
  }
}
