import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/day_list_card.dart';
import '../request/request_data.dart';
import 'location_form_screen.dart';

// Eigene Einsatzorte (GET /me/locations): antippen zum Ändern oder Löschen,
// "+" für einen neuen.
class LocationListScreen extends StatefulWidget {
  const LocationListScreen({super.key});

  @override
  State<LocationListScreen> createState() => _LocationListScreenState();
}

class _LocationListScreenState extends State<LocationListScreen> {
  List<LocationData> _locations = [];
  bool _isLoading = true;
  String? _errorMessage;

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
        title: const Text('Einsatzorte'),
        actions: [
          IconButton(
            tooltip: 'Neuer Einsatzort',
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
              DayListCard(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                emptyText: _isLoading
                    ? null
                    : 'Noch keine Einsatzorte. Mit „+“ legen Sie einen an.',
                children: [
                  for (final l in _locations)
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
