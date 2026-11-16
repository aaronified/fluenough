// Toki Pona's sitelen pona, the second script of its cards (ADR-0055): the
// UCSUR glyphs are recognised as a script, drawn in their downloaded font,
// and asked about in the font check.

import 'package:fluenough/core/decks/font_check.dart';
import 'package:fluenough/core/decks/script_fonts.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/search/script_of.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sitelenPona = LanguageInfo(
    code: 'tok',
    iso639_3: 'tok',
    name: 'Toki Pona',
    script: 'sitelen_pona',
  );

  test('UCSUR glyphs are the sitelen_pona script', () {
    expect(scriptOf('\u{F196C} \u{F1954}.'), 'sitelen_pona');
    expect(scriptOf('toki pona'), 'latin');
  });

  test('sitelen pona is drawn in its own downloaded font', () {
    expect(fontScriptFor('tok', 'sitelen_pona'), 'sitelen_pona');
    expect(scriptFontFamily('sitelen_pona'), 'FluenoughScript-sitelen_pona');
    final quote = quotingTarget('Written: \u{F196C}', <String>[
      '\u{F196C}',
    ], sitelenPona).children!.cast<TextSpan>().last;
    expect(quote.style!.fontFamily, 'FluenoughScript-sitelen_pona');
  });

  test('the font check has a sample of sitelen pona', () {
    final sample = scriptSamples['sitelen_pona']!;
    expect(scriptOf(sample.text), 'sitelen_pona');
    expect(sample.reading, 'toki');
  });
}
