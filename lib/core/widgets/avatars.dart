import 'dart:typed_data';

import 'package:flutter/material.dart';

// Profilbild einer Dolmetscher:in aus einer Data-URL ("data:image/jpeg;base64,…"),
// wie das Backend sie liefert. Kaputt oder leer → null.
Uint8List? pictureBytes(Object? dataUrl) {
  if (dataUrl is! String || !dataUrl.startsWith('data:')) return null;
  try {
    return UriData.parse(dataUrl).contentAsBytes();
  } on FormatException {
    return null;
  }
}

// Rundes Profilbild.
class Avatar extends StatelessWidget {
  final Uint8List bytes;
  final double size;
  const Avatar({super.key, required this.bytes, required this.size});

  @override
  Widget build(BuildContext context) => ClipOval(
    child: Image.memory(
      bytes,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    ),
  );
}

// Bis zu 3 Bilder leicht übereinander (gebuchte Dolmetscher:innen auf der
// Hauptseite). Ein Bild allein ist so groß wie das Symbol (48), mehrere
// sind kleiner, damit sie in die Zeile passen.
class AvatarStack extends StatelessWidget {
  final List<Uint8List> pictures;
  const AvatarStack({super.key, required this.pictures});

  @override
  Widget build(BuildContext context) {
    final shown = pictures.take(3).toList();
    if (shown.length == 1) return Avatar(bytes: shown.first, size: 48);
    const size = 36.0;
    const step = 16.0; // so weit rückt jedes weitere Bild nach rechts
    final ring = Theme.of(context).colorScheme.surface;
    return SizedBox(
      width: size + 4 + step * (shown.length - 1),
      height: 48,
      child: Stack(
        children: [
          // Von hinten nach vorn malen: das erste Bild liegt oben.
          for (var i = shown.length - 1; i >= 0; i--)
            Positioned(
              left: i * step,
              top: (48 - size - 4) / 2,
              child: Container(
                padding: const EdgeInsets.all(
                  2,
                ), // weißer Rand trennt die Bilder
                decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
                child: Avatar(bytes: shown[i], size: size),
              ),
            ),
        ],
      ),
    );
  }
}
