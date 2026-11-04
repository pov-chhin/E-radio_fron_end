import 'dart:io';

import 'package:flutter/services.dart';

/// Widget tests draw all text in "Ahem", a font whose every glyph is a 1em
/// square, so ordinary labels look far wider than on a device and can trip
/// overflow errors that never happen for real. This loads the Roboto that ships
/// in the Flutter SDK so layout is measured with realistic text. Does nothing
/// (tests still run, in Ahem) if the SDK's font files can't be found.
Future<void> loadTestFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';

  final roboto = FontLoader('Roboto');
  var found = false;
  for (final weight in ['light', 'regular', 'medium', 'bold']) {
    final file = File('$dir/roboto-$weight.ttf');
    if (!file.existsSync()) continue;
    roboto.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    found = true;
  }
  if (found) await roboto.load();
}
