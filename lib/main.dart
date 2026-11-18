import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'features/start/start_screen.dart';

Future<void> main() async {
  // Deutsche Monats- und Wochentagsnamen für Kalender und Datumsanzeige.
  await initializeDateFormatting('de_DE');
  runApp(const SignuraApp());
}

class SignuraApp extends StatelessWidget {
  const SignuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Signura',
      debugShowCheckedModeBanner: false,
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        // Platzhalter grau, damit man sieht, dass das Feld leer ist.
        hintColor: _hint(lightScheme),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: TextStyle(color: _hint(lightScheme)),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.surfaceContainerHighest,
          foregroundColor: lightScheme.onSurface,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        hintColor: _hint(darkScheme),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: TextStyle(color: _hint(darkScheme)),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.surfaceContainerHighest,
          foregroundColor: darkScheme.onSurface,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const StartScreen(),
    );
  }
}

// Farbe für Platzhalter (hintText): grau, deutlich schwächer als Eingaben.
Color _hint(ColorScheme scheme) =>
    scheme.onSurfaceVariant.withValues(alpha: 0.6);
