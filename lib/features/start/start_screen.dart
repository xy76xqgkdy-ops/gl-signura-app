import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/session/session_store.dart';
import '../../core/widgets/primary_button.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

// Erste Seite beim App-Start: prüft das gespeicherte Token und öffnet
// die Startseite (angemeldet) oder die Login-Seite.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() => _errorMessage = null);
    try {
      final user = await SessionStore.restore();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              user == null ? const LoginScreen() : HomeScreen(user: user),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _errorMessage == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Erneut versuchen',
                      onPressed: _restore,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
