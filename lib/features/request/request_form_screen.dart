import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/primary_button.dart';
import '../location/location_form_screen.dart';
import 'request_data.dart';
import 'status_chip.dart';

// Neue Anfrage (POST /me/requests) oder vorhandene bearbeiten
// (PUT /me/requests/{id}) und absagen (POST /me/requests/{id}/cancel).
// Gibt true per Navigator.pop zurück, wenn sich etwas geändert hat.
//
// Ändern geht nur, solange die Anfrage offen ist; absagen, solange der
// Termin noch bevorsteht (dieselben Regeln prüft auch das Backend).
class RequestFormScreen extends StatefulWidget {
  final DateTime initialDate;
  final RequestData? existing; // null = neue Anfrage

  const RequestFormScreen({
    super.key,
    required this.initialDate,
    this.existing,
  });

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  late final RequestData? _existing = widget.existing;
  late DateTime _date = (_existing?.start ?? widget.initialDate).dateOnly;
  late TimeOfDay _startTime = _existing == null
      ? const TimeOfDay(hour: 9, minute: 0)
      : TimeOfDay.fromDateTime(_existing.start);
  late TimeOfDay _endTime = _existing == null
      ? const TimeOfDay(hour: 10, minute: 0)
      : TimeOfDay.fromDateTime(_existing.end);
  late bool _remote = _existing?.remote ?? false;
  late String? _purpose = _existing?.purpose;

  // Auswahl für den Anlass. Ein älterer, freier Anlass einer vorhandenen
  // Anfrage bleibt als zusätzliche Option erhalten.
  static const _purposes = ['Arzt', 'Arbeit', 'Behörde', 'Privat', 'Sonstige'];
  List<String> get _purposeOptions => [
    ..._purposes,
    if (_existing != null && !_purposes.contains(_existing.purpose))
      _existing.purpose,
  ];

  // Adresse der Anfrage: gehört der Anfrage selbst. Ein gespeicherter
  // Einsatzort füllt die Felder nur aus; ändert man ihn später, bleibt
  // diese Anfrage unverändert.
  late final _locName = TextEditingController(text: _existing?.locationName);
  late final _locStreet = TextEditingController(
    text: _existing?.locationStreet == 'per Video'
        ? ''
        : _existing?.locationStreet,
  );
  late final _locPostal = TextEditingController(
    text: _existing?.locationPostalcode,
  );
  late final _locCity = TextEditingController(text: _existing?.locationCity);
  late final _locEmail = TextEditingController(text: _existing?.locationEmail);
  late final _locPhone = TextEditingController(text: _existing?.locationPhone);
  late String? _locationId = _existing?.locationId; // nur Herkunft

  List<LocationData> _locations = [];
  bool _loadingLocations = true;
  int _pickerReset = 0; // setzt die Übernehmen-Auswahl nach Gebrauch zurück

  bool _isLoading = false;
  String? _errorMessage;

  // Neue Anfrage oder offene: alle Felder änderbar.
  bool get _editable =>
      _existing == null || _existing.status == RequestStatus.newRequest;

  bool get _canCancel =>
      _existing != null &&
      _existing.status != RequestStatus.cancelled &&
      _existing.start.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    for (final c in [
      _locName,
      _locStreet,
      _locPostal,
      _locCity,
      _locEmail,
      _locPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // Adresse aus einem gespeicherten Einsatzort in die Felder übernehmen.
  void _applyLocation(LocationData l) {
    setState(() {
      _locName.text = l.name;
      _locStreet.text = l.street;
      _locPostal.text = l.postalcode;
      _locCity.text = l.city;
      _locEmail.text = l.email;
      _locPhone.text = l.phone;
      _locationId = l.id;
      _pickerReset++;
    });
  }

  Future<void> _loadLocations() async {
    try {
      final list = await ApiClient.getJsonList('/me/locations');
      if (!mounted) return;
      setState(() {
        _locations = list.map(LocationData.fromJson).toList();
        _loadingLocations = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _loadingLocations = false;
      });
    }
  }

  Future<void> _newLocation() async {
    final created = await Navigator.of(context).push<LocationData>(
      MaterialPageRoute(builder: (_) => const LocationFormScreen()),
    );
    if (!mounted) return;
    if (created == null) {
      setState(() => _pickerReset++); // Auswahl zurücksetzen
      return;
    }
    _locations = [..._locations, created];
    _applyLocation(created);
  }

  DateTime _at(TimeOfDay t) =>
      DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);

  bool get _canSave =>
      (_purpose ?? '').isNotEmpty &&
      _at(_endTime).isAfter(_at(_startTime)) &&
      (_remote ||
          [
            _locStreet,
            _locPostal,
            _locCity,
          ].every((c) => c.text.trim().isNotEmpty)) &&
      _editable &&
      !_isLoading;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today(),
      lastDate: today().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        // Ende mitschieben, damit die Dauer gleich bleibt.
        final minutes =
            (_endTime.hour * 60 + _endTime.minute) -
            (_startTime.hour * 60 + _startTime.minute);
        _startTime = picked;
        final end =
            picked.hour * 60 + picked.minute + (minutes > 0 ? minutes : 60);
        _endTime = TimeOfDay(hour: (end ~/ 60).clamp(0, 23), minute: end % 60);
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final body = {
      'start_date': _at(_startTime).toUtc().toIso8601String(),
      'end_date': _at(_endTime).toUtc().toIso8601String(),
      'purpose': _purpose,
      'mode': _remote ? 'remote' : 'on_site',
      // Auch bei "per Video" alles mitsenden (Adresse unsichtbar übernommen);
      // ohne Straße setzt das Backend "per Video".
      'location_id': _locationId,
      'location_name': _locName.text.trim(),
      'location_street': _locStreet.text.trim(),
      'location_postalcode': _locPostal.text.trim(),
      'location_city': _locCity.text.trim(),
      'location_email': _locEmail.text.trim(),
      'location_phone': _locPhone.text.trim(),
    };
    try {
      if (_existing == null) {
        await ApiClient.postJson('/me/requests', body: body);
      } else {
        await ApiClient.putJson('/me/requests/${_existing.id}', body: body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anfrage absagen?'),
        content: Text(
          '${_existing!.purpose} am ${_existing.start.formattedDate} '
          'um ${_existing.start.formattedTime} Uhr wird abgesagt. '
          'Das lässt sich nicht rückgängig machen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Nicht absagen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Absagen'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ApiClient.postJson('/me/requests/${_existing!.id}/cancel');
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  String _fmt(TimeOfDay t) => '${pad2(t.hour)}:${pad2(t.minute)}';

  // Stil der Eingabefelder (wie AppTextField) für Auswahlfelder.
  InputDecorationTheme _fieldTheme(BuildContext context) =>
      InputDecorationTheme(
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        // Eigener Feldstil überschreibt das Theme: Platzhalter hier auch grau.
        hintStyle: TextStyle(color: Theme.of(context).hintColor),
      );

  // Antippbares Feld im Stil der Eingabefelder (Datum, Beginn, Ende).
  Widget _tapField(
    IconData icon,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _editable ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          child: Text(value, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _existing == null
              ? 'Neue Anfrage'
              : _editable
              ? 'Anfrage bearbeiten'
              : 'Anfrage',
        ),
        // Status oben rechts (bei neuer Anfrage gibt es noch keinen).
        actions: [
          if (_existing != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: StatusChip(status: _existing.status),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Warum die Felder gesperrt sind (Status selbst steht oben rechts).
              if (_existing != null &&
                  !_editable &&
                  _existing.status != RequestStatus.cancelled)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Die Anfrage ist schon weitergeleitet und kann nicht '
                    'mehr geändert werden. Sie können sie absagen.',
                  ),
                ),
              // Anlass und vor Ort / per Video in einer Zeile.
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _purpose,
                        isExpanded: true,
                        hint: const Text('Bitte wählen'),
                        decoration: InputDecoration(
                          labelText: 'Anlass',
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                        items: [
                          for (final p in _purposeOptions)
                            DropdownMenuItem(value: p, child: Text(p)),
                        ],
                        onChanged: _editable
                            ? (p) => setState(() => _purpose = p)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(value: false, label: Text('vor Ort')),
                        ButtonSegment(value: true, label: Text('per Video')),
                      ],
                      selected: {_remote},
                      onSelectionChanged: _editable
                          ? (s) => setState(() => _remote = s.first)
                          : null,
                    ),
                  ],
                ),
              ),
              _tapField(
                Icons.calendar_today,
                'Datum',
                _date.formattedDate,
                _pickDate,
              ),
              Row(
                children: [
                  Expanded(
                    child: _tapField(
                      Icons.schedule,
                      'Beginn',
                      _fmt(_startTime),
                      () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tapField(
                      Icons.schedule_outlined,
                      'Ende',
                      _fmt(_endTime),
                      () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Gespeicherten Einsatzort suchen und übernehmen (auch bei
              // "per Video"), "+" legt einen neuen an. Stil wie "Anlass".
              if (_editable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _loadingLocations
                            ? const Center(child: CircularProgressIndicator())
                            : DropdownMenu<String>(
                                key: ValueKey('picker_$_pickerReset'),
                                expandedInsets: EdgeInsets.zero,
                                enableFilter: true,
                                requestFocusOnTap: true,
                                label: const Text('Einsatzort'),
                                hintText: 'Einsatzort finden',
                                // Suchsymbol statt Pfeil, offen wie geschlossen.
                                trailingIcon: const Icon(Icons.search),
                                selectedTrailingIcon: const Icon(Icons.search),
                                menuHeight: 300,
                                inputDecorationTheme: _fieldTheme(context),
                                dropdownMenuEntries: [
                                  for (final l in _locations)
                                    DropdownMenuEntry(
                                      value: l.id,
                                      label: '${l.name} – ${l.address}',
                                    ),
                                ],
                                onSelected: (id) {
                                  if (id == null) return;
                                  _applyLocation(
                                    _locations.firstWhere((l) => l.id == id),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Neuer Einsatzort',
                        icon: const Icon(Icons.add),
                        onPressed: _isLoading ? null : _newLocation,
                      ),
                    ],
                  ),
                ),
              AppTextField(
                controller: _locName,
                label: _remote
                    ? 'Name (z. B. Gesprächspartner)'
                    : 'Name (z. B. Praxis Dr. Müller)',
                readOnly: !_editable,
                onChanged: (_) => setState(() {}),
              ),
              // Adresse und Kontakt: bei "per Video" ausgeblendet, aber
              // aus dem gewählten Einsatzort trotzdem mitgespeichert.
              if (!_remote) ...[
                AppTextField(
                  controller: _locStreet,
                  label: 'Straße und Hausnummer',
                  readOnly: !_editable,
                  onChanged: (_) => setState(() {}),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: AppTextField(
                        controller: _locPostal,
                        label: 'PLZ',
                        keyboardType: TextInputType.number,
                        readOnly: !_editable,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _locCity,
                        label: 'Ort',
                        readOnly: !_editable,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _locEmail,
                        label: 'E-Mail (optional)',
                        keyboardType: TextInputType.emailAddress,
                        readOnly: !_editable,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _locPhone,
                        label: 'Telefon (optional)',
                        keyboardType: TextInputType.phone,
                        readOnly: !_editable,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // absagen links, speichern rechts.
              Row(
                children: [
                  if (_canCancel)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      onPressed: _isLoading ? null : _cancel,
                      icon: const Icon(Icons.event_busy),
                      label: const Text('absagen'),
                    ),
                  const Spacer(),
                  if (_editable)
                    PrimaryButton(
                      label: _existing == null ? 'Anfrage senden' : 'speichern',
                      isLoading: _isLoading,
                      onPressed: _canSave ? _save : null,
                    ),
                ],
              ),
              ErrorText(message: _errorMessage),
            ],
          ),
        ),
      ),
    );
  }
}
