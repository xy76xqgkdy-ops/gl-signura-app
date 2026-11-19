import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/error_text.dart';

// Profilbild: mit der Kamera aufnehmen, aus der Galerie wählen oder löschen.
//   GET/PUT/DELETE /me/picture
// Das Bild wird vor dem Hochladen verkleinert (höchstens 800 px, JPEG).
// Gibt true per pop zurück, wenn sich etwas geändert hat.
class PictureScreen extends StatefulWidget {
  const PictureScreen({super.key});

  @override
  State<PictureScreen> createState() => _PictureScreenState();
}

class _PictureScreenState extends State<PictureScreen> {
  Uint8List? _picture;
  bool _isLoading = true;
  bool _changed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await ApiClient.getBytes('/me/picture');
      if (!mounted) return;
      setState(() {
        _picture = bytes;
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

  Future<void> _pick(ImageSource source) async {
    setState(() => _errorMessage = null);
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
    } catch (_) {
      setState(
        () => _errorMessage =
            'Die Kamera oder die Fotos können nicht geöffnet werden.',
      );
      return;
    }
    if (file == null) return; // abgebrochen

    setState(() => _isLoading = true);
    try {
      final bytes = await file.readAsBytes();
      await ApiClient.putBytes('/me/picture', bytes, _contentType(bytes));
      if (!mounted) return;
      setState(() {
        _picture = bytes;
        _changed = true;
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

  // Typ aus den ersten Bytes, so prüft es auch das Backend.
  String _contentType(Uint8List b) {
    if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50) return 'image/png';
    if (b.length > 11 && b[8] == 0x57 && b[9] == 0x45) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _delete() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ApiClient.deleteJson('/me/picture');
      if (!mounted) return;
      setState(() {
        _picture = null;
        _changed = true;
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Profilbild')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 80,
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: _picture == null
                        ? null
                        : MemoryImage(_picture!),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : _picture == null
                        ? Icon(Icons.person, size: 80, color: scheme.outline)
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Kamera'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isLoading
                            ? null
                            : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galerie'),
                      ),
                      if (_picture != null)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.error,
                          ),
                          onPressed: _isLoading ? null : _delete,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('löschen'),
                        ),
                    ],
                  ),
                  ErrorText(message: _errorMessage),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
