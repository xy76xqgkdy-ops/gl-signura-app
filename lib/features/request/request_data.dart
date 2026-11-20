import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';

// Status einer Anfrage, wie im Backend (request.status).
enum RequestStatus {
  newRequest('new', 'Offen', Colors.red),
  transferred('transferred', 'Weitergeleitet', Colors.blue),
  confirmed('confirmed', 'Gebucht', Colors.green),
  cancelled('cancelled', 'Abgesagt', Colors.grey);

  final String apiValue;
  final String text;
  final Color color;

  const RequestStatus(this.apiValue, this.text, this.color);

  static RequestStatus parse(String? value) => RequestStatus.values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => RequestStatus.newRequest,
  );
}

// Eine Dolmetsch-Anfrage (GET/POST /me/requests).
class RequestData {
  final String id;
  final DateTime start; // Ortszeit
  final DateTime end;
  final String purpose;
  final bool remote; // true = per Video, false = vor Ort
  final String? locationId; // nur Herkunft (gespeicherter Einsatzort)
  final String locationName; // Adresse gehört der Anfrage selbst
  final String locationStreet;
  final String locationPostalcode;
  final String locationCity;
  final String locationEmail;
  final String locationPhone;
  // Zugeteilter Dolmetscher; liefert das Backend noch nicht (dann null).
  final String? interpreterName;
  final String? interpreterPicture; // Bild-URL
  final int offerCount; // offene Zusagen von Dolmetscher:innen
  final RequestStatus status;

  const RequestData({
    required this.id,
    required this.start,
    required this.end,
    required this.purpose,
    required this.remote,
    required this.locationId,
    required this.locationName,
    required this.locationStreet,
    required this.locationPostalcode,
    required this.locationCity,
    this.locationEmail = '',
    this.locationPhone = '',
    this.interpreterName,
    this.interpreterPicture,
    this.offerCount = 0,
    required this.status,
  });

  factory RequestData.fromJson(Map<String, dynamic> json) => RequestData(
    id: json['id'] as String? ?? '',
    start: DateTime.parse(json['start_date'] as String).toLocal(),
    end: DateTime.parse(json['end_date'] as String).toLocal(),
    purpose: json['purpose'] as String? ?? '',
    remote: json['mode'] == 'remote',
    locationId: json['location_id'] as String?,
    locationName: json['location_name'] as String? ?? '',
    locationStreet: json['location_street'] as String? ?? '',
    locationPostalcode: json['location_postalcode'] as String? ?? '',
    locationCity: json['location_city'] as String? ?? '',
    locationEmail: json['location_email'] as String? ?? '',
    locationPhone: json['location_phone'] as String? ?? '',
    interpreterName: _nonEmpty(json['interpreter_name']),
    interpreterPicture: _nonEmpty(json['interpreter_picture']),
    offerCount: (json['offer_count'] as num?)?.toInt() ?? 0,
    status: RequestStatus.parse(json['status'] as String?),
  );

  // Straße, PLZ Ort (für die Liste).
  String get addressText => [
    locationStreet,
    [locationPostalcode, locationCity].where((s) => s.isNotEmpty).join(' '),
  ].where((s) => s.isNotEmpty).join(', ');

  String get timeRange => '${start.formattedTime} – ${end.formattedTime}';

  String get placeText => remote
      ? ['Per Video', locationName].where((s) => s.isNotEmpty).join(' · ')
      : [
          locationName.isNotEmpty ? locationName : locationStreet,
          locationCity,
        ].where((s) => s.isNotEmpty).join(', ');
}

// Zusage einer Dolmetscher:in (GET /me/requests/{id}/offers), ohne Vermittler.
class OfferData {
  final String id;
  final String interpreterName;
  final String status; // offered, awarded, declined

  const OfferData({
    required this.id,
    required this.interpreterName,
    required this.status,
  });

  factory OfferData.fromJson(Map<String, dynamic> json) => OfferData(
    id: json['offer_id'] as String? ?? '',
    interpreterName: json['interpreter_name'] as String? ?? '',
    status: json['status'] as String? ?? '',
  );
}

String? _nonEmpty(Object? v) => v is String && v.isNotEmpty ? v : null;

// Ein eigener Einsatzort (GET/POST /me/locations).
class LocationData {
  final String id;
  final String name;
  final String street;
  final String postalcode;
  final String city;
  final String email;
  final String phone;

  const LocationData({
    required this.id,
    required this.name,
    required this.street,
    required this.postalcode,
    required this.city,
    this.email = '',
    this.phone = '',
  });

  factory LocationData.fromJson(Map<String, dynamic> json) => LocationData(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    street: json['street'] as String? ?? '',
    postalcode: json['postalcode'] as String? ?? '',
    city: json['city'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
  );

  String get address => '$street, $postalcode $city';
}
