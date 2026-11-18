# gl-signura-app
Dolmetscher finden, App für Gehörlose (Auftragsgeber)

Flutter-App auf gl.signura.de: Anmeldung, Registrierung, Passwort vergessen,
eigene Dolmetsch-Anfragen im Monatskalender und gespeicherte Einsatzorte.

Backend: booin (`booin/backend`), erreichbar unter `https://gl.signura.de/api`.
nginx auf signura-booin leitet `/api/` über das private Hetzner-Netz an
signura-database (`10.0.1.20:8080`) weiter.

## Lokal starten

```bash
flutter run -d chrome --web-port 5173
```

Port 5173 ist nötig: das Backend erlaubt lokal nur diesen Origin
(`BOOIN_CORS_ORIGINS`). Andere API-Adresse: `--dart-define=API_BASE=https://…`.

## Veröffentlichen

```bash
./deploy.sh
```

Baut die Web-App und lädt sie nach `/var/www/html` auf signura-booin
(167.233.242.200). Dateien, die nicht mehr im Build sind, werden dort gelöscht.

## Aufbau

| Ordner | Inhalt |
|---|---|
| `lib/core/api` | `ApiClient` (Token als `Authorization: Bearer`) |
| `lib/core/session` | Token auf dem Gerät speichern (angemeldet bleiben) |
| `lib/core/widgets` | gemeinsame Bausteine (teils aus dolmi übernommen) |
| `lib/features/auth` | Login, Registrieren, Passwort vergessen |
| `lib/features/home` | Startseite mit Kalender und Anfragen des Tages |
| `lib/features/request` | Anfrage anlegen, bearbeiten, absagen |
| `lib/features/location` | gespeicherte Einsatzorte verwalten |
