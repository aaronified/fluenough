import 'dart:io';

import 'package:flutter/services.dart';

/// The Flutter SDK's own fonts: Roboto and the Material icons.
String get _sdkFonts {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      // flutter_tester runs from <sdk>/bin/cache/artifacts/engine/<host>/.
      File(Platform.resolvedExecutable)
          .parent
          .parent
          .parent
          .parent
          .parent
          .parent
          .path;
  return '$root/bin/cache/artifacts/material_fonts';
}

/// Loads Roboto, the theme's font, in place of the test font, whose square
/// letters are far wider than Roboto's. Call it from `setUpAll`.
Future<void> loadRoboto() async {
  final loader = FontLoader('Roboto');
  for (final weight in <String>['Regular', 'Medium', 'Bold']) {
    final file = File('$_sdkFonts/Roboto-$weight.ttf');
    loader.addFont(
      Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
    );
  }
  await loader.load();
}
