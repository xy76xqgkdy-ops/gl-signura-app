import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/day_list_card.dart';
import '../request/request_data.dart';
import 'location_form_screen.dart';

// Eigene Einsatzorte (GET /me/locations): oben suchen (Name, Straße, PLZ,
// Ort), antippen zum Ändern oder Löschen, "+" für einen neuen.
class LocationListScreen extends StatefulWidget {
  const LocationListScreen({super.key});

  @override
  State<LocationListScreen> createState() => _LocationListScreenState();
}

class _LocationListScreenState extends State<LocationListScreen> {
  List<LocationData> _locations = [];
  bool _isLoading = true;
  String? _errorMessage;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<LocationData> get _shown {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _locations;
    return _locations
        .where((l) => '${l.name} ${l.address}'.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await ApiClient.getJsonList('/me/locations');
      if (!mounted) return;
      setState(() {
        _locations = list.map(LocationData.fromJson).toList();
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _open([LocationData? location]) async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(builder: (_) => LocationFormScreen(existing: location)),
    );
    if (result != null && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Orte'),
        actions: [
          IconButton(
            tooltip: 'Neuer Ort',
            icon: const Icon(Icons.add, size: 32),
            onPressed: () => _open(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Suchfeld: filtert die Liste beim Tippen.
              if (_locations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Ort suchen',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Suche löschen',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => _search.clear()),
                            ),
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
              DayListCard(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                emptyText: _isLoading
                    ? null
                    : _locations.isEmpty
                    ? 'Sie haben noch keine Orte gespeichert. Tippen Sie auf +.'
                    : 'Kein Ort gefunden.',
                children: [
                  for (final l in _shown)
                    ListTile(
                      leading: const Icon(Icons.place),
                      title: Text(l.name),
                      subtitle: Text(l.address),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(l),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
