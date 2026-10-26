import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('interface text is drawn in the bundled font, in light and dark', () {
    for (final theme in <ThemeData>[AppTheme.light(), AppTheme.dark()]) {
      for (final style in <TextStyle?>[
        theme.textTheme.bodyMedium,
        theme.textTheme.titleLarge,
        theme.textTheme.labelMedium,
      ]) {
        expect(style?.fontFamily, interfaceFontFamily);
      }
    }
  });

  test('the bundled font has its regular, medium and bold files', () async {
    for (final weight in <String>['Regular', 'Medium', 'Bold']) {
      final data = await rootBundle.load('assets/fonts/Roboto-$weight.ttf');
      expect(data.lengthInBytes, greaterThan(100000), reason: weight);
    }
  });
}
