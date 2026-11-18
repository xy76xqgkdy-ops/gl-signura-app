import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_text.dart';
import '../../core/widgets/primary_button.dart';
import '../request/request_data.dart';

// Neuer eigener Einsatzort (POST /me/locations) oder vorhandenen ändern
// (PUT /me/locations/{id}) und löschen (DELETE /me/locations/{id}).
// Gibt per Navigator.pop den gespeicherten Einsatzort zurück, nach dem
// Löschen true; null, wenn nichts geändert wurde.
class LocationFormScreen extends StatefulWidget {
  final LocationData? existing; // null = neuer Einsatzort

  const LocationFormScreen({super.key, this.existing});

  @override
  State<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends State<LocationFormScreen> {
  late final LocationData? _existing = widget.existing;
  late final _name = TextEditingController(text: _existing?.name);
  late final _street = TextEditingController(text: _existing?.street);
  late final _postalcode = TextEditingController(text: _existing?.postalcode);
  late final _city = TextEditingController(text: _existing?.city);
  late final _email = TextEditingController(text: _existing?.email);
  late final _phone = TextEditingController(text: _existing?.phone);
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final c in [_name, _street, _postalcode, _city, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canSave =>
      [
        _name,
        _street,
        _postalcode,
        _city,
      ].every((c) => c.text.trim().isNotEmpty) &&
      !_isLoading;

  Future<void> _save() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final body = {
      'name': _name.text.trim(),
      'street': _street.text.trim(),
      'postalcode': _postalcode.text.trim(),
      'city': _city.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'country': 'DE',
    };
    try {
      final json = _existing == null
          ? await ApiClient.postJson('/me/locations', body: body)
          : await ApiClient.putJson(
              '/me/locations/${_existing.id}',
              body: body,
            );
      if (!mounted) return;
      Navigator.of(context).pop(LocationData.fromJson(json));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Einsatzort löschen?'),
        content: Text(
          '„${_existing!.name}“ wird aus Ihrer Liste entfernt. '
          'Ihre Anfragen behalten ihre Adresse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
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
      await ApiClient.deleteJson('/me/locations/${_existing!.id}');
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

  @override
  Widget build(BuildContext context) {
    void changed(String _) => setState(() {});
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _existing == null ? 'Neuer Einsatzort' : 'Einsatzort bearbeiten',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _name,
                label: 'Name (z. B. Praxis Dr. Müller)',
                autofocus: _existing == null,
                onChanged: changed,
              ),
              AppTextField(
                controller: _street,
                label: 'Straße und Hausnummer',
                onChanged: changed,
              ),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: AppTextField(
                      controller: _postalcode,
                      label: 'PLZ',
                      keyboardType: TextInputType.number,
                      onChanged: changed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _city,
                      label: 'Ort',
                      onChanged: changed,
                    ),
                  ),
                ],
              ),
              AppTextField(
                controller: _email,
                label: 'E-Mail (optional)',
                keyboardType: TextInputType.emailAddress,
                onChanged: changed,
              ),
              AppTextField(
                controller: _phone,
                label: 'Telefon (optional)',
                keyboardType: TextInputType.phone,
                onChanged: changed,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Speichern',
                isLoading: _isLoading,
                onPressed: _canSave ? _save : null,
              ),
              if (_existing != null) ...[
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _isLoading ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Einsatzort löschen'),
                  ),
                ),
              ],
              ErrorText(message: _errorMessage),
            ],
          ),
        ),
      ),
    );
  }
}
