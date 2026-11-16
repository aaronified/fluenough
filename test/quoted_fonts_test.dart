// Deck words quoted inside an interface string are drawn in the font of
// their script (owner, 2026-11-16: "I don't want to depend on system fonts
// for content"), while the interface's own text stays in Roboto.

import 'package:fluenough/core/decks/script_fonts.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/ui/theme.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LanguageInfo _language(String code, String script, {bool rtl = false}) =>
    LanguageInfo(
      code: code,
      iso639_3: code,
      name: code,
      script: script,
      rtl: rtl,
    );

void main() {
  // (language, the script whose font draws a quote of it)
  final cases = <(LanguageInfo, String)>[
    (_language('hi', 'devanagari'), 'devanagari'),
    (_language('bn', 'bengali'), 'bengali'),
    (_language('ta', 'tamil'), 'tamil'),
    (_language('te', 'telugu'), 'telugu'),
    (_language('kn', 'kannada'), 'kannada'),
    (_language('ml', 'malayalam'), 'malayalam'),
    (_language('gu', 'gujarati'), 'gujarati'),
    (_language('pa', 'gurmukhi'), 'gurmukhi'),
    (_language('or', 'odia'), 'odia'),
    (_language('sat', 'ol_chiki'), 'ol_chiki'),
    (_language('hi', 'perso_arabic', rtl: true), 'perso_arabic'),
    (_language('fa', 'perso_arabic', rtl: true), 'perso_arabic_naskh'),
    (_language('ps', 'perso_arabic', rtl: true), 'perso_arabic_naskh'),
    (_language('ar', 'arabic', rtl: true), 'perso_arabic_naskh'),
    (_language('pa', 'shahmukhi', rtl: true), 'perso_arabic'),
    (_language('he', 'hebrew', rtl: true), 'hebrew'),
    (_language('ja', 'kana'), 'kana'),
    (_language('ja', 'han'), 'han'),
    (_language('zh', 'han_simplified'), 'han_simplified'),
    (_language('yue', 'han_traditional'), 'han_traditional'),
    (_language('ko', 'hangul'), 'hangul'),
    (_language('th', 'thai'), 'thai'),
    (_language('mni', 'meitei_mayek'), 'meitei_mayek'),
    (_language('qap', 'brahmi'), 'brahmi'),
    (_language('sux', 'cuneiform'), 'cuneiform'),
    (_language('egy', 'egyptian_hieroglyphs'), 'egyptian_hieroglyphs'),
    (_language('gmy', 'linear_b'), 'linear_b'),
    (_language('es', 'latin'), 'latin'),
    (_language('ru', 'cyrillic'), 'cyrillic'),
    (_language('el', 'greek'), 'greek'),
    (_language('ipa', 'ipa'), 'latin'),
  ];

  test('a quote in each script is drawn in that script\'s downloaded font, '
      'with Roboto and the content fonts behind it', () {
    for (final (language, fontScript) in cases) {
      final span = quotingTarget('Answer: word.', <String>['word'], language);
      final children = span.children!.cast<TextSpan>();
      final quote = children.singleWhere((c) => c.text!.contains('word'));
      expect(
        quote.style!.fontFamily,
        'FluenoughScript-$fontScript',
        reason: '${language.code} ${language.script}',
      );
      expect(quote.style!.fontFamilyFallback, <String>[
        interfaceFontFamily,
        brailleFontFamily,
        'FluenoughScript-latin',
        'FluenoughScript-cyrillic',
        'FluenoughScript-greek',
      ]);
      // The interface's own words carry no style: they stay in Roboto.
      for (final other in children.where((c) => c != quote)) {
        expect(other.style, isNull, reason: other.text);
      }
    }
  });

  test('braille is quoted in its shadow-dot font', () {
    final span = quotingTarget('Dots: ⠃', <String>[
      '⠃',
    ], _language('qbe', 'braille'));
    final quote = span.children!.cast<TextSpan>().last;
    expect(quote.style!.fontFamily, brailleFontFamily);
  });

  testWidgets('interface text stays in Roboto beside a quote', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Text.rich(
              quotingTarget('Answer: నమస్తే', <String>[
                'నమస్తే',
              ], _language('te', 'telugu')),
            ),
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).textTheme.bodyMedium!.fontFamily, 'Roboto');
    final rich = tester.widget<RichText>(find.byType(RichText).last);
    final families = <String?>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == 'నమస్తే') {
        families.add(span.style?.fontFamily);
      }
      return true;
    });
    expect(families, <String?>['FluenoughScript-telugu']);
  });
}
