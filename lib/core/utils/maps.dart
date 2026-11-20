import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

// Route zu einer Adresse in der Karten-App öffnen. Start ist immer der
// aktuelle Ort; die Karten-App fragt selbst nach dem Standort, diese App
// braucht dafür keine Erlaubnis.
//
//   Android  geo:-Link → Standard-Karten-App (Google Maps, Waze, …) oder Auswahl
//   iPhone   Apple-Karten-Link mit Route; in der EU leitet iOS ihn an die
//            eingestellte Standard-App für Navigation weiter (ab iOS 18.4)
//   Browser  Apple-Geräte: Apple-Karten-Link, sonst Google Maps im neuen Tab
Future<void> openRoute(String address) async {
  final apple = Uri.https('maps.apple.com', '/', {
    'daddr': address,
    'dirflg': 'd',
  });
  final google = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': address,
  });
  final appleDevice =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final geo = Uri(
      scheme: 'geo',
      path: '0,0',
      queryParameters: {'q': address},
    );
    if (await launchUrl(geo, mode: LaunchMode.externalApplication)) return;
    await launchUrl(google, mode: LaunchMode.externalApplication);
    return;
  }
  await launchUrl(
    appleDevice ? apple : google,
    mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}
