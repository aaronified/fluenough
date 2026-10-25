// Braille is drawn with shadow dots (#835, ADR-0043): its text is always in
// the app's own braille font, never the phone's, wherever it appears.

import 'dart:io';

import 'package:fluenough/core/decks/script_fonts.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/ui/theme.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const LanguageInfo braille = LanguageInfo(
  code: 'qbe',
  iso639_3: 'eng',
  name: 'English Braille',
  script: 'braille',
);

const LanguageInfo spanish = LanguageInfo(
  code: 'es',
  iso639_3: 'spa',
  name: 'Spanish',
  script: 'latin',
);

void main() {
  for (final dark in <bool>[false, true]) {
    testWidgets(
      'braille cells are drawn in the shadow-dot font, '
      'in the ${dark ? 'dark' : 'light'} theme at 1.4x text',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!,
            ),
            home: Scaffold(
              body: Column(
                children: <Widget>[
                  TargetText(
                    '⠁⠈⠂⠃⠿',
                    language: braille,
                    fontSize: 48,
                    key: const ValueKey<String>('cells'),
                  ),
                  TargetText('hola', language: spanish, fontSize: 48),
                  // A note, in the interface's own text, that quotes cells.
                  const Text('Dots 1-2: ⠃ (b)', key: ValueKey<String>('note')),
                ],
              ),
            ),
          ),
        );

        Text textIn(Finder f) => tester.widget<Text>(
          find.descendant(of: f, matching: find.byType(Text)).first,
        );
        final cells = textIn(find.byKey(const ValueKey<String>('cells')));
        expect(cells.style!.fontFamily, brailleFontFamily);
        // One face with no bold: a synthetic bold would fill the rings.
        expect(cells.style!.fontWeight, FontWeight.normal);

        final spanishText = textIn(find.widgetWithText(TargetText, 'hola'));
        expect(spanishText.style!.fontFamily, isNot(brailleFontFamily));

        // Braille quoted in any other text falls back to the same font,
        // not the phone's.
        final note = tester.element(find.byKey(const ValueKey<String>('note')));
        expect(
          Theme.of(note).textTheme.bodyMedium!.fontFamilyFallback,
          contains(brailleFontFamily),
        );
      },
    );
  }

  test('the font ships with the app and is registered under its family', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: $brailleFontFamily'));
    expect(pubspec, contains('asset: assets/fonts/BrailleShadow.ttf'));
    expect(File('assets/fonts/BrailleShadow.ttf').existsSync(), isTrue);
    expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
  });
}
