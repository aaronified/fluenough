// A target in the Perso-Arabic script (Hindustani's second script, whose deck
// is not marked right to left) is drawn with line metrics that hold its
// dots and tails: in the word sheet they stay clear of the reading under the
// letter, and in a unit's row the letter sits in the middle of the row (#762).

import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/decks/word_mastery.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:fluenough/ui/theme.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const LanguageInfo _perso = LanguageInfo(
  code: 'hi',
  iso639_3: 'hin',
  name: 'Hindustani',
  script: 'perso_arabic',
  scripts: <String>['perso_arabic', 'devanagari'],
);

const LanguageInfo _devanagari = LanguageInfo(
  code: 'hi',
  iso639_3: 'hin',
  name: 'Hindustani',
  script: 'devanagari',
);

const Mastery _fresh = (level: MasteryLevel.fresh, share: 0.0);

Card _letter(String target, String reading) => Card(
  id: 'hi-0648',
  deckId: 'hi-script-perso-arabic-letters',
  target: target,
  native: 'letter $reading',
  reading: reading,
);

Rect _boxOf(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)).first,
  );
  return paragraph.localToGlobal(Offset.zero) & paragraph.size;
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.textScaleFactorTestValue = 1.4;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearTextScaleFactorTestValue();
  });

  group('Perso-Arabic script at 1.4x text', () {
    for (final letter in <String>['پ', 'ط', 'ل']) {
      testWidgets('the word sheet keeps $letter clear of its reading', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          Scaffold(
            body: WordSheet(card: _letter(letter, 'pa'), language: _perso),
          ),
        );
        final glyph = _boxOf(tester, find.byType(TargetText).first);
        final reading = _boxOf(tester, find.text('pa'));
        expect(glyph.bottom, lessThanOrEqualTo(reading.top));
        // The line holds the script's full height, not the Latin 1.25.
        expect(
          glyph.height,
          greaterThanOrEqualTo(44 * 1.4 * TargetSizes.rtlHeight - 0.5),
        );
      });

      testWidgets('a row centres $letter', (tester) async {
        await pumpScreen(
          tester,
          Scaffold(
            body: Column(
              children: <Widget>[
                CardRow(
                  card: _letter(letter, 'pa'),
                  language: _perso,
                  mastery: _fresh,
                  onTap: () {},
                ),
              ],
            ),
          ),
        );
        final glyph = _boxOf(tester, find.byType(TargetText));
        final row = tester.getRect(find.byType(InkWell));
        expect((glyph.center.dy - row.center.dy).abs(), lessThan(2));
        expect(glyph.top, greaterThanOrEqualTo(row.top));
        expect(glyph.bottom, lessThanOrEqualTo(row.bottom));
      });
    }

    testWidgets('Devanagari keeps its own, shorter line', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: WordSheet(card: _letter('प', 'pa'), language: _devanagari),
        ),
      );
      final glyph = _boxOf(tester, find.byType(TargetText).first);
      expect(glyph.height, closeTo(44 * 1.4 * TargetSizes.ltrHeight, 0.5));
    });
  });
}
