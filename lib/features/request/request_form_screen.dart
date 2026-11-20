import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/primary_button.dart';
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
  // Fokus des Namensfelds (für die Vorschläge aus "Meine Orte").
  final _locNameFocus = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  // Zusagen von Dolmetscher:innen (nur Namen, keine Vermittler) und die
  // zum Beauftragen angekreuzten.
  List<OfferData> _offers = [];
  final Set<String> _chosen = {};

  bool get _isOpen =>
      _existing != null && _existing.status == RequestStatus.newRequest;

  // Neue Anfrage oder offene ohne Zusagen: alle Felder änderbar. Gibt es
  // schon Zusagen, würden sie zu geänderten Angaben nicht mehr passen.
  bool get _editable =>
      _existing == null || (_isOpen && _existing.offerCount == 0);

  List<OfferData> get _openOffers =>
      _offers.where((o) => o.status == 'offered').toList();

  bool get _canAward => _isOpen && _chosen.isNotEmpty && !_isLoading;

  bool get _canCancel =>
      _existing != null &&
      _existing.status != RequestStatus.cancelled &&
      _existing.start.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadLocations();
    final e = _existing;
    if (e != null &&
        (e.offerCount > 0 || e.status == RequestStatus.confirmed)) {
      _loadOffers();
    }
  }

  Future<void> _loadOffers() async {
    try {
      final list = await ApiClient.getJsonList(
        '/me/requests/${_existing!.id}/offers',
      );
      if (!mounted) return;
      setState(() => _offers = list.map(OfferData.fromJson).toList());
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    }
  }

  // Angekreuzte Zusagen beauftragen; die übrigen werden abgelehnt.
  Future<void> _award() async {
    final n = _chosen.length;
    final names = [
      for (final o in _openOffers)
        if (_chosen.contains(o.id)) o.interpreterName,
    ].join(', ');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          n == 1 ? '1 Dolmetscher buchen?' : '$n Dolmetscher buchen?',
        ),
        content: Text(
          '$names\n\nDie anderen bekommen eine Absage. '
          'Sie können das nicht rückgängig machen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('buchen'),
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
      await ApiClient.postJson(
        '/me/requests/${_existing!.id}/award',
        body: {'offer_ids': _chosen.toList()},
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
      _loadOffers(); // z. B. inzwischen zurückgezogene Zusage
    }
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
    _locNameFocus.dispose();
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
    });
  }

  Future<void> _loadLocations() async {
    try {
      final list = await ApiClient.getJsonList('/me/locations');
      if (!mounted) return;
      setState(() => _locations = list.map(LocationData.fromJson).toList());
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    }
  }

  // Vorschläge aus "Meine Orte" passend zum eingetippten Namen (auch Straße
  // oder Ort). Leeres Feld: alle Orte.
  Iterable<LocationData> _locationOptions(TextEditingValue value) {
    final q = value.text.trim().toLowerCase();
    if (q.isEmpty) return _locations;
    return _locations.where(
      (l) => '${l.name} ${l.address}'.toLowerCase().contains(q),
    );
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
          'Sie können das nicht rückgängig machen.',
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

  // Warum die Anfrage nicht mehr änderbar ist.
  String _lockedHint(RequestData r) {
    if (r.status == RequestStatus.confirmed) {
      final names = (r.interpreterName ?? '').isNotEmpty
          ? ': ${r.interpreterName}'
          : '';
      return 'Gebucht$names. Sie können den Termin absagen.';
    }
    if (r.status == RequestStatus.newRequest && r.offerCount > 0) {
      return 'Es gibt Zusagen. Kreuzen Sie an, wen Sie buchen möchten. '
          'Sie können die Anfrage nicht mehr ändern. Sie können sie absagen '
          'und eine neue Anfrage stellen.';
    }
    return 'Die Anfrage kann nicht mehr geändert werden. Sie können sie '
        'absagen.';
  }

  // Zusagen: offen → ankreuzen; beauftragt → mit Haken; nur Namen.
  Widget _offersSection(BuildContext context) {
    final shown = _isOpen
        ? _openOffers
        : _offers.where((o) => o.status == 'awarded').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isOpen
              ? 'Zusagen: ${_chosen.length} ausgewählt'
              : 'Gebuchte Dolmetscher',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final o in shown)
                _isOpen
                    ? CheckboxListTile(
                        value: _chosen.contains(o.id),
                        onChanged: _isLoading
                            ? null
                            : (on) => setState(
                                () => on == true
                                    ? _chosen.add(o.id)
                                    : _chosen.remove(o.id),
                              ),
                        secondary: const Icon(Icons.record_voice_over_outlined),
                        title: Text(o.interpreterName),
                        dense: true,
                      )
                    : ListTile(
                        leading: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        title: Text(o.interpreterName),
                        dense: true,
                      ),
            ],
          ),
        ),
      ],
    );
  }

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
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_lockedHint(_existing)),
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
                          labelText: 'Grund',
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
              const SizedBox(height: 4),
              // Name des Orts mit Suche: Tippen zeigt passende Orte aus
              // "Meine Orte", Antippen übernimmt die Adresse. Ein neuer Ort
              // landet beim Speichern der Anfrage automatisch in "Meine Orte"
              // (macht das Backend, wenn Name, Straße, PLZ und Ort neu sind).
              if (_editable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        RawAutocomplete<LocationData>(
                          textEditingController: _locName,
                          focusNode: _locNameFocus,
                          optionsBuilder: _locationOptions,
                          displayStringForOption: (l) => l.name,
                          onSelected: _applyLocation,
                          fieldViewBuilder: (context, controller, focus, _) =>
                              TextField(
                                controller: controller,
                                focusNode: focus,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: _remote
                                      ? 'Name (z. B. Gesprächspartner)'
                                      : 'Name des Orts (z. B. Praxis Dr. Müller)',
                                  hintText: 'Name eingeben oder suchen',
                                  suffixIcon: const Icon(Icons.search),
                                ).applyDefaults(_fieldTheme(context)),
                              ),
                          optionsViewBuilder: (context, onSelected, options) =>
                              Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(8),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: 280,
                                      maxWidth: constraints.maxWidth,
                                    ),
                                    child: ListView(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      children: [
                                        for (final l in options)
                                          ListTile(
                                            leading: const Icon(Icons.place),
                                            title: Text(l.name),
                                            subtitle: Text(l.address),
                                            onTap: () => onSelected(l),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                        ),
                  ),
                )
              else
                AppTextField(
                  controller: _locName,
                  label: _remote ? 'Name' : 'Name des Orts',
                  readOnly: true,
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
              if (_offers.isNotEmpty) ...[
                const SizedBox(height: 16),
                _offersSection(context),
              ],
              const SizedBox(height: 12),
              // absagen links, speichern bzw. beauftragen rechts.
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
                    )
                  else if (_isOpen && _openOffers.isNotEmpty)
                    PrimaryButton(
                      label: 'buchen (${_chosen.length})',
                      isLoading: _isLoading,
                      onPressed: _canAward ? _award : null,
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
